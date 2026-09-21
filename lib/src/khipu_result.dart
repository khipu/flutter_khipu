import 'package:meta/meta.dart';

import 'messages.g.dart' as pigeon;
// `export` alone re-exports KhipuResultStatus for importers of this file; it
// does not bring the name into scope here, so this file also needs its own
// unprefixed import to use KhipuResultStatus in the field type below.
import 'messages.g.dart' show KhipuResultStatus;

export 'messages.g.dart' show KhipuResultStatus;

/// A milestone of the payment, as reported by the SDK.
@immutable
class KhipuEvent {
  const KhipuEvent({
    required this.name,
    required this.type,
    required this.timestamp,
  });

  /// All three are non-null: measured on `khipu-client-android` 2.28.5, the
  /// constructor of `com.khipu.client.KhipuEvent` checks them with
  /// `checkNotNullParameter`.
  final String name;
  final String type;
  final String timestamp;

  factory KhipuEvent._fromPigeon(pigeon.KhipuEvent e) => KhipuEvent(
        name: e.name,
        type: e.type,
        timestamp: e.timestamp,
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuEvent &&
      other.name == name &&
      other.type == type &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(name, type, timestamp);

  @override
  String toString() =>
      'KhipuEvent(name: $name, type: $type, timestamp: $timestamp)';
}

/// The outcome of the payment.
///
/// The five non-null fields are so because the SDK declares them that way
/// on both platforms (§2.3 of the design doc). The three optionals —
/// [exitUrl], [failureReason] and [continueUrl]— are exactly the ones the
/// SDK declares `@Nullable`, and they always travel: Pigeon serializes a
/// positional list, so an empty field takes its place with `null` and there
/// is no key to omit.
@immutable
class KhipuResult {
  const KhipuResult({
    required this.operationId,
    required this.result,
    required this.exitTitle,
    required this.exitMessage,
    required this.events,
    this.exitUrl,
    this.failureReason,
    this.continueUrl,
  });

  final String operationId;

  /// What happened with the payment. Can be [KhipuResultStatus.unknown] if
  /// the server emitted a value this plugin does not know yet.
  final KhipuResultStatus result;

  final String exitTitle;
  final String exitMessage;

  /// The payment's milestones, in order. Its own, fixed-length list: the
  /// wrapper copies the one the channel delivers, which is a view that
  /// casts on each access.
  final List<KhipuEvent> events;

  /// Where to return to when the payment finished. Null if not applicable.
  final String? exitUrl;

  /// Why it failed. Null if it did not fail.
  final String? failureReason;

  /// Where to continue to when the payment was left halfway. Null if not
  /// applicable.
  final String? continueUrl;

  factory KhipuResult.fromPigeon(pigeon.KhipuResult r) => KhipuResult(
        operationId: r.operationId,
        result: r.result,
        exitTitle: r.exitTitle,
        exitMessage: r.exitMessage,
        exitUrl: r.exitUrl,
        failureReason: r.failureReason,
        continueUrl: r.continueUrl,
        events: r.events.isEmpty
            ? const <KhipuEvent>[]
            : List<KhipuEvent>.unmodifiable(
                r.events.map(KhipuEvent._fromPigeon),
              ),
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuResult &&
      other.operationId == operationId &&
      other.result == result &&
      other.exitTitle == exitTitle &&
      other.exitMessage == exitMessage &&
      other.exitUrl == exitUrl &&
      other.failureReason == failureReason &&
      other.continueUrl == continueUrl &&
      _sameEvents(other.events, events);

  static bool _sameEvents(List<KhipuEvent> a, List<KhipuEvent> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        operationId,
        result,
        exitTitle,
        exitMessage,
        exitUrl,
        failureReason,
        continueUrl,
        Object.hashAll(events),
      );

  @override
  String toString() => 'KhipuResult(operationId: $operationId, '
      'result: $result, events: ${events.length})';
}
