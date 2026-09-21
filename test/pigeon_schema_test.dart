import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Pigeon schema is the single source of the channel's shape, and two
/// of its properties are ones no behavior test can defend.
///
/// The first is the empty-value encoding that PR #18 pinned. Pigeon
/// serializes a positional list, not a map, so there's no key to omit: the
/// requirement holds by construction as long as the three fields stay
/// nullable. The only thing that could break it is someone making them
/// required in the schema, and that's what this test watches.
///
/// The second is the `unknown` case of KhipuResultStatus. Removing it
/// breaks no test: it breaks in production, the day the server emits a new
/// value.
void main() {
  final String schema = File('pigeons/khipu_api.dart').readAsStringSync();

  test('the three optional fields of KhipuResult stay nullable', () {
    for (final String field in <String>[
      'exitUrl',
      'failureReason',
      'continueUrl',
    ]) {
      expect(
        schema,
        contains('String? $field;'),
        reason: 'PR #18 pinned that the three optional fields always '
            'travel. With Pigeon that holds by staying nullable: $field '
            'stopped being one.',
      );
    }
  });

  test('KhipuResultStatus keeps the unknown case', () {
    expect(schema, contains('enum KhipuResultStatus'));
    expect(
      schema,
      contains('unknown,'),
      reason: 'Without unknown, a new value from the server breaks '
          'decoding of the entire message.',
    );
  });

  test('the five values the SDK can emit are covered', () {
    // Measured against the bytecode of KhipuActivityKt in
    // khipu-client-android 2.28.5: OK, ERROR, WARNING, CONTINUE,
    // USER_CANCELED. `mustContinue` is CONTINUE renamed, because `continue`
    // is reserved in the three languages Pigeon generates.
    for (final String c in <String>[
      'ok,',
      'error,',
      'warning,',
      'mustContinue,',
      'userCanceled,',
    ]) {
      expect(schema, contains(c));
    }
  });
}
