import 'package:flutter/material.dart';
import 'dart:async';

class UndoHelper {
  static void showUndoDeleteSnackbar({
    required BuildContext context,
    required String itemName,
    required VoidCallback onUndo,
    required VoidCallback onExecute,
  }) {
    bool undone = false;
    Timer? timer;
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          Expanded(child: Text('$itemName deleted.')),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            duration: const Duration(seconds: 5),
            builder: (context, value, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: value,
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  Text(
                    '${(value * 5).ceil()}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          undone = true;
          timer?.cancel();
          onUndo();
        },
      ),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final controller = ScaffoldMessenger.of(context).showSnackBar(snackBar);
    
    controller.closed.then((reason) {
      timer?.cancel();
      if (!undone && reason != SnackBarClosedReason.action) {
        onExecute();
      }
    });

    // Explicitly hide after 5 seconds to prevent it hanging around
    timer = Timer(const Duration(seconds: 5), () {
      if (!undone) {
        controller.close();
      }
    });
  }
}
