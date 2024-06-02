import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_khipu/flutter_khipu.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  KhipuResult _result = KhipuResult();
  final _flutterKhipuPlugin = FlutterKhipu();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    KhipuResult result;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      KhipuStartOperationOptions options = KhipuStartOperationOptions(
          operationId: 'mxitm6yzdjwl',
          locale: 'es_CL',
          title: 'FlutterKhipu',
          skipExitPage: true,
          theme: 'dark',
          colors: KhipuColors(
              // darkBackground: '#00ff00',
              // darkPrimary: '#ff0000',
              // darkOnBackground: '#0000ff',
              // darkTopBarContainer: '#ffffff',
              // darkOnTopBarContainer: '#333333'
              ));

      result =
          await _flutterKhipuPlugin.startOperation(options) ?? KhipuResult();
    } on PlatformException {
      result = KhipuResult();
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('OperationId: ${_result.operationId ?? 'none yet'}  \n'),
            Text('result: ${_result.result ?? 'none yet'}  \n'),
            Text('exitTitle: ${_result.exitTitle ?? 'none yet'}  \n'),
            Text('exitMessage: ${_result.exitMessage ?? 'none yet'}  \n'),
            Text('exitUrl: ${_result.exitUrl ?? 'none yet'}  \n'),
            Text('failureReason: ${_result.failureReason ?? 'none yet'}  \n'),
            Text('continueUrl: ${_result.continueUrl ?? 'none yet'}  \n'),
            Text(
                'events: ${_result.events?.map((event) => '${event.name}(${event.type}) ${event.timestamp}').join(" - ") ?? 'none yet'}  \n'),
          ],
        )),
      ),
    );
  }
}
