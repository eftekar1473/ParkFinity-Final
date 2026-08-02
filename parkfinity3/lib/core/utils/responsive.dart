import 'package:flutter/material.dart';

/// Breakpoints (dp width)
const kBreakpointMobile  = 600;
const kBreakpointTablet  = 900;

enum ScreenSize { mobile, tablet, desktop }

/// Quick screen-size classifier.
ScreenSize screenSize(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= kBreakpointTablet) return ScreenSize.desktop;
  if (w >= kBreakpointMobile) return ScreenSize.tablet;
  return ScreenSize.mobile;
}

bool isMobile(BuildContext context)  => screenSize(context) == ScreenSize.mobile;
bool isTablet(BuildContext context)  => screenSize(context) == ScreenSize.tablet;
bool isDesktop(BuildContext context) => screenSize(context) == ScreenSize.desktop;

/// Side padding that adapts to width.
double adaptivePadding(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= kBreakpointTablet) return 32;
  if (w >= kBreakpointMobile) return 24;
  return 16;
}

/// Max content width for wide screens.
double adaptiveMaxWidth(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= kBreakpointTablet) return 800;
  if (w >= kBreakpointMobile) return 600;
  return w;
}

/// Column count for grids.
int gridColumns(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= kBreakpointTablet) return 3;
  if (w >= kBreakpointMobile) return 2;
  return 1;
}
