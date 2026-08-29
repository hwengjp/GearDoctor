import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/app_version.dart';

void main() {
  test('settings shows GearDoctor and the app version', () {
    expect(appName, 'GearDoctor');
    expect(appVersionLabel, 'GearDoctor $appVersion');
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(appVersion), isTrue);
  });
}
