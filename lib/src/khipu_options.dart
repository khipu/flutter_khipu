import 'package:meta/meta.dart';

import 'messages.g.dart' as pigeon;
// `export` alone re-exports KhipuTheme for importers of this file; it does
// not bring the name into scope here, so this file also needs its own
// unprefixed import to use KhipuTheme in the field type below.
import 'messages.g.dart' show KhipuTheme;

export 'messages.g.dart' show KhipuTheme;

/// Palette Khipu is painted with.
///
/// Each color is a hex string, `'#8347AD'`. A null color leaves the one the
/// SDK brings.
@immutable
class KhipuColors {
  const KhipuColors({
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

  final String? lightBackground;
  final String? lightOnBackground;
  final String? lightPrimary;
  final String? lightOnPrimary;
  final String? lightTopBarContainer;
  final String? lightOnTopBarContainer;
  final String? darkBackground;
  final String? darkOnBackground;
  final String? darkPrimary;
  final String? darkOnPrimary;
  final String? darkTopBarContainer;
  final String? darkOnTopBarContainer;

  pigeon.KhipuColors toPigeon() => pigeon.KhipuColors(
        lightBackground: lightBackground,
        lightOnBackground: lightOnBackground,
        lightPrimary: lightPrimary,
        lightOnPrimary: lightOnPrimary,
        lightTopBarContainer: lightTopBarContainer,
        lightOnTopBarContainer: lightOnTopBarContainer,
        darkBackground: darkBackground,
        darkOnBackground: darkOnBackground,
        darkPrimary: darkPrimary,
        darkOnPrimary: darkOnPrimary,
        darkTopBarContainer: darkTopBarContainer,
        darkOnTopBarContainer: darkOnTopBarContainer,
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuColors &&
      other.lightBackground == lightBackground &&
      other.lightOnBackground == lightOnBackground &&
      other.lightPrimary == lightPrimary &&
      other.lightOnPrimary == lightOnPrimary &&
      other.lightTopBarContainer == lightTopBarContainer &&
      other.lightOnTopBarContainer == lightOnTopBarContainer &&
      other.darkBackground == darkBackground &&
      other.darkOnBackground == darkOnBackground &&
      other.darkPrimary == darkPrimary &&
      other.darkOnPrimary == darkOnPrimary &&
      other.darkTopBarContainer == darkTopBarContainer &&
      other.darkOnTopBarContainer == darkOnTopBarContainer;

  @override
  int get hashCode => Object.hash(
        lightBackground,
        lightOnBackground,
        lightPrimary,
        lightOnPrimary,
        lightTopBarContainer,
        lightOnTopBarContainer,
        darkBackground,
        darkOnBackground,
        darkPrimary,
        darkOnPrimary,
        darkTopBarContainer,
        darkOnTopBarContainer,
      );

  @override
  String toString() => 'KhipuColors(lightPrimary: $lightPrimary, '
      'darkPrimary: $darkPrimary)';
}

/// What is needed to open a payment.
///
/// Only [operationId] is required; the rest adjusts the presentation and,
/// if left null, Khipu uses its own default.
@immutable
class KhipuStartOperationOptions {
  const KhipuStartOperationOptions({
    required this.operationId,
    this.locale,
    this.title,
    this.titleImageUrl,
    this.skipExitPage,
    this.skipExitSuccessPage,
    this.showFooter,
    this.showMerchantLogo,
    this.showPaymentDetails,
    this.theme,
    this.colors,
  });

  /// Operation identifier, created on the merchant's backend.
  final String operationId;

  /// Interface language, `'es_CL'`.
  final String? locale;

  /// Title of the top bar.
  final String? title;

  /// Image of the top bar.
  final String? titleImageUrl;

  /// Skips the final screen, whatever the outcome.
  final bool? skipExitPage;

  /// Skips the final screen only when the payment went well.
  final bool? skipExitSuccessPage;

  final bool? showFooter;
  final bool? showMerchantLogo;
  final bool? showPaymentDetails;

  /// Theme it presents itself with. Null leaves the SDK's own.
  final KhipuTheme? theme;

  /// Palette. Null leaves the SDK's own.
  final KhipuColors? colors;

  pigeon.KhipuStartOperationOptions toPigeon() =>
      pigeon.KhipuStartOperationOptions(
        operationId: operationId,
        locale: locale,
        title: title,
        titleImageUrl: titleImageUrl,
        skipExitPage: skipExitPage,
        skipExitSuccessPage: skipExitSuccessPage,
        showFooter: showFooter,
        showMerchantLogo: showMerchantLogo,
        showPaymentDetails: showPaymentDetails,
        theme: theme,
        colors: colors?.toPigeon(),
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuStartOperationOptions &&
      other.operationId == operationId &&
      other.locale == locale &&
      other.title == title &&
      other.titleImageUrl == titleImageUrl &&
      other.skipExitPage == skipExitPage &&
      other.skipExitSuccessPage == skipExitSuccessPage &&
      other.showFooter == showFooter &&
      other.showMerchantLogo == showMerchantLogo &&
      other.showPaymentDetails == showPaymentDetails &&
      other.theme == theme &&
      other.colors == colors;

  @override
  int get hashCode => Object.hash(
        operationId,
        locale,
        title,
        titleImageUrl,
        skipExitPage,
        skipExitSuccessPage,
        showFooter,
        showMerchantLogo,
        showPaymentDetails,
        theme,
        colors,
      );

  @override
  String toString() =>
      'KhipuStartOperationOptions(operationId: $operationId, theme: $theme)';
}
