import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

void registerAppLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Poppins',
    ], await rootBundle.loadString('assets/fonts/OFL-Poppins.txt'));
  });
}
