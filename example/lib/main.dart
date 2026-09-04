import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_khipu/flutter_khipu.dart';

import 'demo_settings.dart';
import 'options_form.dart';
import 'result_card.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_khipu example',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8347AD),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final FlutterKhipu _khipu = FlutterKhipu();
  final KhipuDemoSettings _settings = KhipuDemoSettings();

  KhipuResult? _result;
  String? _error;
  bool _running = false;

  /// The whole integration is these few lines: build the options and call
  /// `startOperation`. Everything else in this app is the form that fills them.
  Future<void> _launch() async {
    setState(() {
      _running = true;
      _result = null;
      _error = null;
    });

    try {
      final KhipuResult? result = await _khipu.startOperation(
        _settings.toOptions(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } on PlatformException catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '${exception.code}: ${exception.message}');
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canLaunch =
        !_running && _settings.operationId.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('flutter_khipu example')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                OptionsForm(
                  settings: _settings,
                  onChanged: () => setState(() {}),
                ),
                ResultCard(result: _result, error: _error),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton(
                    onPressed: canLaunch ? _launch : null,
                    child: Text(_running ? 'Running…' : 'Launch Khipu'),
                  ),
                  if (!_running && _settings.operationId.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Enter an operationId to launch.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
