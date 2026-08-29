import 'package:flutter/material.dart';
import '../../core/utils/snackbar_helper.dart';

class ErrorDialog {
  ErrorDialog._();

  static Future<void> show(BuildContext context, String message) {
    return SnackbarHelper.showError(context, message);
  }
}
