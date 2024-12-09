import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wordlet/wordlet.dart';

import 'constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordlet',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(),
        useMaterial3: true,
        textTheme: TextTheme(
          displayLarge: GoogleFonts.lato(
            color: Colors.black,
            fontSize: 40,
            fontWeight: FontWeight.w700,
          ),
          displayMedium: GoogleFonts.lato(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: Wordlet(
        target: "YUMMY", // TODO: get word from database
      ),
    );
  }
}

