import 'package:eros_fe/common/controller/auto_lock_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class UnlockPageController extends GetxController {
  final _infoText = ''.obs;
  String get infoText => _infoText.value;
  set infoText(String val) => _infoText.value = val;

  Future<bool> _unlock({required BuildContext context}) async {
    infoText = '';
    try {
      final bool didAuthenticate = await localAuth.authenticate(
        localizedReason: ' ',
        authMessages: <AuthMessages>[
          AutoLockController.iOSAuthMessages,
          AutoLockController.androidAuthMessages,
        ],
      );
      return didAuthenticate;
    } on LocalAuthException catch (e, stack) {
      logger.e('$e\n$stack');
      infoText = e.description ?? e.code.name;
      return false;
    }
  }

  Future<void> unlockToBack({
    required BuildContext context,
    bool autoBack = true,
  }) async {
    // await Future.delayed(kUnLockPageTransitionDuration);
    if (!context.mounted) {
      return;
    }

    final didAuthenticate = await _unlock(context: context);
    if (didAuthenticate && autoBack) {
      Get.back(result: didAuthenticate);
    }
  }
}
