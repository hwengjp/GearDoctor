import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'state/app_store.dart';
import 'theme.dart';

class GearDoctorApp extends StatefulWidget {
  const GearDoctorApp({super.key, this.store});

  final AppStore? store;

  @override
  State<GearDoctorApp> createState() => _GearDoctorAppState();
}

class _GearDoctorAppState extends State<GearDoctorApp> {
  late final AppStore _store;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? AppStore();
    if (_ownsStore) {
      _store.load();
    }
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GearDoctor',
      theme: buildAppTheme(),
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          if (_store.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (_store.error != null) {
            return Scaffold(
              body: Center(child: Text('起動に失敗しました\n${_store.error}')),
            );
          }
          return HomeScreen(store: _store);
        },
      ),
    );
  }
}
