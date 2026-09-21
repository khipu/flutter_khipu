import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_khipu/flutter_khipu.dart';

import 'package:flutter_khipu/src/messages.g.dart' as pigeon;

/// Answers the Pigeon channel the way the native side would.
///
/// Pigeon names each channel `dev.flutter.pigeon.<package>.<api>.<method>`,
/// and encodes arguments and response with its own codec. Intercepting it
/// here is the Pigeon equivalent of the old `setMockMethodCallHandler`.
///
/// `setMockDecodedMessageHandler` takes the `BasicMessageChannel` itself
/// (built from the same name and codec `KhipuHostApi.startOperation` uses
/// internally), not a bare `(codec, name)` pair.
void mockHost(
  Object? Function(pigeon.KhipuStartOperationOptions options) respond,
) {
  const String name =
      'dev.flutter.pigeon.flutter_khipu.KhipuHostApi.startOperation';
  final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
    name,
    pigeon.KhipuHostApi.pigeonChannelCodec,
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, (Object? message) async {
    final List<Object?> args = message! as List<Object?>;
    final options = args[0]! as pigeon.KhipuStartOperationOptions;
    return <Object?>[respond(options)];
  });
}

/// A complete native result, in the generated types.
pigeon.KhipuResult nativeResult({
  pigeon.KhipuResultStatus result = pigeon.KhipuResultStatus.ok,
  String? exitUrl = 'https://khipu.com/done',
  String? failureReason,
  String? continueUrl,
  List<pigeon.KhipuEvent>? events,
}) {
  return pigeon.KhipuResult(
    operationId: 'abc123',
    result: result,
    exitTitle: 'Listo',
    exitMessage: 'Pago realizado',
    exitUrl: exitUrl,
    failureReason: failureReason,
    continueUrl: continueUrl,
    events: events ??
        <pigeon.KhipuEvent>[
          pigeon.KhipuEvent(
            name: 'start',
            type: 'info',
            timestamp: '2026-09-21T10:00:00Z',
          ),
        ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final FlutterKhipu khipu = FlutterKhipu();

  group('startOperation', () {
    test('passes the scalar options to the native side', () async {
      late pigeon.KhipuStartOperationOptions seen;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seen = o;
        return nativeResult();
      });

      await khipu.startOperation(
        const KhipuStartOperationOptions(
          operationId: 'abc123',
          title: 'Mi comercio',
          locale: 'es_CL',
          skipExitPage: true,
          theme: KhipuTheme.dark,
        ),
      );

      expect(seen.operationId, 'abc123');
      expect(seen.title, 'Mi comercio');
      expect(seen.locale, 'es_CL');
      expect(seen.skipExitPage, isTrue);
      expect(seen.theme, pigeon.KhipuTheme.dark);
    });

    test('sends the palette nested, not twelve loose keys', () async {
      late pigeon.KhipuStartOperationOptions seen;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seen = o;
        return nativeResult();
      });

      await khipu.startOperation(
        const KhipuStartOperationOptions(
          operationId: 'abc123',
          colors: KhipuColors(
            lightPrimary: '#8347AD',
            darkPrimary: '#3CB4E5',
          ),
        ),
      );

      expect(seen.colors, isNotNull);
      expect(seen.colors!.lightPrimary, '#8347AD');
      expect(seen.colors!.darkPrimary, '#3CB4E5');
      expect(seen.colors!.lightBackground, isNull);
    });

    test('leaves the palette null when none was given', () async {
      late pigeon.KhipuStartOperationOptions seen;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seen = o;
        return nativeResult();
      });

      await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(seen.colors, isNull);
    });
  });

  group('result', () {
    test('maps a complete result', () async {
      mockHost((_) => nativeResult());

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(r, isNotNull);
      expect(r!.operationId, 'abc123');
      expect(r.result, KhipuResultStatus.ok);
      expect(r.exitTitle, 'Listo');
      expect(r.exitUrl, 'https://khipu.com/done');
      expect(r.failureReason, isNull);
      expect(r.continueUrl, isNull);
      expect(r.events, hasLength(1));
      expect(r.events.single.name, 'start');
    });

    test('events is its own list, not a view over the message', () async {
      mockHost((_) => nativeResult());

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      // Pigeon delivers a CastList, which is a view over the list the
      // channel decoded and casts on every access. The wrapper copies it.
      expect(r!.events, isA<List<KhipuEvent>>());
      expect(() => r.events.add(r.events.first), throwsUnsupportedError);
    });

    test('an empty events list arrives as const []', () async {
      mockHost((_) => nativeResult(events: <pigeon.KhipuEvent>[]));

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(r!.events, isEmpty);
    });

    test('returns null when the native side sends no result', () async {
      mockHost((_) => null);

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(r, isNull);
    });

    test('the five SDK statuses cross the channel', () async {
      for (final pigeon.KhipuResultStatus s in <pigeon.KhipuResultStatus>[
        pigeon.KhipuResultStatus.ok,
        pigeon.KhipuResultStatus.error,
        pigeon.KhipuResultStatus.warning,
        pigeon.KhipuResultStatus.mustContinue,
        pigeon.KhipuResultStatus.userCanceled,
      ]) {
        mockHost((_) => nativeResult(result: s));

        final KhipuResult? r = await khipu.startOperation(
          const KhipuStartOperationOptions(operationId: 'abc123'),
        );

        expect(r!.result.name, s.name);
      }
    });
  });

  group('value', () {
    test('two results with the same fields are equal', () {
      const KhipuResult a = KhipuResult(
        operationId: 'abc123',
        result: KhipuResultStatus.ok,
        exitTitle: 'Listo',
        exitMessage: 'Pago realizado',
        events: <KhipuEvent>[],
      );
      const KhipuResult b = KhipuResult(
        operationId: 'abc123',
        result: KhipuResultStatus.ok,
        exitTitle: 'Listo',
        exitMessage: 'Pago realizado',
        events: <KhipuEvent>[],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString names the status', () {
      const KhipuResult a = KhipuResult(
        operationId: 'abc123',
        result: KhipuResultStatus.userCanceled,
        exitTitle: 'Cancelado',
        exitMessage: 'La persona salió',
        events: <KhipuEvent>[],
      );

      expect(a.toString(), contains('userCanceled'));
    });
  });
}
