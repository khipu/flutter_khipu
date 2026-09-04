import 'package:flutter/material.dart';
import 'package:flutter_khipu/flutter_khipu.dart';

/// Shows what `startOperation` handed back.
///
/// Every field is listed even when it came back empty, so you can tell an
/// absent value apart from one you forgot to look at.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, this.result, this.error});

  final KhipuResult? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Result', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._body(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (error != null) {
      return <Widget>[
        Text(
          error!,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
        ),
      ];
    }

    final KhipuResult? current = result;
    if (current == null) {
      return <Widget>[
        Text(
          'Nothing yet. Launch Khipu to see what comes back.',
          style: theme.textTheme.bodySmall,
        ),
      ];
    }

    final Iterable<KhipuEvent> events =
        current.events ?? const <KhipuEvent>[];

    return <Widget>[
      _Row(label: 'operationId', value: current.operationId),
      _Row(label: 'result', value: current.result),
      _Row(label: 'exitTitle', value: current.exitTitle),
      _Row(label: 'exitMessage', value: current.exitMessage),
      _Row(label: 'exitUrl', value: current.exitUrl),
      _Row(label: 'failureReason', value: current.failureReason),
      _Row(label: 'continueUrl', value: current.continueUrl),
      const Divider(height: 24),
      Text('events', style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      if (events.isEmpty)
        Text('none', style: theme.textTheme.bodySmall)
      else
        for (final KhipuEvent event in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${event.name} (${event.type}) — ${event.timestamp}',
              style: theme.textTheme.bodySmall,
            ),
          ),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
