import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The method channel carries options as a flat map of primitives, so the key
/// names are the contract between Dart and each native side — and nothing in
/// either language checks them. A key renamed on one side silently disables that
/// option: no compile error, no runtime error, just a setting that stops working.
///
/// These tests read the three sources and compare the key sets directly. That is
/// the only place this class of drift is visible, because a unit test on either
/// side can only ever see its own half of the wire.
void main() {
  /// Keys Dart puts into the `startOperation` argument map.
  Set<String> keysSentByDart() {
    final String source =
        File('lib/flutter_khipu_method_channel.dart').readAsStringSync();
    return RegExp(r"'(\w+)':\s*options")
        .allMatches(source)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
  }

  /// Keys the iOS plugin reads back out of that map.
  Set<String> keysReadByIos() {
    final String source =
        File('ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift')
            .readAsStringSync();
    return RegExp(r'args\["(\w+)"\]')
        .allMatches(source)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
  }

  /// Keys the Android plugin reads. Matched through `call.argument`/`hasArgument`
  /// specifically, because the same file also writes the result keys and a looser
  /// pattern would pick those up as if they were arguments.
  Set<String> keysReadByAndroid() {
    final String source = File(
      'android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt',
    ).readAsStringSync();
    return RegExp(r'(?:hasArgument|argument<[^>]*>)\("(\w+)"\)')
        .allMatches(source)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
  }

  // If a source file is reformatted so a pattern stops matching, the sets would
  // silently collapse to empty and compare equal. These guards make that a
  // failure instead — a broken extractor must never look like a passing seam.
  group('the extractors actually found something', () {
    test('Dart sends a plausible number of keys', () {
      expect(keysSentByDart().length, greaterThanOrEqualTo(20),
          reason: 'the Dart extractor matched almost nothing — the argument map '
              'was probably reformatted, so this test is no longer reading it');
    });

    test('iOS reads a plausible number of keys', () {
      expect(keysReadByIos().length, greaterThanOrEqualTo(20),
          reason: 'the iOS extractor matched almost nothing — args["…"] lookups '
              'were probably refactored, so this test is no longer reading them');
    });

    test('Android reads a plausible number of keys', () {
      expect(keysReadByAndroid().length, greaterThanOrEqualTo(20),
          reason: 'the Android extractor matched almost nothing — the '
              'call.argument lookups were probably refactored');
    });
  });

  group('the wire contract holds', () {
    test('iOS consumes exactly the keys Dart sends', () {
      final Set<String> sent = keysSentByDart();
      final Set<String> read = keysReadByIos();

      expect(sent.difference(read), isEmpty,
          reason: 'Dart sends these but iOS never reads them, so they are '
              'silently ignored on iOS');
      expect(read.difference(sent), isEmpty,
          reason: 'iOS reads these but Dart never sends them, so they are dead '
              'lookups that will always be null');
    });

    test('Android consumes exactly the keys Dart sends', () {
      final Set<String> sent = keysSentByDart();
      final Set<String> read = keysReadByAndroid();

      expect(sent.difference(read), isEmpty,
          reason: 'Dart sends these but Android never reads them, so they are '
              'silently ignored on Android');
      expect(read.difference(sent), isEmpty,
          reason: 'Android reads these but Dart never sends them, so they are '
              'dead lookups that will always be null');
    });

    test('both platforms honour the same options', () {
      expect(keysReadByIos(), keysReadByAndroid(),
          reason: 'the two platforms disagree about which options exist, so an '
              'option works on one and is ignored on the other');
    });
  });

  // The result travels back over the same flat map, and this direction is now the
  // more dangerous of the two. Before 1.7.1 a renamed result key made
  // KhipuResult.fromJson throw on a non-null cast — loud, immediate, findable.
  // Widening those casts to String? fixed a real crash but also removed the alarm:
  // a rename now yields a silently null field instead. So this half of the seam
  // lost its only detector precisely when the crash was fixed.

  /// Result keys Dart reads back out of the reply.
  Set<String> keysReadFromResultByDart() {
    final String source = File('lib/flutter_khipu.dart').readAsStringSync();
    return RegExp(r"(?:json|map)\['(\w+)'\]")
        .allMatches(source)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
  }

  /// Result keys the iOS plugin writes into the reply.
  Set<String> keysWrittenToResultByIos() {
    final String source =
        File('ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift')
            .readAsStringSync();
    return RegExp(r'"(\w+)":\s*(?:khipuResult|event)')
        .allMatches(source)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
  }

  /// Result keys the Android plugin writes into the reply.
  Set<String> keysWrittenToResultByAndroid() {
    final String source = File(
      'android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt',
    ).readAsStringSync();
    return <String>{
      ...RegExp(r'\["(\w+)"\]\s*=')
          .allMatches(source)
          .map((RegExpMatch m) => m.group(1)!),
      ...RegExp(r'"(\w+)"\s+to\s')
          .allMatches(source)
          .map((RegExpMatch m) => m.group(1)!),
    };
  }

  group('the result extractors actually found something', () {
    test('Dart reads a plausible number of result keys', () {
      expect(keysReadFromResultByDart().length, greaterThanOrEqualTo(10),
          reason: 'the Dart result extractor matched almost nothing — fromJson '
              'was probably refactored, so this test no longer reads it');
    });

    test('iOS writes a plausible number of result keys', () {
      expect(keysWrittenToResultByIos().length, greaterThanOrEqualTo(10),
          reason: 'the iOS result extractor matched almost nothing');
    });

    test('Android writes a plausible number of result keys', () {
      expect(keysWrittenToResultByAndroid().length, greaterThanOrEqualTo(10),
          reason: 'the Android result extractor matched almost nothing');
    });
  });

  group('the result contract holds', () {
    test('iOS returns exactly the keys Dart reads', () {
      final Set<String> read = keysReadFromResultByDart();
      final Set<String> written = keysWrittenToResultByIos();

      expect(read.difference(written), isEmpty,
          reason: 'Dart reads these but iOS never returns them, so they arrive '
              'null with no error — invisible since the casts became String?');
      expect(written.difference(read), isEmpty,
          reason: 'iOS returns these but Dart never reads them, so the value is '
              'computed and thrown away');
    });

    test('Android returns exactly the keys Dart reads', () {
      final Set<String> read = keysReadFromResultByDart();
      final Set<String> written = keysWrittenToResultByAndroid();

      expect(read.difference(written), isEmpty,
          reason: 'Dart reads these but Android never returns them, so they '
              'arrive null with no error');
      expect(written.difference(read), isEmpty,
          reason: 'Android returns these but Dart never reads them');
    });

    test('both platforms return the same shape', () {
      expect(keysWrittenToResultByIos(), keysWrittenToResultByAndroid(),
          reason: 'the two platforms disagree about the result shape, so a field '
              'is populated on one platform and null on the other');
    });
  });
}
