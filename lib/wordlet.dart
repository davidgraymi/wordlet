import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'constants.dart';

enum GameState { inProgress, win, lose }

enum LetterHint { none, incorrect, wrongPlace, correct }

// TODO: add ability to change colors
const Map<LetterHint, Color> _defaultHintToColorMap = {
  LetterHint.none: Color(0x00ffffff),
  LetterHint.incorrect: Color(0xff9e9e9e),
  LetterHint.wrongPlace: Color(0xfffdd835),
  LetterHint.correct: Color(0xff4ca750)
};

class Wordlet extends StatefulWidget {
  /// Creates a widget to play a single game of Wordlet.
  ///
  /// [target] must be a five letter string of all capital letters.
  Wordlet(
      {super.key,
      required this.target,
      this.confettiColors,
      this.backgroundColor,
      this.textInputColor,
      this.textFrozenColor,
      this.hintToColor = _defaultHintToColorMap,
      this.client})
      : assert(target.length == 5),
        assert(alphaCapReg.allMatches(target).length == 5);

  final List<Color>? confettiColors;
  final String target;
  final Color? backgroundColor;
  final Color? textInputColor;
  final Color? textFrozenColor;
  final Map<LetterHint, Color>? hintToColor;
  final http.Client? client;

  @override
  State<Wordlet> createState() => _WordletState();
}

class _WordletState extends State<Wordlet> {
  final _wordLength = 5;
  final _maxWords = 6;
  final Map<String, List<int>> _charMap = {};

  late FocusNode _focusNode;
  late ConfettiController _confettiController;
  late List<String> _targetChars;
  late List<String> _words;
  late List<List<LetterHint>> _hints;
  late int _index;
  late GameState _gameState;

  String getSubject() {
    DateTime date = DateTime.now();
    return "Wordlet ${date.month}/${date.day}/${date.year}";
  }

  String helperFormatHintString(
    List<List<LetterHint>> hints,
  ) {
    String retval = getSubject();
    retval += "\n";
    for (int i = 0; i < hints.length; i++) {
      for (int j = 0; j < hints[i].length; j++) {
        switch (hints[i][j]) {
          case LetterHint.none:
          // TODO: Handle this case.
          case LetterHint.incorrect:
            retval += "⬜️";
          case LetterHint.wrongPlace:
            retval += "🟨";
          case LetterHint.correct:
            retval += "🟩";
        }
      }
      retval += "\n";
    }
    retval += "https://davidmgray.com/wordlet/index.html";
    return retval;
  }

  /// Checks if a word is english.
  ///
  /// TODO: implement
  bool isWordValid(String word) {
    // String db = "https://api.dictionaryapi.dev/api/v2/entries/en/$word";
    // var url = Uri.https('api.dictionaryapi.dev', 'api/v2/entries/en/$word');
    // var response = await widget.client.get(url);
    // print('Response status: ${response.statusCode}');
    // print('Response body: ${response.body}');
    //
    // print(await http.read(Uri.https('example.com', 'foobar.txt')));
    return (word.length == _wordLength);
  }

  /// Compares a word against the target.
  bool isWordCorrect(String word) {
    if (kDebugMode) {
      print("$word != ${widget.target}");
    }
    return (word == widget.target);
  }

  void handleWin() {
    setState(() {
      _confettiController.play();
      _focusNode.unfocus();
      _gameState = GameState.win;
    });
    if (kDebugMode) {
      print("you win!");
    }
  }

  /// Updates the hints
  ///
  /// Only mark letters as [LetterHint.wrongPlace] as many times as it occurs in [target].
  ///
  /// ### Example
  /// target = "TWERK", input = "WEEKS"
  ///  - only the E in position 3 would be marked [LetterHint.correct]
  ///  - the E in position 2 would be marked [LetterHint.incorrect]
  ///
  /// ### Example 2
  /// target = "TWERK", input = "THREE"
  ///  - only the E in position 4 would be marked [LetterHint.wrongPlace]
  ///  - the E in position 5 would be marked [LetterHint.incorrect]
  void updateHints(String word) {
    List<String> myChars = word.split('');
    // duplicate map $1 = correct, $2 = wrong place
    Map<String, (List<int>, List<int>)> dupeMap = {};

    // Initial label for characters
    for (int i = 0; i < _wordLength; i++) {
      // Correct character, correct place
      if (myChars[i] == _targetChars[i]) {
        setState(() => _hints[_index][i] = LetterHint.correct);
        // update duplicate map
        dupeMap.update(myChars[i], ((List<int>, List<int>) value) {
          value.$1.add(i);
          return value;
        }, ifAbsent: () {
          return ([i], []);
        });
        // Correct character, wrong place
      } else if (widget.target.contains(myChars[i])) {
        setState(() => _hints[_index][i] = LetterHint.wrongPlace);
        // update map
        dupeMap.update(myChars[i], ((List<int>, List<int>) value) {
          value.$2.add(i);
          return value;
        }, ifAbsent: () {
          return ([], [i]);
        });
        // Wrong character
      } else {
        setState(() => _hints[_index][i] = LetterHint.incorrect);
      }
    }

    if (kDebugMode) {
      print("---------------");
      print("$dupeMap");
      print("$_charMap");
      print("$_targetChars");
      print(widget.target);
    }

    // Iterate through any duplicate characters and clean up extra labeling that causes confusion.
    for (String key in dupeMap.keys) {
      if (kDebugMode) {
        print("$key");
      }

      int total = dupeMap[key]!.$1.length + dupeMap[key]!.$2.length;
      if (_charMap[key] != null) {
        if (total > 1 && _charMap[key]!.isNotEmpty) {
          int o = dupeMap[key]!.$2.length - 1;
          if (kDebugMode) {
            print("total: $total");
          }
          while (total > _charMap[key]!.length) {
            int out = dupeMap[key]!.$2[o];
            if (kDebugMode) {
              print("changing $out to LetterHint.incorrect");
            }
            setState(() {
              _hints[_index][dupeMap[key]!.$2[o]] = LetterHint.incorrect;
            });
            total--;
            o--;
          }
        }
      }
    }
  }

  void submitWord(String word) {
    if (kDebugMode) {
      print("begin submit: ${widget.target}");
    }
    updateHints(word);
    if (isWordCorrect(word)) {
      handleWin();
    } else {
      // move to next row
      _index += 1;
      // if all words have been entered lose
      if (_index > _maxWords - 1) {
        setState(() {
          _focusNode.unfocus();
          _gameState = GameState.lose;
        });
      }
    }
    if (kDebugMode) {
      print("end submit: ${widget.target}");
    }
  }

  void onEnter() {
    if (_words[_index].length == _wordLength) {
      if (isWordValid(_words[_index])) {
        submitWord(_words[_index]);
      }
    }
  }

  void onBackspace() {
    if (_words[_index].isNotEmpty) {
      setState(() {
        _words[_index] = _words[_index].substring(0, _words[_index].length - 1);
      });
    }
  }

  void onCharacter(String character) {
    if (character.contains(alphaCapReg) &&
        _words[_index].length < _wordLength) {
      setState(() {
        _words[_index] += character;
      });
    }
  }

  KeyEventResult keyEventHandler(KeyEvent event) {
    if (kDebugMode) {
      print("handle key: ${event.logicalKey}");
    }
    // If [enter] key is pressed down and the word is 5 letters
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        event.runtimeType == KeyDownEvent) {
      onEnter();
      return KeyEventResult.handled;
      // If [backspace] was pressed
    } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
        event.runtimeType == KeyDownEvent) {
      onBackspace();
      return KeyEventResult.handled;
      // If a character was pressed
    } else if (event.character != null) {
      var upper = event.character!.toUpperCase();
      onCharacter(upper);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    _focusNode = FocusNode(
      debugLabel: "wordlet",
    );
    _targetChars = widget.target.split('');
    _words = List<String>.filled(_maxWords, "");
    _hints = List<List<LetterHint>>.generate(_maxWords, (i) {
      return List<LetterHint>.filled(_wordLength, LetterHint.none);
    }, growable: false);
    _index = 0;
    _gameState = GameState.inProgress;
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 100),
    );

    for (int i = 0; i < _targetChars.length; i++) {
      _charMap.update(_targetChars[i], (List<int> value) {
        value.add(i);
        return value;
      }, ifAbsent: () {
        return [i];
      });
    }

    if (kDebugMode) {
      print("---------------");
      print(widget.target);
      print("$_targetChars");
      print("$_charMap");
    }

    super.initState();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print("dispose");
    }
    _confettiController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: keyEventHandler,
      autofocus: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 300,
                        maxWidth: 370,
                      ),
                      child: Column(
                        children: [
                          Word(
                            chars: _words[0].split(''),
                            hints: _hints[0],
                            hintToColor: widget.hintToColor,
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Word(
                            chars: _words[1].split(''),
                            hints: _hints[1],
                            hintToColor: widget.hintToColor,
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Word(
                            chars: _words[2].split(''),
                            hints: _hints[2],
                            hintToColor: widget.hintToColor,
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Word(
                            chars: _words[3].split(''),
                            hints: _hints[3],
                            hintToColor: widget.hintToColor,
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Word(
                            chars: _words[4].split(''),
                            hints: _hints[4],
                            hintToColor: widget.hintToColor,
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Word(
                            chars: _words[5].split(''),
                            hints: _hints[5],
                            hintToColor: widget.hintToColor,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 550),
                      child: SoftKeyboard(
                        onCharacterTap: onCharacter,
                        onBackspaceTap: onBackspace,
                        onEnterTap: onEnter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.88),
              child: AnimatedContainer(
                height: 45,
                width: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _gameState == GameState.lose
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                duration: const Duration(milliseconds: 200),
                child: _gameState == GameState.lose
                    ? Text(
                        widget.target,
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium!
                            .copyWith(
                                color: Theme.of(context).colorScheme.surface),
                      )
                    : null,
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: (_gameState == GameState.lose ||
                      _gameState == GameState.win)
                  ? Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color?>(
                                        (Set<WidgetState> states) {
                                  return Theme.of(context).colorScheme.surface;
                                }),
                                padding: WidgetStateProperty.resolveWith<
                                        EdgeInsetsGeometry?>(
                                    (Set<WidgetState> states) {
                                  return const EdgeInsets.all(16);
                                }),
                                elevation:
                                    WidgetStateProperty.resolveWith<double?>(
                                        (Set<WidgetState> states) {
                                  return 20;
                                }),
                              ),
                              onPressed: () async {
                                var str = helperFormatHintString(_hints);
                                final result = await Share.share(str,
                                    subject: getSubject());

                                if (result.status ==
                                    ShareResultStatus.success) {
                                  print('Thank you for sharing my website!');
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Share with a friend!",
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    CupertinoIcons.share,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            gravity: 0.2,
            minBlastForce: 1,
            maxBlastForce: 200,
            numberOfParticles: 1000,
            blastDirectionality: BlastDirectionality.explosive,
            colors: widget.confettiColors,
          ),
        ],
      ),
    );
  }
}

class SoftKeyboard extends StatelessWidget {
  SoftKeyboard(
      {super.key,
      required this.onCharacterTap,
      required this.onBackspaceTap,
      required this.onEnterTap});

  final Function(String) onCharacterTap;
  final Function() onBackspaceTap;
  final Function() onEnterTap;

  double spacing = 4.0;
  double width = 34;
  double height = 60;
  double specialwidth = 55;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CharacterKey(
              character: 'Q',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'W',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'E',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'R',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'T',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'Y',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'U',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'I',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'O',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'P',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            CharacterKey(
              character: 'A',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'S',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'D',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'F',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'G',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'H',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'J',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'K',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'L',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            const Spacer(flex: 1),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EnterKey(
              onTap: onEnterTap,
              height: height,
              width: specialwidth,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'Z',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'X',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'C',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'V',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'B',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'N',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'M',
              onTap: onCharacterTap,
              height: height,
              width: width,
            ),
            SizedBox(width: spacing),
            BackspaceKey(
              onTap: onBackspaceTap,
              height: height,
              width: specialwidth,
            ),
          ],
        ),
      ],
    );
  }
}

class CharacterKey extends StatelessWidget {
  const CharacterKey(
      {super.key,
      required this.character,
      required this.onTap,
      required this.height,
      required this.width})
      : assert(character.length == 1);

  final String character;
  final Function(String) onTap;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: SizedBox(
        height: 60,
        child: TextButton(
          onPressed: () {
            onTap(character);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
              return Colors.grey[350];
            }),
            shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
                (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              );
            }),
            padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry?>(
                (Set<WidgetState> states) {
              return EdgeInsets.zero;
            }),
          ),
          child: Text(
            character,
            style: Theme.of(context)
                .textTheme
                .displaySmall!
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class EnterKey extends StatelessWidget {
  const EnterKey(
      {super.key,
      required this.onTap,
      required this.height,
      required this.width});

  final Function() onTap;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: SizedBox(
        height: 60,
        child: TextButton(
          onPressed: () {
            onTap();
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
              return Colors.grey[350];
            }),
            shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
                (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              );
            }),
            padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry?>(
                (Set<WidgetState> states) {
              return EdgeInsets.zero;
            }),
          ),
          child: Text(
            'ENTER',
            style: Theme.of(context)
                .textTheme
                .displaySmall!
                .copyWith(color: Theme.of(context).colorScheme.onSurface)
                .copyWith(fontSize: 12)
          ),
        ),
      ),
    );
  }
}

class BackspaceKey extends StatelessWidget {
  const BackspaceKey(
      {super.key,
      required this.onTap,
      required this.height,
      required this.width});

  final Function() onTap;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: SizedBox(
        height: 60,
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.backspace_outlined, size: 24,),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
              return Colors.grey[350];
            }),
            shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
                (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              );
            }),
            padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry?>(
                (Set<WidgetState> states) {
              return EdgeInsets.zero;
            }),
          ),
        ),
      ),
    );
  }
}

class Word extends StatelessWidget {
  final List<String> chars;
  final List<LetterHint> hints;
  final Map<LetterHint, Color>? hintToColor;
  const Word(
      {super.key,
      required this.chars,
      required this.hints,
      this.hintToColor = _defaultHintToColorMap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Letter(
              char: chars.isNotEmpty ? chars[0] : '',
              hint: hints[0],
              hintToColor: hintToColor,
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          Expanded(
            child: Letter(
              char: chars.length > 1 ? chars[1] : '',
              hint: hints[1],
              hintToColor: hintToColor,
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          Expanded(
            child: Letter(
              char: chars.length > 2 ? chars[2] : '',
              hint: hints[2],
              hintToColor: hintToColor,
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          Expanded(
            child: Letter(
              char: chars.length > 3 ? chars[3] : '',
              hint: hints[3],
              hintToColor: hintToColor,
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          Expanded(
            child: Letter(
              char: chars.length > 4 ? chars[4] : '',
              hint: hints[4],
              hintToColor: hintToColor,
            ),
          ),
        ],
      ),
    );
  }
}

class Letter extends StatelessWidget {
  const Letter(
      {super.key,
      required this.char,
      required this.hint,
      this.hintToColor = _defaultHintToColorMap});

  final String char;
  final LetterHint hint;
  final Map<LetterHint, Color>? hintToColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      // width: 70,
      // height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hintToColor == null ? null : hintToColor![hint],
        border: Border.all(
            color: Colors.black45, width: hint != LetterHint.none ? 0.5 : 1.2),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        char,
        style: hint != LetterHint.none
            ? Theme.of(context)
                .textTheme
                .displayLarge!
                .copyWith(color: Theme.of(context).colorScheme.surface)
            : Theme.of(context)
                .textTheme
                .displayLarge!
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
