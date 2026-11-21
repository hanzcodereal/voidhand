import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const Voidhand());
}

class Voidhand extends StatelessWidget {
  const Voidhand({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voidhand',
      debugShowCheckedModeBanner: false,
      theme: T.dark,
      home: const DashboardScreen(),
    );
  }
}
