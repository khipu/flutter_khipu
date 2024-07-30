import 'flutter_khipu_platform_interface.dart';

class FlutterKhipu {
  Future<KhipuResult?> startOperation(KhipuStartOperationOptions options) {
    return FlutterKhipuPlatform.instance.startOperation(options);
  }
}

class KhipuColors {
  String? lightBackground;
  String? lightOnBackground;
  String? lightPrimary;
  String? lightOnPrimary;
  String? lightTopBarContainer;
  String? lightOnTopBarContainer;
  String? darkBackground;
  String? darkOnBackground;
  String? darkPrimary;
  String? darkOnPrimary;
  String? darkTopBarContainer;
  String? darkOnTopBarContainer;

  KhipuColors({
    this.lightBackground,
    this.lightOnBackground,
    this.lightPrimary,
    this.lightOnPrimary,
    this.lightTopBarContainer,
    this.lightOnTopBarContainer,
    this.darkBackground,
    this.darkOnBackground,
    this.darkPrimary,
    this.darkOnPrimary,
    this.darkTopBarContainer,
    this.darkOnTopBarContainer,
  });
}

class KhipuStartOperationOptions {
  String operationId;
  String? locale;
  String? title;
  String? titleImageUrl;
  bool? skipExitPage;
  bool? showFooter;
  String? theme;
  KhipuColors? colors;

  KhipuStartOperationOptions({required this.operationId,
    this.locale,
    this.title,
    this.titleImageUrl,
    this.skipExitPage,
    this.showFooter,
    this.theme,
    this.colors});
}

class KhipuEvent {
  String? name;
  String? type;
  String? timestamp;

  KhipuEvent({this.name, this.type, this.timestamp});

  static KhipuEvent fromJson(Object? json) {
    var map = json as Map;

    return KhipuEvent(
        name: map['name'] as String,
        type: map['type'] as String,
        timestamp: map['timestamp'] as String);
  }
}

class KhipuResult {
  String? operationId;
  String? result;
  String? exitTitle;
  String? exitMessage;
  String? exitUrl;
  String? failureReason;
  String? continueUrl;
  Iterable<KhipuEvent>? events;

  KhipuResult({this.operationId,
    this.result,
    this.exitTitle,
    this.exitMessage,
    this.exitUrl,
    this.failureReason,
    this.continueUrl,
    this.events});

  static KhipuResult fromJson(Map<Object?, Object?> json) {
    var eventsJson = (json['events'] as List<Object?>);
    var events = eventsJson.map((event) => KhipuEvent.fromJson(event));

    return KhipuResult(
        operationId: json['operationId'] as String,
        result: json['result'] as String,
        exitTitle: json['exitTitle'] as String,
        exitMessage: json['exitMessage'] as String,
        exitUrl: json['exitUrl'] as String,
        failureReason: json['failureReason'] as String?,
        continueUrl: json['continueUrl'] as String?,
        events: events);
  }
}
