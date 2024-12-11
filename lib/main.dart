import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wordlet/temp_word_list.dart';
import 'package:wordlet/wordlet.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // final client = http.Client();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Theme.of(context).colorScheme.surface,
      title: 'Wordlet',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.white,
        ),
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
          displaySmall: GoogleFonts.lato(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          labelSmall: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: Scaffold(
        body: Wordlet(
          target: theList[
              Random().nextInt(theList.length)], // TODO: get word from database
        ),
      ),
    );
  }
}
