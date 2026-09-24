import 'package:flutter/material.dart';

import 'main.dart'; // Add this

class TutorialKeys {
  static final GlobalKey<DashboardShellState> dashboardShellKey = GlobalKey<DashboardShellState>();

  static final GlobalKey addMicKey = GlobalKey();
  static final GlobalKey addTextKey = GlobalKey();
  
  static final GlobalKey noteCardKey = GlobalKey();
  static final GlobalKey noteDeleteKey = GlobalKey();
  static final GlobalKey noteEditKey = GlobalKey();
  
  static final GlobalKey chatInputKey = GlobalKey();
  
  static final GlobalKey reminderCardKey = GlobalKey();
  
  static final GlobalKey financeCardKey = GlobalKey();
  static final GlobalKey financeAddKey = GlobalKey();
}
