import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../domain/dates.dart';
import '../domain/usage.dart';
import '../models/models.dart';
import '../state/app_store.dart';
import '../widgets/widgets.dart';
import 'part_detail_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'gear_screen.dart';

String _homeSyncLabel(AppStore store) {
  final from = store.settings.lastSyncFrom;
  final to = store.newestSyncedOn;
  if (from == null && to == null) {
    return '未同期';
  }
  if (from != null && to != null) {
    return '${formatDate(from)}〜${formatDate(to)}';
  }
  if (from != null) {
    return '${formatDate(from)}〜—';
  }
  return formatDate(to!);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final alerts = store.alerts;
        final gearName = store.selectedGear == null
            ? 'ギア: 未選択'
            : 'ギア: ${demoGearLabel(
                store.selectedGear!.name,
                demo: isDemoGearId(store.selectedGear!.id),
              )}';
        final lastSync = markDemo(
          _homeSyncLabel(store),
          demo: store.usingDemoRides,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('GearDoctor'),
            actions: [
              TextButton(
                onPressed: () => _openSettings(context),
                child: const Text('設定'),
              ),
            ],
          ),
          body: Column(
            children: [
              if (store.usingDemoRides)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _DemoClearBanner(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SyncScreen(store: store),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _openGear(context),
                        child: Text(
                          gearName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    Flexible(
                      child: InkWell(
                        onTap: () => _openSync(context),
                        child: Text(
                          '最終同期 $lastSync',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (alerts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _AlertBanner(
                    alerts: alerts,
                    onTap: (partId) => _openDetail(context, partId),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: store.cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final card = store.cards[index];
                    return _PartCard(
                      store: store,
                      card: card,
                      onOpen: (partId) => _openDetail(context, partId),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SyncScreen(store: store),
                        ),
                      );
                    },
                    child: const Text('Strava同期'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SettingsScreen(store: store)),
    );
  }

  void _openGear(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GearScreen(store: store)),
    );
  }

  void _openSync(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SyncScreen(store: store)),
    );
  }

  void _openDetail(BuildContext context, String partId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartDetailScreen(store: store, partId: partId),
      ),
    );
  }
}

class _DemoClearBanner extends StatelessWidget {
  const _DemoClearBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            'デモを解除するには Strava を同期します。最初の取得でデモ走行は消えます。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alerts, required this.onTap});

  final List<AlertItem> alerts;
  final void Function(String partId) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'しきい値 ${alerts.length}件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final alert in alerts)
                ActionChip(
                  label: Text(alert.label),
                  onPressed: () => onTap(alert.partId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.store,
    required this.card,
    required this.onOpen,
  });

  final AppStore store;
  final DisplayCard card;
  final void Function(String partId) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (card.isGroup)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SideUsage(
                      part: card.rear!,
                      used: store.usedOf(card.rear!),
                      limit: store.limitOf(card.rear!),
                      positionLabel: 'R',
                      modeLabel: store.limitModeLabelOf(card.rear!),
                      demoDistance: store.usingDemoRides,
                      onTap: () => onOpen(card.rear!.id),
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: scheme.outlineVariant,
                  ),
                  Expanded(
                    child: SideUsage(
                      part: card.front!,
                      used: store.usedOf(card.front!),
                      limit: store.limitOf(card.front!),
                      positionLabel: 'F',
                      modeLabel: store.limitModeLabelOf(card.front!),
                      demoDistance: store.usingDemoRides,
                      onTap: () => onOpen(card.front!.id),
                    ),
                  ),
                ],
              ),
            )
          else
            SideUsage(
              part: card.part!,
              used: store.usedOf(card.part!),
              limit: store.limitOf(card.part!),
              modeLabel: store.limitModeLabelOf(card.part!),
              demoDistance: store.usingDemoRides,
              onTap: () => onOpen(card.part!.id),
            ),
        ],
      ),
    );
  }
}
