import 'package:flutter/material.dart';

import 'main.dart'; // Add this

class TutorialKeys {
  static final GlobalKey<DashboardShellState> dashboardShellKey = GlobalKey<DashboardShellState>();

  static final GlobalKey addMicKey = GlobalKey();
  static final GlobalKey addTextKey = GlobalKey();
  
  static final GlobalKey noteCardKey = GlobalKey();
  static final GlobalKey noteDeleteKey = GlobalKey();
  static final GlobalKey noteEditKey = GlobalKey();
  static final GlobalKey noteChartKey = GlobalKey();
  static final GlobalKey noteAlarmIconKey = GlobalKey();
  static final GlobalKey noteWalletIconKey = GlobalKey();
  static final GlobalKey noteStarIconKey = GlobalKey();
  
  static final GlobalKey chatInputKey = GlobalKey();
  static final GlobalKey chatPromptsKey = GlobalKey();
  static final GlobalKey chatLimitKey = GlobalKey();
  
  static final GlobalKey reminderCardKey = GlobalKey();
  static final GlobalKey reminderCheckboxKey = GlobalKey();
  static final GlobalKey reminderRecurringIconKey = GlobalKey();
  static final GlobalKey reminderAlarmIconKey = GlobalKey();
  
  static final GlobalKey financeCardKey = GlobalKey();
  static final GlobalKey financeChartToggleKey = GlobalKey();
  static final GlobalKey financeTransactionDeleteKey = GlobalKey();
  static final GlobalKey financeSplitwiseTabKey = GlobalKey();
  static final GlobalKey splitwiseDeleteKey = GlobalKey();
  static final GlobalKey financeAddKey = GlobalKey();
}
