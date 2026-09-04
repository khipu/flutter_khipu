import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_khipu/flutter_khipu.dart';
import 'package:flutter_khipu/flutter_khipu_method_channel.dart';

/// A result payload shaped like the one the native side sends back.
Map<String, Object?> nativeResult({
  String? exitUrl = 'https://khipu.com/done',
  String? failureReason,
  String? continueUrl,
  List<Object?>? events,
}) {
  return <String, Object?>{
    'operationId': 'abc123',
    'result': 'OK',
    'exitTitle': 'Listo',
    'exitMessage': 'Pago realizado',
    'exitUrl': exitUrl,
    'failureReason': failureReason,
    'continueUrl': continueUrl,
    'events': events ??
        <Object?>[
          <String, Object?>{
            'name': 'start',
            'type': 'info',
            'timestamp': '2026-09-04T10:00:00Z',
          },
        ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelFlutterKhipu platform = MethodChannelFlutterKhipu();
  const MethodChannel channel = MethodChannel('flutter_khipu');

  /// The calls the plugin made during a test, in order.
  final List<MethodCall> calls = <MethodCall>[];

  /// What the mocked native side answers. Reassign inside a test to change it.
  late Object? Function(MethodCall) respond;

  setUp(() {
    calls.clear();
    respond = (MethodCall _) => nativeResult();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      return respond(methodCall);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<Object?, Object?> argumentsOf(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  group('startOperation invocation', () {
    test('invokes the startOperation method', () async {
      await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'startOperation');
    });

    test('sends exactly the argument keys the native side reads', () async {
      // The native side reads each option out of the argument map by name, so a
      // renamed or dropped key silently disables that option instead of
      // failing. Pinning the whole key set makes that break a test instead.
      await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(
        argumentsOf(calls.single).keys.toSet(),
        <String>{
          'operationId',
          'title',
          'titleImageUrl',
          'locale',
          'skipExitPage',
          'skipExitSuccessPage',
          'showFooter',
          'showMerchantLogo',
          'showPaymentDetails',
          'theme',
          'lightBackground',
          'lightOnBackground',
          'lightPrimary',
          'lightOnPrimary',
          'lightTopBarContainer',
          'lightOnTopBarContainer',
          'darkBackground',
          'darkOnBackground',
          'darkPrimary',
          'darkOnPrimary',
          'darkTopBarContainer',
          'darkOnTopBarContainer',
        },
      );
    });

    test('passes the scalar options through', () async {
      await platform.startOperation(
        KhipuStartOperationOptions(
          operationId: 'abc123',
          title: 'Mi comercio',
          titleImageUrl: 'https://example.com/logo.png',
          locale: 'es_CL',
          theme: 'dark',
          skipExitPage: true,
          skipExitSuccessPage: false,
          showFooter: false,
          showMerchantLogo: true,
          showPaymentDetails: false,
        ),
      );

      final Map<Object?, Object?> args = argumentsOf(calls.single);
      expect(args['operationId'], 'abc123');
      expect(args['title'], 'Mi comercio');
      expect(args['titleImageUrl'], 'https://example.com/logo.png');
      expect(args['locale'], 'es_CL');
      expect(args['theme'], 'dark');
      expect(args['skipExitPage'], isTrue);
      expect(args['skipExitSuccessPage'], isFalse);
      expect(args['showFooter'], isFalse);
      expect(args['showMerchantLogo'], isTrue);
      expect(args['showPaymentDetails'], isFalse);
    });

    test('flattens every colour onto its own top level key', () async {
      // KhipuColors is nested in Dart but flat on the wire. Each field gets its
      // own name as its value here, so a mismapped colour shows up as a
      // mismatch rather than as a colour that quietly never applies.
      await platform.startOperation(
        KhipuStartOperationOptions(
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

      final Map<Object?, Object?> args = argumentsOf(calls.single);
      for (final String field in <String>[
        'lightBackground',
        'lightOnBackground',
        'lightPrimary',
        'lightOnPrimary',
        'lightTopBarContainer',
        'lightOnTopBarContainer',
        'darkBackground',
        'darkOnBackground',
        'darkPrimary',
        'darkOnPrimary',
        'darkTopBarContainer',
        'darkOnTopBarContainer',
      ]) {
        expect(args[field], field, reason: '$field is mismapped on the wire');
      }
    });

    test('sends null colours when no palette is given', () async {
      await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      final Map<Object?, Object?> args = argumentsOf(calls.single);
      expect(args['lightPrimary'], isNull);
      expect(args['darkPrimary'], isNull);
    });
  });

  group('result parsing', () {
    test('maps a full payload onto KhipuResult', () async {
      respond = (MethodCall _) => nativeResult(
            failureReason: 'none',
            continueUrl: 'https://khipu.com/continue',
          );

      final KhipuResult? result = await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(result, isNotNull);
      expect(result!.operationId, 'abc123');
      expect(result.result, 'OK');
      expect(result.exitTitle, 'Listo');
      expect(result.exitMessage, 'Pago realizado');
      expect(result.exitUrl, 'https://khipu.com/done');
      expect(result.failureReason, 'none');
      expect(result.continueUrl, 'https://khipu.com/continue');
    });

    test('parses the event list', () async {
      respond = (MethodCall _) => nativeResult(events: <Object?>[
            <String, Object?>{
              'name': 'start',
              'type': 'info',
              'timestamp': '2026-09-04T10:00:00Z',
            },
            <String, Object?>{
              'name': 'authorized',
              'type': 'success',
              'timestamp': '2026-09-04T10:01:00Z',
            },
          ]);

      final KhipuResult? result = await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      final List<KhipuEvent> events = result!.events!.toList();
      expect(events, hasLength(2));
      expect(events.first.name, 'start');
      expect(events.first.type, 'info');
      expect(events.first.timestamp, '2026-09-04T10:00:00Z');
      expect(events.last.name, 'authorized');
    });

    test('accepts an empty event list', () async {
      respond = (MethodCall _) => nativeResult(events: <Object?>[]);

      final KhipuResult? result = await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(result!.events, isEmpty);
    });

    test('leaves the optional fields null when the native side omits them',
        () async {
      respond = (MethodCall _) => nativeResult();

      final KhipuResult? result = await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(result!.failureReason, isNull);
      expect(result.continueUrl, isNull);
    });

    test('survives an event with null fields', () async {
      // KhipuEvent's fields are all declared nullable, so parsing must tolerate
      // a partial event rather than throwing on the cast.
      respond = (MethodCall _) => nativeResult(events: <Object?>[
            <String, Object?>{
              'name': null,
              'type': null,
              'timestamp': null,
            },
          ]);

      final KhipuResult? result = await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      final KhipuEvent event = result!.events!.single;
      expect(event.name, isNull);
      expect(event.type, isNull);
      expect(event.timestamp, isNull);
    });

    test('survives a null exitUrl', () async {
      // FlutterKhipuPlugin.swift sends exitUrl with `as Any`, the same as the
      // fields it treats as optional, so a nil arrives here as null.
      respond = (MethodCall _) => nativeResult(exitUrl: null);

      final KhipuResult? result = await platform.startOperation(
        KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(result!.exitUrl, isNull);
    });
  });
}
