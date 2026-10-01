import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 12),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final path = Platform.environment['FINTRACK_QA_REPORT'];
    if (path != null) {
      await File(
        path,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    }
  },
);
