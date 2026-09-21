/// Khipu plugin for Flutter.
///
/// This is the only file a merchant imports. Everything under `lib/src/` is
/// internal and can change without notice, including the code Pigeon
/// generates.
library;

export 'src/flutter_khipu.dart' show FlutterKhipu;
export 'src/khipu_options.dart'
    show KhipuColors, KhipuStartOperationOptions, KhipuTheme;
export 'src/khipu_result.dart'
    show KhipuEvent, KhipuResult, KhipuResultStatus;
