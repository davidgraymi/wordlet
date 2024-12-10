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
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final client = http.Client();

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
        target: theList[Random().nextInt(theList.length)], client: client, // TODO: get word from database
      ),
    );
  }
}

