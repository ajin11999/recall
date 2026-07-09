import 'package:flutter/material.dart';

import 'api.dart';
import 'notifications.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.init();
  final session = await Session.load();
  runApp(RecallApp(initial: session));
}

class RecallApp extends StatefulWidget {
  const RecallApp({super.key, this.initial});

  final Session? initial;

  @override
  State<RecallApp> createState() => _RecallAppState();
}

class _RecallAppState extends State<RecallApp> {
  Api? _api;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    if (s != null) {
      _api = Api(s.baseUrl, s.token);
      Notifications.sync(_api!);
    }
  }

  Future<void> _onLogin(String baseUrl, String token) async {
    await Session(baseUrl: baseUrl, token: token).save();
    setState(() => _api = Api(baseUrl, token));
    Notifications.sync(_api!);
  }

  Future<void> _onLogout() async {
    await Session.clear();
    await Notifications.cancelAll();
    setState(() => _api = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recall',
      theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      home: _api == null
          ? LoginScreen(onLogin: _onLogin)
          : HomeScreen(api: _api!, onLogout: _onLogout),
    );
  }
}
