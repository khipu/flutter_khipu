import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El podspec y el Package.swift tienen que declarar la misma versión de
/// KhipuClientIOS, y el podspec la misma versión que el pubspec. También
/// tienen que declarar el mismo piso de iOS. Son archivos que nadie compara,
/// y el podspec se quedó en 0.0.1 durante ocho releases sin que nada lo
/// notara.
void main() {
  String read(String path) => File(path).readAsStringSync();

  // `multiLine` matters: `version:` is not the first line of pubspec.yaml,
  // so a `^`-anchored pattern needs it to match anywhere but the very start
  // of the file. Without it this silently returns null instead of comparing
  // versions, which fails the test for the wrong reason.
  String? firstMatch(String source, String pattern) =>
      RegExp(pattern, multiLine: true).firstMatch(source)?.group(1);

  test('the podspec version matches the pubspec version', () {
    final String? pubspec = firstMatch(
      read('pubspec.yaml'),
      r"^version:\s*(\S+)",
    );
    final String? podspec = firstMatch(
      read('ios/flutter_khipu.podspec'),
      r"s\.version\s*=\s*'([^']+)'",
    );

    expect(
      pubspec,
      isNotNull,
      reason: 'could not read version from pubspec.yaml',
    );
    expect(
      podspec,
      isNotNull,
      reason: 'could not read s.version from the podspec',
    );
    expect(podspec, pubspec);
  });

  test('both iOS packaging files pin the same KhipuClientIOS', () {
    final String? fromPodspec = firstMatch(
      read('ios/flutter_khipu.podspec'),
      r"KhipuClientIOS',\s*'([^']+)'",
    );
    final String? fromSwift = firstMatch(
      read('ios/flutter_khipu/Package.swift'),
      r'exact:\s*"([^"]+)"',
    );

    expect(fromPodspec, isNotNull, reason: 'could not read the pod dependency');
    expect(fromSwift, isNotNull, reason: 'could not read the SPM dependency');
    expect(
      fromPodspec,
      fromSwift,
      reason: 'CocoaPods and SPM would install different Khipu clients',
    );
  });

  test('both iOS packaging files pin the same deployment target', () {
    final String? fromPodspec = firstMatch(
      read('ios/flutter_khipu.podspec'),
      r"s\.platform\s*=\s*:ios,\s*'([^']+)'",
    );
    final String? fromSwift = firstMatch(
      read('ios/flutter_khipu/Package.swift'),
      r'\.iOS\("([^"]+)"\)',
    );

    expect(
      fromPodspec,
      isNotNull,
      reason: 'could not read s.platform from the podspec',
    );
    expect(
      fromSwift,
      isNotNull,
      reason: 'could not read the iOS platform from Package.swift',
    );
    expect(
      fromPodspec,
      fromSwift,
      reason: 'CocoaPods and SPM would require different iOS deployment '
          'targets',
    );
  });
}
