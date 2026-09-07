import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ToastService {
  static final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(
    String message, {
    bool isError = false,
    Color? backgroundColor,
  }) {
    void present() {
      try {
        final messenger = rootMessengerKey.currentState;
        if (messenger == null) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[Toast] $message');
          }
          return;
        }

        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: backgroundColor ??
                (isError ? const Color(0xFFEF4444) : null),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e, stack) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[Toast] $message (error: $e)');
          // ignore: avoid_print
          print(stack);
        }
      }
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => present());
    } else {
      present();
    }
  }
}
