import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'instrument.dart';
import 'instrument_registry.dart';

class InstrumentPickerScreen extends StatelessWidget {
  const InstrumentPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Instrument')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: instrumentRegistry.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final instrument = instrumentRegistry[index];
          return _InstrumentCard(instrument: instrument);
        },
      ),
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({required this.instrument});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/record', extra: instrument.id),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                _iconFor(instrument.id),
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instrument.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      instrument.family,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String id) {
    return switch (id) {
      'piano' => Icons.piano,
      'guitar_acoustic' => Icons.music_note,
      _ => Icons.library_music,
    };
  }
}
