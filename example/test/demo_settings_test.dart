import 'package:flutter_khipu/flutter_khipu.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_khipu_example/demo_settings.dart';

/// Reads the twelve KhipuColors fields in the same order as
/// [KhipuDemoSettings.colorFieldNames], so a mapping mistake shows up as a
/// mismatch instead of hiding behind a silently unset colour.
List<String?> _colorValuesInFieldOrder(KhipuColors c) => <String?>[
      c.lightBackground,
      c.lightOnBackground,
      c.lightPrimary,
      c.lightOnPrimary,
      c.lightTopBarContainer,
      c.lightOnTopBarContainer,
      c.darkBackground,
      c.darkOnBackground,
      c.darkPrimary,
      c.darkOnPrimary,
      c.darkTopBarContainer,
      c.darkOnTopBarContainer,
    ];

void main() {
  group('toOptions', () {
    test('carries the operation id and the scalar options through', () {
      final settings = KhipuDemoSettings()
        ..operationId = 'abc123'
        ..title = 'Mi comercio'
        ..theme = 'dark'
        ..locale = 'en_US';

      final options = settings.toOptions();

      expect(options.operationId, 'abc123');
      expect(options.title, 'Mi comercio');
      expect(options.theme, 'dark');
      expect(options.locale, 'en_US');
    });

    test('carries every boolean switch through', () {
      final settings = KhipuDemoSettings()
        ..skipExitPage = true
        ..skipExitSuccessPage = false
        ..showFooter = false
        ..showMerchantLogo = true
        ..showPaymentDetails = false;

      final options = settings.toOptions();

      expect(options.skipExitPage, isTrue);
      expect(options.skipExitSuccessPage, isFalse);
      expect(options.showFooter, isFalse);
      expect(options.showMerchantLogo, isTrue);
      expect(options.showPaymentDetails, isFalse);
    });

    test('sends null instead of an empty string for blank text fields', () {
      final settings = KhipuDemoSettings()
        ..title = ''
        ..titleImageUrl = '   ';

      final options = settings.toOptions();

      // An empty string is not the same as "unset": it would blank out the top
      // bar title rather than leaving the SDK default in place.
      expect(options.title, isNull);
      expect(options.titleImageUrl, isNull);
    });

    test('trims surrounding whitespace off text fields', () {
      final settings = KhipuDemoSettings()
        ..operationId = '  abc123  '
        ..title = '  Mi comercio  ';

      final options = settings.toOptions();

      expect(options.operationId, 'abc123');
      expect(options.title, 'Mi comercio');
    });

    test('omits colors entirely when none are set', () {
      final options = KhipuDemoSettings().toOptions();

      expect(options.colors, isNull);
    });
  });

  group('colour presets', () {
    test('start out empty so the SDK defaults are used', () {
      expect(KhipuDemoSettings().colors, isEmpty);
    });

    test('applying a preset fills all twelve fields', () {
      final settings = KhipuDemoSettings()..applyColorPreset('Khipu');

      expect(settings.colors.length, KhipuDemoSettings.colorFieldNames.length);

      final colors = settings.toOptions().colors;
      expect(colors, isNotNull);
      expect(_colorValuesInFieldOrder(colors!), everyElement(isNotNull));
    });

    test('the Khipu preset uses the brand palette', () {
      final settings = KhipuDemoSettings()..applyColorPreset('Khipu');

      expect(settings.colors['lightPrimary'], '#8347AD');
      expect(settings.colors['darkPrimary'], '#3CB4E5');
    });

    test('applying the null preset clears the colours again', () {
      final settings = KhipuDemoSettings()..applyColorPreset('Khipu');
      expect(settings.colors, isNotEmpty);

      settings.applyColorPreset(null);

      expect(settings.colors, isEmpty);
      expect(settings.toOptions().colors, isNull);
    });

    test('every preset defines exactly the known colour fields', () {
      for (final entry in KhipuDemoSettings.colorPresets.entries) {
        expect(
          entry.value.keys.toSet(),
          KhipuDemoSettings.colorFieldNames.toSet(),
          reason: 'preset "${entry.key}" does not define the known fields',
        );
      }
    });
  });

  group('colour field mapping', () {
    test('each field name maps to its own KhipuColors property', () {
      // Every field gets its own name as its value, so the resulting
      // KhipuColors must read back the field names in order. A typo, a
      // duplicated assignment or a dropped field all break this.
      final settings = KhipuDemoSettings();
      for (final name in KhipuDemoSettings.colorFieldNames) {
        settings.colors[name] = name;
      }

      final colors = settings.toOptions().colors;

      expect(colors, isNotNull);
      expect(
        _colorValuesInFieldOrder(colors!),
        KhipuDemoSettings.colorFieldNames,
      );
    });

    test('a single overridden field survives on its own', () {
      final settings = KhipuDemoSettings();
      settings.colors['darkTopBarContainer'] = '#123456';

      final colors = settings.toOptions().colors;

      expect(colors!.darkTopBarContainer, '#123456');
      expect(colors.lightPrimary, isNull);
    });
  });
}
