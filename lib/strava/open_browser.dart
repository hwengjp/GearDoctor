import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// WSL では Linux の url_launcher が失敗することがあるので、Windows のブラウザを直接起動する。
/// `explorer.exe` や、引用なしの `cmd start` は `&` で URL が切れ、フォルダが開くので使わない。
Future<bool> openInBrowser(Uri url) async {
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
      return true;
    }
  } catch (_) {}

  if (!Platform.isLinux) {
    return false;
  }

  final href = url.toString();
  for (final browser in _windowsBrowsers()) {
    if (await _run(browser, [href])) {
      return true;
    }
  }

  final escaped = href.replaceAll("'", "''");
  if (await _run('/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe', [
        '-NoProfile',
        '-Command',
        "Start-Process '$escaped'",
      ])) {
    return true;
  }

  if (await _run('wslview', [href])) {
    return true;
  }
  return _run('xdg-open', [href]);
}

Future<bool> _run(String executable, List<String> arguments) async {
  if (!File(executable).existsSync() &&
      executable.startsWith('/mnt/c/') ) {
    return false;
  }
  try {
    final result = await Process.run(executable, arguments);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Iterable<String> _windowsBrowsers() sync* {
  yield '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe';
  yield '/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe';
  yield '/mnt/c/Program Files/Microsoft/Edge/Application/msedge.exe';
  yield '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
  final users = Directory('/mnt/c/Users');
  if (!users.existsSync()) {
    return;
  }
  const skip = {'All Users', 'Default', 'Default User', 'Public'};
  try {
    for (final entity in users.listSync()) {
      if (entity is! Directory) {
        continue;
      }
      final name = entity.path.split('/').last;
      if (skip.contains(name)) {
        continue;
      }
      yield '${entity.path}/AppData/Local/Google/Chrome/Application/chrome.exe';
      yield '${entity.path}/AppData/Local/Microsoft/Edge/Application/msedge.exe';
    }
  } catch (_) {}
}
