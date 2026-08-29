import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../state/app_store.dart';
import '../widgets/widgets.dart';
import 'display_group_screen.dart';
import 'edit_part_screen.dart';
import 'import_replacements_screen.dart';
import 'sync_screen.dart';

class GearScreen extends StatelessWidget {
  const GearScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final selected = store.selectedGear;
        final selectedName = selected == null
            ? '未選択'
            : demoGearLabel(selected.name, demo: isDemoGearId(selected.id));
        final canManage = store.canManageRecords;
        return Scaffold(
          appBar: AppBar(title: const Text('ギア')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                selectedName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Strava から取った自転車だけ選べます。部品の追加・設定、交換記録、CSV は選んだギアだけです。初期の部品は同じです。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (store.usingDemoRides) ...[
                const SizedBox(height: 8),
                Text(
                  'デモのあいだは部品の追加と記録の CSV は使えません。先に Strava を同期してください。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              if (store.gears.isEmpty) ...[
                const Text('先に Strava を同期すると、ここに自転車が並びます。'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SyncScreen(store: store),
                      ),
                    );
                  },
                  child: const Text('Strava同期'),
                ),
                const SizedBox(height: 16),
              ] else ...[
                for (final gear in store.gears) ...[
                  SelectTile(
                    selected: store.settings.selectedGearId == gear.id,
                    title: demoGearLabel(
                      gear.name,
                      demo: isDemoGearId(gear.id),
                      selected: store.settings.selectedGearId == gear.id,
                    ),
                    onTap: () => store.selectGear(gear.id),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (!canManage && store.gears.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '上で自転車を選ぶと、部品の追加と交換記録が使えます。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              FilledButton(
                onPressed: () {
                  if (store.usingDemoRides) {
                    showDemoRequiresSyncDialog(context);
                    return;
                  }
                  if (!canManage) {
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditPartScreen(store: store),
                    ),
                  );
                },
                child: const Text('部品を追加'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  if (store.usingDemoRides) {
                    showDemoRequiresSyncDialog(context);
                    return;
                  }
                  if (!canManage) {
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImportReplacementsScreen(store: store),
                    ),
                  );
                },
                child: const Text('記録の CSV'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: canManage
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DisplayGroupScreen(store: store),
                          ),
                        );
                      }
                    : null,
                child: const Text('表示をまとめる / 分ける'),
              ),
            ],
          ),
        );
      },
    );
  }
}
