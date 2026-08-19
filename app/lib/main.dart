import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/record_screen.dart';
import 'services/recorder.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseConfigured) {
    await Supabase.initialize(
        url: supabaseUrl, publishableKey: supabasePublishableKey);
  }
  runApp(const FlatnineApp());
}

class FlatnineApp extends StatefulWidget {
  const FlatnineApp({super.key});

  @override
  State<FlatnineApp> createState() => _FlatnineAppState();
}

class _FlatnineAppState extends State<FlatnineApp> {
  final _store = SessionStore();
  late final _recorder = RecorderService(_store);

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flatnine',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: RecordScreen(recorder: _recorder),
    );
  }
}
