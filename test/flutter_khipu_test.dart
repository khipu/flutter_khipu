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
      // Five booleans, two possible values: by the pigeonhole principle any
      // single round has at least three fields sharing a value, so a swap
      // between two of those three passes undetected — e.g. skipExitPage
      // and showFooter, both true in one round. Three rounds, each field
      // carrying its own triple across them (TFF, FTF, FFT, TTF, TFT — all
      // distinct), close that gap: any swap between any pair of fields
      // changes at least one round.
      final List<Map<String, bool>> booleanRounds = <Map<String, bool>>[
        <String, bool>{
          'skipExitPage': true,
          'skipExitSuccessPage': false,
          'showFooter': false,
          'showMerchantLogo': true,
          'showPaymentDetails': true,
        },
        <String, bool>{
          'skipExitPage': false,
          'skipExitSuccessPage': true,
          'showFooter': false,
          'showMerchantLogo': true,
          'showPaymentDetails': false,
        },
        <String, bool>{
          'skipExitPage': false,
          'skipExitSuccessPage': false,
          'showFooter': true,
          'showMerchantLogo': false,
          'showPaymentDetails': true,
        },
      ];

      for (final Map<String, bool> round in booleanRounds) {
        late pigeon.KhipuStartOperationOptions seen;
        mockHost((pigeon.KhipuStartOperationOptions o) {
          seen = o;
          return nativeResult();
        });

        await khipu.startOperation(
          KhipuStartOperationOptions(
            operationId: 'abc123',
            title: 'Mi comercio',
            titleImageUrl: 'https://example.com/logo.png',
            locale: 'es_CL',
            skipExitPage: round['skipExitPage'],
            skipExitSuccessPage: round['skipExitSuccessPage'],
            showFooter: round['showFooter'],
            showMerchantLogo: round['showMerchantLogo'],
            showPaymentDetails: round['showPaymentDetails'],
            theme: KhipuTheme.dark,
          ),
        );

        expect(seen.operationId, 'abc123');
        expect(seen.title, 'Mi comercio');
        expect(seen.titleImageUrl, 'https://example.com/logo.png');
        expect(seen.locale, 'es_CL');
        expect(seen.skipExitPage, round['skipExitPage']);
        expect(seen.skipExitSuccessPage, round['skipExitSuccessPage']);
        expect(seen.showFooter, round['showFooter']);
        expect(seen.showMerchantLogo, round['showMerchantLogo']);
        expect(seen.showPaymentDetails, round['showPaymentDetails']);
        expect(seen.theme, pigeon.KhipuTheme.dark);
      }
    });

    test('sends the palette nested, not twelve loose keys', () async {
      // Partial construction: most fields stay unset and must travel as
      // null, not silently pick up a neighbour's value.
      late pigeon.KhipuStartOperationOptions seenPartial;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seenPartial = o;
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

      expect(seenPartial.colors, isNotNull);
      expect(seenPartial.colors!.lightPrimary, '#8347AD');
      expect(seenPartial.colors!.darkPrimary, '#3CB4E5');
      expect(seenPartial.colors!.lightBackground, isNull);

      // Each field gets its own name as its value, so a field swapped with
      // its neighbour fails with a message naming exactly which one.
      late pigeon.KhipuStartOperationOptions seen;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seen = o;
        return nativeResult();
      });

      await khipu.startOperation(
        const KhipuStartOperationOptions(
          operationId: 'abc123',
          colors: KhipuColors(
            lightBackground: 'lightBackground',
            lightOnBackground: 'lightOnBackground',
            lightPrimary: 'lightPrimary',
            lightOnPrimary: 'lightOnPrimary',
            lightTopBarContainer: 'lightTopBarContainer',
            lightOnTopBarContainer: 'lightOnTopBarContainer',
            darkBackground: 'darkBackground',
            darkOnBackground: 'darkOnBackground',
            darkPrimary: 'darkPrimary',
            darkOnPrimary: 'darkOnPrimary',
            darkTopBarContainer: 'darkTopBarContainer',
            darkOnTopBarContainer: 'darkOnTopBarContainer',
          ),
        ),
      );

      expect(seen.colors, isNotNull);
      final pigeon.KhipuColors colors = seen.colors!;
      final Map<String, String?> sentByField = <String, String?>{
        'lightBackground': colors.lightBackground,
        'lightOnBackground': colors.lightOnBackground,
        'lightPrimary': colors.lightPrimary,
        'lightOnPrimary': colors.lightOnPrimary,
        'lightTopBarContainer': colors.lightTopBarContainer,
        'lightOnTopBarContainer': colors.lightOnTopBarContainer,
        'darkBackground': colors.darkBackground,
        'darkOnBackground': colors.darkOnBackground,
        'darkPrimary': colors.darkPrimary,
        'darkOnPrimary': colors.darkOnPrimary,
        'darkTopBarContainer': colors.darkTopBarContainer,
        'darkOnTopBarContainer': colors.darkOnTopBarContainer,
      };
      for (final MapEntry<String, String?> field in sentByField.entries) {
        expect(
          field.value,
          field.key,
          reason: '${field.key} is mismapped on the wire',
        );
      }
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
      // exitUrl, failureReason and continueUrl used to travel together —
      // exitUrl set, the other two always null — so a swap among the three
      // went undetected. Cover both the all-null shape and one where all
      // three carry distinct values.
      mockHost((_) => nativeResult(exitUrl: null));

      final KhipuResult? withoutOptionals = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(withoutOptionals, isNotNull);
      expect(withoutOptionals!.exitUrl, isNull);
      expect(withoutOptionals.failureReason, isNull);
      expect(withoutOptionals.continueUrl, isNull);

      mockHost(
        (_) => nativeResult(
          exitUrl: 'https://khipu.com/done',
          failureReason: 'INSUFFICIENT_FUNDS',
          continueUrl: 'https://khipu.com/continue',
          events: <pigeon.KhipuEvent>[
            pigeon.KhipuEvent(
              name: 'start',
              type: 'info',
              timestamp: '2026-09-21T10:00:00Z',
            ),
            pigeon.KhipuEvent(
              name: 'authorized',
              type: 'success',
              timestamp: '2026-09-21T10:01:00Z',
            ),
          ],
        ),
      );

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(r, isNotNull);
      expect(r!.operationId, 'abc123');
      expect(r.result, KhipuResultStatus.ok);
      expect(r.exitTitle, 'Listo');
      expect(r.exitUrl, 'https://khipu.com/done');
      expect(r.failureReason, 'INSUFFICIENT_FUNDS');
      expect(r.continueUrl, 'https://khipu.com/continue');

      // Two events with distinct fields, checked by index: a single-element
      // list can't reveal whether order is preserved.
      expect(r.events, hasLength(2));
      expect(r.events[0].name, 'start');
      expect(r.events[0].type, 'info');
      expect(r.events[0].timestamp, '2026-09-21T10:00:00Z');
      expect(r.events[1].name, 'authorized');
      expect(r.events[1].type, 'success');
      expect(r.events[1].timestamp, '2026-09-21T10:01:00Z');
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
