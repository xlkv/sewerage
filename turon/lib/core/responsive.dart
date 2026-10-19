import 'package:flutter/widgets.dart';

const double kTabletBreakpoint = 600.0;
const double kSidePanelWidth = 380.0;

bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpoint;
