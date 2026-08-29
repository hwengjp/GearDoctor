import '../models/models.dart';

int recommendedLimitFor(String registeredName, CycleKind cycle) {
  if (cycle == CycleKind.months) {
    if (registeredName.contains('電池')) {
      return 12;
    }
    return 24;
  }
  if (registeredName.contains('パッド')) {
    return 1500;
  }
  if (registeredName.contains('オイル')) {
    return 10000;
  }
  if (registeredName.contains('ワイヤー') || registeredName.contains('ケーブル')) {
    return 5000;
  }
  if (registeredName.contains('チェーン')) {
    return 4000;
  }
  if (registeredName.contains('タイヤ')) {
    return 6000;
  }
  if (registeredName.contains('ディスク')) {
    return 8000;
  }
  if (registeredName.contains('バーテープ') || registeredName.contains('プーリー')) {
    return 5000;
  }
  return 6000;
}
