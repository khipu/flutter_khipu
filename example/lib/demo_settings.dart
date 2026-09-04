import 'package:flutter_khipu/flutter_khipu.dart';

/// Mutable state behind the demo form.
///
/// Keeping it apart from the widgets means the part that can break quietly —
/// turning the form state into [KhipuStartOperationOptions] — is plain Dart and
/// can be unit tested. A mistyped colour key would otherwise just show up as a
/// colour that never takes effect.
class KhipuDemoSettings {
  /// The twelve [KhipuColors] fields, in the order the form lays them out.
  static const List<String> colorFieldNames = <String>[
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
  ];

  static const Map<String, Map<String, String>> colorPresets =
      <String, Map<String, String>>{
    'Khipu': <String, String>{
      'lightBackground': '#FFFFFF',
      'lightOnBackground': '#1A1A1A',
      'lightPrimary': '#8347AD',
      'lightOnPrimary': '#FFFFFF',
      'lightTopBarContainer': '#8347AD',
      'lightOnTopBarContainer': '#FFFFFF',
      'darkBackground': '#101418',
      'darkOnBackground': '#E8EAED',
      'darkPrimary': '#3CB4E5',
      'darkOnPrimary': '#06283A',
      'darkTopBarContainer': '#1A1F26',
      'darkOnTopBarContainer': '#E8EAED',
    },
    'High contrast': <String, String>{
      'lightBackground': '#FFFFFF',
      'lightOnBackground': '#000000',
      'lightPrimary': '#000000',
      'lightOnPrimary': '#FFFFFF',
      'lightTopBarContainer': '#000000',
      'lightOnTopBarContainer': '#FFFFFF',
      'darkBackground': '#000000',
      'darkOnBackground': '#FFFFFF',
      'darkPrimary': '#FFFFFF',
      'darkOnPrimary': '#000000',
      'darkTopBarContainer': '#FFFFFF',
      'darkOnTopBarContainer': '#000000',
    },
  };

  static const List<String> themes = <String>['system', 'light', 'dark'];

  static const List<String> locales = <String>['es_CL', 'en_US'];

  String operationId = '';
  String title = '';
  String titleImageUrl = '';
  bool skipExitPage = false;
  bool skipExitSuccessPage = false;
  bool showFooter = true;
  bool showMerchantLogo = true;
  bool showPaymentDetails = true;
  String theme = 'system';
  String locale = 'es_CL';

  /// Colour overrides keyed by [colorFieldNames].
  ///
  /// Empty means "don't send `colors` at all", which leaves Khipu's own palette
  /// in place. That is a different thing from sending twelve nulls.
  final Map<String, String> colors = <String, String>{};

  /// Replaces every colour with the named preset, or clears them all when
  /// [name] is null.
  void applyColorPreset(String? name) {
    colors.clear();
    final Map<String, String>? preset = name == null ? null : colorPresets[name];
    if (preset != null) {
      colors.addAll(preset);
    }
  }

  KhipuStartOperationOptions toOptions() {
    return KhipuStartOperationOptions(
      operationId: operationId.trim(),
      title: _orNull(title),
      titleImageUrl: _orNull(titleImageUrl),
      locale: locale,
      theme: theme,
      skipExitPage: skipExitPage,
      skipExitSuccessPage: skipExitSuccessPage,
      showFooter: showFooter,
      showMerchantLogo: showMerchantLogo,
      showPaymentDetails: showPaymentDetails,
      colors: colors.isEmpty ? null : _buildColors(),
    );
  }

  /// Blank means "leave it unset". Sending an empty string would actively blank
  /// out the top bar title instead.
  static String? _orNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  KhipuColors _buildColors() {
    return KhipuColors(
      lightBackground: colors['lightBackground'],
      lightOnBackground: colors['lightOnBackground'],
      lightPrimary: colors['lightPrimary'],
      lightOnPrimary: colors['lightOnPrimary'],
      lightTopBarContainer: colors['lightTopBarContainer'],
      lightOnTopBarContainer: colors['lightOnTopBarContainer'],
      darkBackground: colors['darkBackground'],
      darkOnBackground: colors['darkOnBackground'],
      darkPrimary: colors['darkPrimary'],
      darkOnPrimary: colors['darkOnPrimary'],
      darkTopBarContainer: colors['darkTopBarContainer'],
      darkOnTopBarContainer: colors['darkOnTopBarContainer'],
    );
  }
}
