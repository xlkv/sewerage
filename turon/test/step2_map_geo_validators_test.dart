import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turon/app.dart';
import 'package:turon/core/geo_utils.dart';
import 'package:turon/core/validators.dart';
import 'package:turon/data/models/manhole.dart';
import 'package:turon/data/models/pipe.dart';
import 'package:turon/data/models/work_status.dart';
import 'package:turon/features/map/map_controller.dart';
import 'package:turon/features/map/map_mode.dart';
import 'package:turon/features/map/map_objects_layer.dart';

void main() {
  final sampleTime = DateTime.utc(2026, 4, 19);

  Manhole makeManhole(
    String id,
    String code,
    WorkStatus status, {
    double lat = 41.2995,
    double lng = 69.2401,
  }) {
    return Manhole(
      id: id,
      code: code,
      status: status,
      lat: lat,
      lng: lng,
      createdAt: sampleTime,
      updatedAt: sampleTime,
    );
  }

  Pipe makePipe(
    String id,
    String code,
    String fromId,
    String toId,
    WorkStatus status, {
    int diameterMm = 200,
    double lengthAutoM = 45.0,
    double? lengthManualM,
  }) {
    return Pipe(
      id: id,
      code: code,
      fromManholeId: fromId,
      toManholeId: toId,
      diameterMm: diameterMm,
      status: status,
      lengthAutoM: lengthAutoM,
      lengthManualM: lengthManualM,
      createdAt: sampleTime,
      updatedAt: sampleTime,
    );
  }

  group('MapController state machine (LLD 4.5)', () {
    late ProviderContainer container;
    late MapController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(mapControllerProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('View -> Tap manhole / pipe -> View (selection = object)', () {
      expect(container.read(mapControllerProvider).mode, const ViewMode());
      expect(container.read(mapControllerProvider).selection, isNull);

      controller.onManholeTap('mh-1');
      expect(container.read(mapControllerProvider).mode, const ViewMode());
      expect(
        container.read(mapControllerProvider).selection,
        const ManholeSelection('mh-1'),
      );

      controller.onPipeTap('pipe-1');
      expect(container.read(mapControllerProvider).mode, const ViewMode());
      expect(
        container.read(mapControllerProvider).selection,
        const PipeSelection('pipe-1'),
      );
    });

    test('View -> Tap empty map -> View (selection = null)', () {
      controller.onManholeTap('mh-1');
      expect(
        container.read(mapControllerProvider).selection,
        const ManholeSelection('mh-1'),
      );

      controller.onMapTap(41.3000, 69.2400);
      expect(container.read(mapControllerProvider).mode, const ViewMode());
      expect(container.read(mapControllerProvider).selection, isNull);
    });

    test('Non-admin role is blocked from entering edit/add/move modes', () {
      controller.startAddManhole(isAdmin: false);
      expect(container.read(mapControllerProvider).mode, const ViewMode());

      controller.startAddPipe(isAdmin: false);
      expect(container.read(mapControllerProvider).mode, const ViewMode());

      controller.startMoveManhole(
        'mh-1',
        initialLat: 41.2,
        initialLng: 69.2,
        isAdmin: false,
      );
      expect(container.read(mapControllerProvider).mode, const ViewMode());
    });

    test(
      'View -> + Kolodets -> AddManhole -> Tap map (lat, lng) -> Opens Manhole form -> Save -> View',
      () {
        controller.startAddManhole();
        var state = container.read(mapControllerProvider);
        expect(state.mode, const AddManholeMode());
        expect(
          state.mode.bannerText,
          'Kolodets joyini xaritadan tanlang',
        );
        expect(state.activeForm, isNull);

        controller.onMapTap(41.3111, 69.2797);
        state = container.read(mapControllerProvider);
        expect(
          state.mode,
          const AddManholeMode(pendingLat: 41.3111, pendingLng: 69.2797),
        );
        expect(
          state.activeForm,
          const CreateManholeForm(lat: 41.3111, lng: 69.2797),
        );

        controller.onFormSaved(selection: const ManholeSelection('mh-new'));
        state = container.read(mapControllerProvider);
        expect(state.mode, const ViewMode());
        expect(state.activeForm, isNull);
        expect(state.selection, const ManholeSelection('mh-new'));
      },
    );

    test(
      'View -> + Quvur -> AddPipe(null) -> Tap a -> AddPipe(a) -> Tap same a -> AddPipe(null)',
      () {
        controller.startAddPipe();
        var state = container.read(mapControllerProvider);
        expect(state.mode, const AddPipeMode(fromManholeId: null));
        expect(state.mode.bannerText, '1-kolodetsni tanlang');

        controller.onManholeTap('mh-a');
        state = container.read(mapControllerProvider);
        expect(state.mode, const AddPipeMode(fromManholeId: 'mh-a'));
        expect(state.mode.bannerText, '2-kolodetsni tanlang');

        // Tap same manhole a -> deselect back to AddPipe(from: null)
        controller.onManholeTap('mh-a');
        state = container.read(mapControllerProvider);
        expect(state.mode, const AddPipeMode(fromManholeId: null));
        expect(state.mode.bannerText, '1-kolodetsni tanlang');
      },
    );

    test(
      'AddPipe(a) -> Tap manhole b where a-b pipe exists (either direction) -> snackbar, stay in AddPipe(a)',
      () {
        final existingPipes = [
          makePipe('p-1', 'Q-1', 'mh-b', 'mh-a', WorkStatus.completed),
        ];

        controller.startAddPipe();
        controller.onManholeTap('mh-a', existingPipes: existingPipes);
        expect(
          container.read(mapControllerProvider).mode,
          const AddPipeMode(fromManholeId: 'mh-a'),
        );

        controller.onManholeTap('mh-b', existingPipes: existingPipes);
        final state = container.read(mapControllerProvider);
        expect(state.mode, const AddPipeMode(fromManholeId: 'mh-a'));
        expect(state.activeForm, isNull);
        expect(
          state.snackbarMessage,
          'Bu kolodetslar allaqachon ulangan',
        );
      },
    );

    test(
      'AddPipe(a) -> Tap valid manhole b -> Opens Pipe form (from=a, to=b) -> Save -> View',
      () {
        final existingPipes = [
          makePipe('p-1', 'Q-1', 'mh-x', 'mh-y', WorkStatus.completed),
        ];

        controller.startAddPipe();
        controller.onManholeTap('mh-a', existingPipes: existingPipes);
        controller.onManholeTap('mh-b', existingPipes: existingPipes);

        var state = container.read(mapControllerProvider);
        expect(
          state.mode,
          const AddPipeMode(fromManholeId: 'mh-a', toManholeId: 'mh-b'),
        );
        expect(
          state.activeForm,
          const CreatePipeForm(fromManholeId: 'mh-a', toManholeId: 'mh-b'),
        );

        controller.onFormSaved(selection: const PipeSelection('p-new'));
        state = container.read(mapControllerProvider);
        expect(state.mode, const ViewMode());
        expect(state.activeForm, isNull);
        expect(state.selection, const PipeSelection('p-new'));
      },
    );

    test(
      'View -> MoveManhole(id) -> drag / update position -> Save -> View',
      () {
        controller.startMoveManhole(
          'mh-1',
          initialLat: 41.2995,
          initialLng: 69.2401,
        );
        var state = container.read(mapControllerProvider);
        expect(
          state.mode,
          const MoveManholeMode(
            manholeId: 'mh-1',
            newLat: 41.2995,
            newLng: 69.2401,
          ),
        );
        expect(
          state.mode.bannerText,
          'Kolodetsni yangi joyga suring \u2192 Saqlash',
        );

        controller.updateMoveManholePosition(41.3050, 69.2500);
        state = container.read(mapControllerProvider);
        expect(
          state.mode,
          const MoveManholeMode(
            manholeId: 'mh-1',
            newLat: 41.3050,
            newLng: 69.2500,
          ),
        );

        controller.completeMoveManhole();
        state = container.read(mapControllerProvider);
        expect(state.mode, const ViewMode());
        expect(state.selection, const ManholeSelection('mh-1'));
      },
    );

    test('Any != View -> cancelMode (Bekor qilish / Back) -> View', () {
      controller.startAddManhole();
      expect(container.read(mapControllerProvider).mode, isA<AddManholeMode>());
      controller.cancelMode();
      expect(container.read(mapControllerProvider).mode, const ViewMode());

      controller.startAddPipe();
      controller.onManholeTap('mh-a');
      expect(container.read(mapControllerProvider).mode, isA<AddPipeMode>());
      controller.cancelMode();
      expect(container.read(mapControllerProvider).mode, const ViewMode());

      controller.startMoveManhole(
        'mh-1',
        initialLat: 41.2995,
        initialLng: 69.2401,
      );
      expect(
        container.read(mapControllerProvider).mode,
        isA<MoveManholeMode>(),
      );
      controller.cancelMode();
      expect(container.read(mapControllerProvider).mode, const ViewMode());
    });
  });

  group('Status filter logic & diff helper (LLD 4.4 & 4.6)', () {
    test('StatusFilterNotifier toggles and selects all statuses', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(statusFilterProvider),
        WorkStatus.values.toSet(),
      );

      container
          .read(statusFilterProvider.notifier)
          .toggle(WorkStatus.planned);
      expect(
        container.read(statusFilterProvider),
        {WorkStatus.inProgress, WorkStatus.completed},
      );

      container.read(statusFilterProvider.notifier).selectAll();
      expect(
        container.read(statusFilterProvider),
        WorkStatus.values.toSet(),
      );
    });

    test(
      'filterPipes draws a pipe that passes status filter even if its endpoint manholes are filtered out',
      () {
        final manholes = {
          'mh-1': makeManhole('mh-1', 'K-1', WorkStatus.completed),
          'mh-2': makeManhole('mh-2', 'K-2', WorkStatus.inProgress),
        };
        final pipes = {
          'p-1': makePipe(
            'p-1',
            'Q-1',
            'mh-1',
            'mh-2',
            WorkStatus.planned,
          ),
          'p-2': makePipe(
            'p-2',
            'Q-2',
            'mh-1',
            'mh-2',
            WorkStatus.completed,
          ),
        };

        // Filter only "planned": neither mh-1 nor mh-2 is planned, but p-1 IS planned.
        final activeStatuses = {WorkStatus.planned};

        final visibleManholes = MapObjectsLayer.filterManholes(
          manholes,
          activeStatuses,
        );
        expect(visibleManholes, isEmpty);

        final visiblePipes = MapObjectsLayer.filterPipes(
          pipes,
          activeStatuses,
          allManholes: manholes,
        );
        expect(visiblePipes.map((p) => p.id).toList(), ['p-1']);
      },
    );

    test('shouldShowCodeLabel is true only for zoom >= 14', () {
      expect(MapObjectsLayer.shouldShowCodeLabel(13.9), isFalse);
      expect(MapObjectsLayer.shouldShowCodeLabel(14.0), isTrue);
      expect(MapObjectsLayer.shouldShowCodeLabel(18.0), isTrue);
    });

    test('ObjectIdDiff computes toRemove, toAdd, and toUpdate accurately', () {
      final diff = ObjectIdDiff.compute(
        {'a', 'b', 'c'},
        {'b', 'c', 'd'},
      );
      expect(diff.toRemove, {'a'});
      expect(diff.toAdd, {'d'});
      expect(diff.toUpdate, {'b', 'c'});
    });
  });

  group('GeoUtils: Haversine, bearing, midpoint, boundingBox', () {
    test('haversineMeters is 0 for identical coordinates', () {
      expect(
        GeoUtils.haversineMeters(41.2995, 69.2401, 41.2995, 69.2401),
        0.0,
      );
    });

    test(
      'haversineMeters and haversineMetersRounded match expected distance',
      () {
        // ~111.195 meters per 0.001 degree of latitude
        final dist = GeoUtils.haversineMeters(
          41.3000,
          69.2400,
          41.3010,
          69.2400,
        );
        expect(dist, closeTo(111.19, 0.5));

        final rounded = GeoUtils.haversineMetersRounded(
          41.3000,
          69.2400,
          41.3010,
          69.2400,
        );
        expect(rounded, closeTo(111.19, 0.5));
      },
    );

    test('bearingDegrees returns cardinal directions in [0, 360)', () {
      // North (0 deg)
      expect(
        GeoUtils.bearingDegrees(41.0, 69.0, 42.0, 69.0),
        closeTo(0.0, 0.01),
      );
      // East (~90 deg)
      expect(
        GeoUtils.bearingDegrees(41.0, 69.0, 41.0, 70.0),
        closeTo(89.67, 0.5),
      );
      // South (180 deg)
      expect(
        GeoUtils.bearingDegrees(42.0, 69.0, 41.0, 69.0),
        closeTo(180.0, 0.01),
      );
      // West (~270 deg)
      expect(
        GeoUtils.bearingDegrees(41.0, 70.0, 41.0, 69.0),
        closeTo(270.33, 0.5),
      );
    });

    test('midpoint and boundingBox work as expected', () {
      final mid = GeoUtils.midpoint(41.0, 69.0, 41.2, 69.4);
      expect(mid.lat, closeTo(41.1, 1e-6));
      expect(mid.lng, closeTo(69.2, 1e-6));

      expect(GeoUtils.boundingBox(const []), isNull);
      final bbox = GeoUtils.boundingBox([
        (lat: 41.3, lng: 69.2),
        (lat: 41.1, lng: 69.5),
        (lat: 41.2, lng: 69.1),
      ]);
      expect(bbox, isNotNull);
      expect(bbox!.minLat, 41.1);
      expect(bbox.maxLat, 41.3);
      expect(bbox.minLng, 69.1);
      expect(bbox.maxLng, 69.5);
    });
  });

  group('FormValidators (LLD 1.2, 2.2 & 4.7)', () {
    test('validateCode checks required/optional and 1..32 length', () {
      expect(FormValidators.validateCode(null), isNotNull);
      expect(FormValidators.validateCode('   '), isNotNull);
      expect(FormValidators.validateCode('', allowEmpty: true), isNull);
      expect(FormValidators.validateCode('K-101'), isNull);
      expect(FormValidators.validateCode('A' * 32), isNull);
      expect(FormValidators.validateCode('A' * 33), isNotNull);
    });

    test('validateManholeHeight checks optional > 0 and max 2 decimals', () {
      expect(FormValidators.validateManholeHeight(''), isNull);
      expect(FormValidators.validateManholeHeight('0'), isNotNull);
      expect(FormValidators.validateManholeHeight('-1.5'), isNotNull);
      expect(FormValidators.validateManholeHeight('2.555'), isNotNull);
      expect(FormValidators.validateManholeHeight('abc'), isNotNull);
      expect(FormValidators.validateManholeHeight('2.5'), isNull);
      expect(FormValidators.validateManholeHeight('2,5'), isNull);
      expect(FormValidators.validateManholeHeight('50'), isNull);
      expect(FormValidators.validateManholeHeight('1000'), isNull);
    });

    test('validateManholeDiameterM checks optional > 0 and max 2 decimals', () {
      expect(FormValidators.validateManholeDiameterM(''), isNull);
      expect(FormValidators.validateManholeDiameterM('0'), isNotNull);
      expect(FormValidators.validateManholeDiameterM('1.234'), isNotNull);
      expect(FormValidators.validateManholeDiameterM('abc'), isNotNull);
      expect(FormValidators.validateManholeDiameterM('1.0'), isNull);
      expect(FormValidators.validateManholeDiameterM('10'), isNull);
      expect(FormValidators.validateManholeDiameterM('1000'), isNull);
    });

    test('validatePipeCustomDiameter checks 50..2000 when custom selected', () {
      expect(
        FormValidators.validatePipeCustomDiameter(
          '',
          isCustomSelected: false,
        ),
        isNull,
      );
      expect(
        FormValidators.validatePipeCustomDiameter(
          '',
          isCustomSelected: true,
        ),
        isNotNull,
      );
      expect(
        FormValidators.validatePipeCustomDiameter(
          '49',
          isCustomSelected: true,
        ),
        isNotNull,
      );
      expect(
        FormValidators.validatePipeCustomDiameter(
          '2001',
          isCustomSelected: true,
        ),
        isNotNull,
      );
      expect(
        FormValidators.validatePipeCustomDiameter(
          '600',
          isCustomSelected: true,
        ),
        isNull,
      );
    });

    test('validatePipeManualLength checks > 0 and <= 10000 when enabled', () {
      expect(
        FormValidators.validatePipeManualLength(
          '',
          isManualEnabled: false,
        ),
        isNull,
      );
      expect(
        FormValidators.validatePipeManualLength(
          '',
          isManualEnabled: true,
        ),
        isNotNull,
      );
      expect(
        FormValidators.validatePipeManualLength(
          '0',
          isManualEnabled: true,
        ),
        isNotNull,
      );
      expect(
        FormValidators.validatePipeManualLength(
          '10001',
          isManualEnabled: true,
        ),
        isNotNull,
      );
      expect(
        FormValidators.validatePipeManualLength(
          '125.5',
          isManualEnabled: true,
        ),
        isNull,
      );
    });

    test('validateNote checks max 500 chars', () {
      expect(FormValidators.validateNote(null), isNull);
      expect(FormValidators.validateNote('A' * 500), isNull);
      expect(FormValidators.validateNote('A' * 501), isNotNull);
    });
  });

  group('ConfigErrorScreen fallback', () {
    testWidgets(
      'TuronApp shows friendly ConfigErrorScreen when SUPABASE env vars are missing',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isSupabaseConfiguredProvider.overrideWithValue(false),
            ],
            child: const TuronApp(),
          ),
        );

        expect(find.byType(ConfigErrorScreen), findsOneWidget);
        expect(
          find.text('Ilova konfiguratsiyasi topilmadi'),
          findsOneWidget,
        );
      },
    );
  });
}
