import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turon/core/errors.dart';
import 'package:turon/core/geo_utils.dart';
import 'package:turon/core/optimistic_store.dart';
import 'package:turon/core/router.dart';
import 'package:turon/core/validators.dart';
import 'package:turon/data/models/manhole.dart';
import 'package:turon/data/models/master.dart';
import 'package:turon/data/models/profile.dart';
import 'package:turon/data/models/work_status.dart';
import 'package:turon/data/repositories/admin_users_repo.dart';
import 'package:turon/data/repositories/master_repo.dart';
import 'package:turon/features/admin/masters/masters_screen.dart';
import 'package:turon/features/admin/users/users_screen.dart';
import 'package:turon/features/map/map_controller.dart';
import 'package:turon/features/map/map_mode.dart';
import 'package:turon/features/map/map_objects_layer.dart';
import 'package:turon/shared/widgets/adaptive_panel.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as ymk_image;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;

void main() {
  group('Step 4.1: Optional decimal parsing & manhole validators', () {
    test('parseOptionalDecimal returns null for empty or whitespace input', () {
      expect(FormValidators.parseOptionalDecimal(null), isNull);
      expect(FormValidators.parseOptionalDecimal(''), isNull);
      expect(FormValidators.parseOptionalDecimal('   '), isNull);
    });

    test(
      'parseOptionalDecimal parses both comma and dot and rounds to 2 decimals',
      () {
        expect(FormValidators.parseOptionalDecimal('2,5'), 2.5);
        expect(FormValidators.parseOptionalDecimal('2.5'), 2.5);
        expect(FormValidators.parseOptionalDecimal(' 100,25 '), 100.25);
        expect(FormValidators.parseOptionalDecimal('1000'), 1000.0);
      },
    );

    test(
      'validateManholeHeight and validateManholeDiameterM allow large numbers and reject <= 0 or >2 decimals',
      () {
        expect(FormValidators.validateManholeHeight(''), isNull);
        expect(FormValidators.validateManholeHeight('   '), isNull);
        expect(FormValidators.validateManholeHeight('100'), isNull);
        expect(FormValidators.validateManholeHeight('1000'), isNull);
        expect(FormValidators.validateManholeHeight('25,75'), isNull);
        expect(FormValidators.validateManholeHeight('0'), isNotNull);
        expect(FormValidators.validateManholeHeight('-5'), isNotNull);
        expect(FormValidators.validateManholeHeight('abc'), isNotNull);
        expect(FormValidators.validateManholeHeight('2.123'), isNotNull);

        expect(FormValidators.validateManholeDiameterM(''), isNull);
        expect(FormValidators.validateManholeDiameterM('   '), isNull);
        expect(FormValidators.validateManholeDiameterM('100'), isNull);
        expect(FormValidators.validateManholeDiameterM('1000'), isNull);
        expect(FormValidators.validateManholeDiameterM('1,5'), isNull);
        expect(FormValidators.validateManholeDiameterM('0'), isNotNull);
        expect(FormValidators.validateManholeDiameterM('-1'), isNotNull);
        expect(FormValidators.validateManholeDiameterM('xyz'), isNotNull);
        expect(FormValidators.validateManholeDiameterM('1.999'), isNotNull);
      },
    );
  });

  group('Step 4.2: Qarshi default camera constants', () {
    test('GeoUtils has Qarshi coordinates (38.8606, 65.7898) and zoom 13.0', () {
      expect(GeoUtils.qarshiLat, 38.8606);
      expect(GeoUtils.qarshiLng, 65.7898);
      expect(GeoUtils.qarshiDefaultZoom, 13.0);
    });
  });

  group('Step 4.3: ManholeMarkerCacheKey & canvas bitmap generator', () {
    test('ManholeMarkerCacheKey equality, hashCode, and zoomBucket', () {
      expect(ManholeMarkerCacheKey.bucketForZoom(13.9), 'dot');
      expect(ManholeMarkerCacheKey.bucketForZoom(14.0), 'full');
      expect(ManholeMarkerCacheKey.bucketForZoom(17.5), 'full');

      const k1 = ManholeMarkerCacheKey(
        status: WorkStatus.completed,
        code: 'K-12',
        selected: false,
        zoomBucket: 'full',
      );
      const k2 = ManholeMarkerCacheKey(
        status: WorkStatus.completed,
        code: 'K-12',
        selected: false,
        zoomBucket: 'full',
      );
      const k3 = ManholeMarkerCacheKey(
        status: WorkStatus.completed,
        code: 'K-12',
        selected: true,
        zoomBucket: 'full',
      );
      const k4 = ManholeMarkerCacheKey(
        status: WorkStatus.completed,
        code: 'K-12',
        selected: false,
        zoomBucket: 'dot',
      );

      expect(k1, equals(k2));
      expect(k1.hashCode, equals(k2.hashCode));
      expect(k1, isNot(equals(k3)));
      expect(k1, isNot(equals(k4)));
    });

    testWidgets('drawManholeImage renders valid ui.Image & PNG bytes for dot and full', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final fullImage = await MapObjectsLayerController.drawManholeImage(
          const ManholeMarkerCacheKey(
            status: WorkStatus.inProgress,
            code: 'K-105',
            selected: true,
            zoomBucket: 'full',
          ),
          dprOverride: 2.0,
        );
        final fullByteData = await fullImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        expect(fullByteData, isNotNull);
        expect(fullByteData!.lengthInBytes, greaterThan(0));

        final dotImage = await MapObjectsLayerController.drawManholeImage(
          const ManholeMarkerCacheKey(
            status: WorkStatus.planned,
            code: 'K-105',
            selected: false,
            zoomBucket: 'dot',
          ),
          dprOverride: 2.0,
        );
        final dotByteData = await dotImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        expect(dotByteData, isNotNull);
        expect(dotByteData!.lengthInBytes, greaterThan(0));
        expect(fullImage.width, greaterThan(dotImage.width));
      });
    });
  });

  group('Step 4.5: Admin validators, error mappings, and router guard', () {
    test('Admin form validators check fullName, phone, and 5-digit PIN', () {
      expect(FormValidators.validateFullName(''), isNotNull);
      expect(FormValidators.validateFullName('A'), isNotNull);
      expect(FormValidators.validateFullName('Ali Valiyev'), isNull);

      expect(FormValidators.validateRequiredPhone(''), isNotNull);
      expect(FormValidators.validateRequiredPhone('00 123 45 67'), isNotNull);
      expect(
        FormValidators.validateRequiredPhone('+998 (90) 123-45-67'),
        isNull,
      );

      expect(FormValidators.validateOptionalPhone(''), isNull);
      expect(FormValidators.validateOptionalPhone('   '), isNull);
      expect(FormValidators.validateOptionalPhone('+998'), isNull);
      expect(FormValidators.validateOptionalPhone('12345'), isNotNull);
      expect(
        FormValidators.validateOptionalPhone('+998 (93) 555-44-33'),
        isNull,
      );

      expect(FormValidators.validatePin(''), isNotNull);
      expect(FormValidators.validatePin('1234'), isNotNull);
      expect(FormValidators.validatePin('1234a'), isNotNull);
      expect(FormValidators.validatePin('12345'), isNull);
    });

    test('mapErrorToMessage maps phone_exists and self_change in Uzbek', () {
      const phoneExistsFnErr = FunctionException(
        status: 409,
        details: {'error': 'phone_exists'},
      );
      expect(
        mapErrorToMessage(phoneExistsFnErr),
        'Bu raqam allaqachon ro\'yxatda',
      );

      const selfChangeFnErr = FunctionException(
        status: 400,
        details: {'error': 'self_change'},
      );
      expect(
        mapErrorToMessage(selfChangeFnErr),
        'O\'zingizni o\'zgartira olmaysiz',
      );
    });

    test('resolveRouteRedirect guards /admin routes for non-admin users', () {
      expect(
        resolveRouteRedirect(
          matchedLocation: '/admin/users',
          isAuthenticated: false,
          isAdmin: null,
        ),
        '/login',
      );
      expect(
        resolveRouteRedirect(
          matchedLocation: '/admin/users',
          isAuthenticated: true,
          isAdmin: false,
        ),
        '/',
      );
      expect(
        resolveRouteRedirect(
          matchedLocation: '/admin/masters',
          isAuthenticated: true,
          isAdmin: false,
        ),
        '/',
      );
      expect(
        resolveRouteRedirect(
          matchedLocation: '/admin/users',
          isAuthenticated: true,
          isAdmin: true,
        ),
        isNull,
      );
    });

    testWidgets('UsersScreen and MastersScreen render list, empty state, and filter search', (
      tester,
    ) async {
      final sampleUsers = [
        const Profile(
          id: 'u-1',
          fullName: 'Azizbek Admin',
          phone: '998901234567',
          role: AppRole.admin,
          isActive: true,
        ),
        const Profile(
          id: 'u-2',
          fullName: 'Sardor Xodim',
          phone: '998939998877',
          role: AppRole.user,
          isActive: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            adminUsersProvider.overrideWith((ref) async => sampleUsers),
          ],
          child: const MaterialApp(home: UsersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Azizbek Admin'), findsOneWidget);
      expect(find.text('Sardor Xodim'), findsOneWidget);
      expect(find.text('Bloklangan'), findsOneWidget);
      expect(find.text('Qo\'shish'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('users_search_field')),
        'Sardor',
      );
      await tester.pump();
      expect(find.text('Azizbek Admin'), findsNothing);
      expect(find.text('Sardor Xodim'), findsOneWidget);

      final sampleMasters = [
        const Master(
          id: 'm-1',
          fullName: 'Usta Karim',
          phone: '998912223344',
          isActive: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            mastersProvider.overrideWith((ref) => Stream.value(sampleMasters)),
          ],
          child: const MaterialApp(home: MastersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Usta Karim'), findsOneWidget);
      expect(find.text('+998 (91) 222-33-44'), findsOneWidget);
      expect(find.text('Usta qo\'shish'), findsOneWidget);

      // Empty state check (#11)
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            mastersProvider.overrideWith(
              (ref) => Stream.value(const <Master>[]),
            ),
          ],
          child: const MaterialApp(home: MastersScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hali usta qo\'shilmagan'), findsOneWidget);
      expect(find.text('Usta qo\'shish'), findsOneWidget);
    });
  });

  group('Step 5: formatLength, spheroidMeters, OptimisticEntityStore, Delete & Selection sync', () {
    test('formatLength formats meters < 1000 as m and >= 1000 as km', () {
      expect(formatLength(48.3), '48.3 m');
      expect(formatLength(999.94), '999.9 m');
      expect(formatLength(1000.0), '1.0 km');
      expect(formatLength(441913.1), '441.9 km');
    });

    test('spheroidMetersRounded matches PostGIS WGS84 spheroid distance', () {
      // Qarshi to Tashkent (~400 km): WGS84 spheroid distance ~399863.57 m
      final spheroid = GeoUtils.spheroidMetersRounded(
        38.8606,
        65.7898,
        41.2995,
        69.2401,
      );
      expect(spheroid, closeTo(399863.57, 1.0));
    });

    test('OptimisticEntityStore merges local upsert, remote snapshots, and delete idempotently', () {
      final store = OptimisticEntityStore<Master>(getId: (m) => m.id);

      const m1 = Master(id: 'm1', fullName: 'Usta 1', isActive: true);
      const m2 = Master(id: 'm2', fullName: 'Usta 2', isActive: true);
      const m1Updated = Master(
        id: 'm1',
        fullName: 'Usta 1 Yangi',
        isActive: true,
      );

      // Optimistic local create before remote stream emits
      store.upsert(m1);
      expect(store.currentMap.keys, ['m1']);

      // Remote snapshot arrives with m1 and m2 -> merged by id without duplicates
      store.applyRemote([m1, m2]);
      expect(store.currentMap.length, 2);

      // Optimistic local update
      store.upsert(m1Updated);
      expect(store.currentMap['m1']?.fullName, 'Usta 1 Yangi');

      // Optimistic local delete -> stays removed even if stale remote snapshot includes it
      store.remove('m2');
      expect(store.currentMap.containsKey('m2'), isFalse);
      store.applyRemote([m1Updated, m2]);
      expect(store.currentMap.containsKey('m2'), isFalse);
    });

    test('ensureDeletedRowsAffected throws AppException when 0 rows affected', () {
      expect(
        () => ensureDeletedRowsAffected(const <Map<String, dynamic>>[]),
        throwsA(isA<AppException>()),
      );
      expect(
        () => ensureDeletedRowsAffected([
          {'id': 'row-1'},
        ]),
        returnsNormally,
      );
    });

    test('MapController selection state machine switches and clears cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(mapControllerProvider.notifier);

      // Select manhole -> select pipe -> clearSelection
      controller.onManholeTap('mh-1');
      expect(
        container.read(mapControllerProvider).selection,
        const ManholeSelection('mh-1'),
      );

      controller.onPipeTap('pipe-1');
      expect(
        container.read(mapControllerProvider).selection,
        const PipeSelection('pipe-1'),
      );

      controller.clearSelection();
      expect(container.read(mapControllerProvider).selection, isNull);

      // Cancel MoveManhole clears selection
      controller.startMoveManhole(
        'mh-1',
        initialLat: 38.86,
        initialLng: 65.78,
      );
      expect(
        container.read(mapControllerProvider).mode,
        isA<MoveManholeMode>(),
      );
      expect(
        container.read(mapControllerProvider).selection,
        const ManholeSelection('mh-1'),
      );
      controller.cancelMode();
      expect(container.read(mapControllerProvider).mode, const ViewMode());
      expect(container.read(mapControllerProvider).selection, isNull);
    });
  });

  group('Step 6: UX_REPORT_2 regressions (#1-#4)', () {
    test(
      'Regression #1: clearing selection via (a) map tap, (b) X button, or (c) sheet swipe removes selected manhole placemark and restores unselected marker',
      () {
        final rootCollection = _FakeMapObjectCollection();
        final layerController = MapObjectsLayerController(
          rootCollection: rootCollection,
          onManholeTap: (_) {},
          onPipeTap: (_) {},
          onManholeMoved: (_, _) {},
        );
        final manholesCollection = rootCollection.subCollections.last;

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final mapController = container.read(mapControllerProvider.notifier);

        final manholes = {
          'mh-1': Manhole(
            id: 'mh-1',
            code: 'K-6',
            lat: 38.8606,
            lng: 65.7898,
            status: WorkStatus.completed,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        };

        void syncFromState() {
          final state = container.read(mapControllerProvider);
          layerController.sync(
            allManholes: manholes,
            allPipes: const {},
            activeStatuses: WorkStatus.values.toSet(),
            selection: state.selection,
            mode: state.mode,
            zoom: 16.0,
          );
        }

        // Initial unselected render
        syncFromState();
        expect(manholesCollection.activePlacemarks.length, 1);
        final initialPlacemark = manholesCollection.activePlacemarks.single;
        expect(initialPlacemark.lastIconProvider?.id, contains('norm'));

        // (a) Select manhole -> clear via empty map tap
        mapController.onManholeTap('mh-1');
        syncFromState();
        expect(manholesCollection.activePlacemarks.length, 1);
        final selectedPlacemarkA = manholesCollection.activePlacemarks.single;
        expect(selectedPlacemarkA.lastIconProvider?.id, contains('sel'));
        expect(selectedPlacemarkA.lastIconStyle?.zIndex, 20.0);

        mapController.onMapTap(38.8610, 65.7900);
        expect(container.read(mapControllerProvider).selection, isNull);
        syncFromState();
        expect(
          manholesCollection.removedPlacemarks,
          isEmpty,
          reason: 'Selection changes update the marker in place',
        );
        expect(manholesCollection.activePlacemarks.length, 1);
        final restoredPlacemarkA = manholesCollection.activePlacemarks.single;
        expect(restoredPlacemarkA.lastIconProvider?.id, contains('norm'));
        expect(restoredPlacemarkA.lastIconProvider?.cacheable, isTrue);
        expect(restoredPlacemarkA.lastIconStyle?.zIndex, 10.0);

        // (b) Select manhole -> clear via bottom sheet X button (clearSelection)
        mapController.onManholeTap('mh-1');
        syncFromState();
        final selectedPlacemarkB = manholesCollection.activePlacemarks.single;
        expect(selectedPlacemarkB.lastIconProvider?.id, contains('sel'));

        mapController.clearSelection();
        expect(container.read(mapControllerProvider).selection, isNull);
        syncFromState();
        expect(
          manholesCollection.removedPlacemarks,
          isEmpty,
          reason: 'Selection changes update the marker in place',
        );
        expect(
          manholesCollection.activePlacemarks.single.lastIconProvider?.id,
          contains('norm'),
        );

        // (c) Select manhole -> clear via sheet swipe-down dismiss callback
        mapController.onManholeTap('mh-1');
        syncFromState();
        final selectedPlacemarkC = manholesCollection.activePlacemarks.single;
        expect(selectedPlacemarkC.lastIconProvider?.id, contains('sel'));

        // Sheet swipe down invokes onDismiss -> clearSelection()
        mapController.clearSelection();
        syncFromState();
        expect(
          manholesCollection.removedPlacemarks,
          isEmpty,
          reason: 'Selection changes update the marker in place',
        );
        expect(
          manholesCollection.activePlacemarks.single.lastIconProvider?.id,
          contains('norm'),
        );
      },
    );

    testWidgets(
      'Regression #1c: swiping down on AdaptivePanel details sheet (even over a ListView) triggers onDismissDetails',
      (tester) async {
        var dismissed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Scaffold(
                body: SizedBox(
                  width: 390,
                  height: 844,
                  child: AdaptivePanel(
                    mapChild: const SizedBox.expand(),
                    onDismissDetails: () => dismissed++,
                    detailsBuilder: (context, scrollController) => ListView(
                      controller: scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      children: const [
                        SizedBox(height: 120, child: Text('K-6 Quduq')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const Key('details_sheet_surface')),
          const Offset(0, 220),
        );
        await tester.pumpAndSettle();

        expect(dismissed, 1);
      },
    );

    test(
      'Regression #2: offsetCameraTargetForSheet shifts target south on phone so object sits above bottom sheet',
      () {
        const objLat = 38.8606;
        const objLng = 65.7898;
        final shifted = GeoUtils.offsetCameraTargetForSheet(
          objectLat: objLat,
          objectLng: objLng,
          zoom: 16.0,
          bottomSheetHeightDp: 340,
        );
        // Camera target is shifted south (lower latitude) so the object appears higher on screen
        expect(shifted.lat, lessThan(objLat));
        expect(shifted.lng, closeTo(objLng, 1e-9));
      },
    );
  });
}

class _FakePlacemarkMapObject extends Fake implements ymk.PlacemarkMapObject {
  bool valid = true;
  ymk.Point? lastGeometry;
  ymk_image.ImageProvider? lastIconProvider;
  ymk.IconStyle? lastIconStyle;
  bool isDraggableSet = false;
  final List<ymk.MapObjectTapListener> tapListeners = [];
  ymk.MapObjectDragListener? dragListener;

  @override
  bool isValid() => valid;

  @override
  set geometry(ymk.Point value) {
    lastGeometry = value;
  }

  @override
  void setIconWithStyle(
    ymk_image.ImageProvider image,
    ymk.IconStyle style, {
    ymk.Callback? onFinished,
  }) {
    lastIconProvider = image;
    lastIconStyle = style;
  }

  @override
  set draggable(bool value) {
    isDraggableSet = value;
  }

  @override
  void addTapListener(ymk.MapObjectTapListener tapListener) {
    tapListeners.add(tapListener);
  }

  @override
  void removeTapListener(ymk.MapObjectTapListener tapListener) {
    tapListeners.remove(tapListener);
  }

  @override
  void setDragListener(ymk.MapObjectDragListener? dragListener) {
    this.dragListener = dragListener;
  }
}

class _FakeMapObjectCollection extends Fake implements ymk.MapObjectCollection {
  final List<_FakeMapObjectCollection> subCollections = [];
  final List<_FakePlacemarkMapObject> activePlacemarks = [];
  final List<_FakePlacemarkMapObject> removedPlacemarks = [];

  @override
  bool isValid() => true;

  @override
  ymk.MapObjectCollection addCollection() {
    final sub = _FakeMapObjectCollection();
    subCollections.add(sub);
    return sub;
  }

  @override
  ymk.PlacemarkMapObject addPlacemark() {
    final placemark = _FakePlacemarkMapObject();
    activePlacemarks.add(placemark);
    return placemark;
  }

  @override
  void remove(ymk.MapObject mapObject) {
    if (mapObject is _FakePlacemarkMapObject) {
      mapObject.valid = false;
      activePlacemarks.remove(mapObject);
      removedPlacemarks.add(mapObject);
    }
  }
}

