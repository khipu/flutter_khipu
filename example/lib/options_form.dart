import 'package:flutter/material.dart';

import 'demo_settings.dart';

/// Lets you flip every option Khipu accepts before launching it.
///
/// Owns the text controllers because picking a colour preset has to push new
/// values into the twelve hex fields.
class OptionsForm extends StatefulWidget {
  const OptionsForm({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final KhipuDemoSettings settings;

  /// Called after any edit, so the page can re-evaluate the launch button.
  final VoidCallback onChanged;

  @override
  State<OptionsForm> createState() => _OptionsFormState();
}

class _OptionsFormState extends State<OptionsForm> {
  late final TextEditingController _operationId;
  late final TextEditingController _title;
  late final TextEditingController _titleImageUrl;
  late final Map<String, TextEditingController> _colorFields;

  /// Which preset is highlighted. Editing a hex field by hand clears it,
  /// because the palette no longer matches any preset.
  String? _preset;

  @override
  void initState() {
    super.initState();
    final KhipuDemoSettings settings = widget.settings;
    _operationId = TextEditingController(text: settings.operationId);
    _title = TextEditingController(text: settings.title);
    _titleImageUrl = TextEditingController(text: settings.titleImageUrl);
    _colorFields = <String, TextEditingController>{
      for (final String field in KhipuDemoSettings.colorFieldNames)
        field: TextEditingController(text: settings.colors[field] ?? ''),
    };
  }

  @override
  void dispose() {
    _operationId.dispose();
    _title.dispose();
    _titleImageUrl.dispose();
    for (final TextEditingController controller in _colorFields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _applyPreset(String? name) {
    setState(() {
      _preset = name;
      widget.settings.applyColorPreset(name);
      for (final String field in KhipuDemoSettings.colorFieldNames) {
        _colorFields[field]!.text = widget.settings.colors[field] ?? '';
      }
    });
    widget.onChanged();
  }

  void _editColor(String field, String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      widget.settings.colors.remove(field);
    } else {
      widget.settings.colors[field] = trimmed;
    }
    if (_preset != null) {
      setState(() => _preset = null);
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final KhipuDemoSettings settings = widget.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Section(
          title: 'Operation',
          children: <Widget>[
            _text(
              controller: _operationId,
              label: 'operationId',
              helper: 'Payment intent id. Single use, so create a fresh one '
                  'for every run.',
              onChanged: (String value) {
                settings.operationId = value;
                widget.onChanged();
              },
            ),
          ],
        ),
        _Section(
          title: 'Top bar',
          children: <Widget>[
            _text(
              controller: _title,
              label: 'title',
              helper: 'Leave empty to keep Khipu\'s own title.',
              onChanged: (String value) {
                settings.title = value;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 12),
            _text(
              controller: _titleImageUrl,
              label: 'titleImageUrl',
              helper: 'An image URL replaces the title.',
              onChanged: (String value) {
                settings.titleImageUrl = value;
                widget.onChanged();
              },
            ),
          ],
        ),
        _Section(
          title: 'Behaviour',
          children: <Widget>[
            _switch(
              label: 'skipExitPage',
              subtitle: 'Skip the final screen, success or failure.',
              value: settings.skipExitPage,
              onChanged: (bool value) => settings.skipExitPage = value,
            ),
            _switch(
              label: 'skipExitSuccessPage',
              subtitle: 'Skip the final screen only when the payment worked.',
              value: settings.skipExitSuccessPage,
              onChanged: (bool value) => settings.skipExitSuccessPage = value,
            ),
            _switch(
              label: 'showFooter',
              subtitle: 'Show the footer with the Khipu logo.',
              value: settings.showFooter,
              onChanged: (bool value) => settings.showFooter = value,
            ),
            _switch(
              label: 'showMerchantLogo',
              subtitle: 'Show the merchant logo.',
              value: settings.showMerchantLogo,
              onChanged: (bool value) => settings.showMerchantLogo = value,
            ),
            _switch(
              label: 'showPaymentDetails',
              subtitle: 'Show the payment breakdown.',
              value: settings.showPaymentDetails,
              onChanged: (bool value) => settings.showPaymentDetails = value,
            ),
          ],
        ),
        _Section(
          title: 'Theme and locale',
          children: <Widget>[
            _label(context, 'theme'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                for (final String theme in KhipuDemoSettings.themes)
                  ButtonSegment<String>(value: theme, label: Text(theme)),
              ],
              selected: <String>{settings.theme},
              onSelectionChanged: (Set<String> selection) {
                setState(() => settings.theme = selection.first);
                widget.onChanged();
              },
            ),
            const SizedBox(height: 20),
            _label(context, 'locale'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                for (final String locale in KhipuDemoSettings.locales)
                  ButtonSegment<String>(value: locale, label: Text(locale)),
              ],
              selected: <String>{settings.locale},
              onSelectionChanged: (Set<String> selection) {
                setState(() => settings.locale = selection.first);
                widget.onChanged();
              },
            ),
          ],
        ),
        _Section(
          title: 'Colors',
          children: <Widget>[
            Text(
              'Default leaves the colors option unset, so Khipu uses its own '
              'palette.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Default'),
                  selected: _preset == null,
                  onSelected: (bool _) => _applyPreset(null),
                ),
                for (final String name in KhipuDemoSettings.colorPresets.keys)
                  ChoiceChip(
                    label: Text(name),
                    selected: _preset == name,
                    onSelected: (bool _) => _applyPreset(name),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Edit the twelve values'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: <Widget>[
                for (final String field in KhipuDemoSettings.colorFieldNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _colorFields[field],
                      decoration: InputDecoration(
                        labelText: field,
                        hintText: '#RRGGBB',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (String value) => _editColor(field, value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }

  Widget _text({
    required TextEditingController controller,
    required String label,
    required String helper,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  Widget _switch({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(label),
      subtitle: Text(subtitle),
      value: value,
      contentPadding: EdgeInsets.zero,
      onChanged: (bool next) {
        setState(() => onChanged(next));
        widget.onChanged();
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
