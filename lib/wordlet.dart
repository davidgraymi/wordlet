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

const Map<LetterHint, Color> _defaultHintToKeyColorMap = {
  LetterHint.none: Color(0xffd6d6d6),
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
  final Map<String, LetterHint> _keyMap = {
    'Q': LetterHint.none,
    'W': LetterHint.none,
    'E': LetterHint.none,
    'R': LetterHint.none,
    'T': LetterHint.none,
    'Y': LetterHint.none,
    'U': LetterHint.none,
    'I': LetterHint.none,
    'O': LetterHint.none,
    'P': LetterHint.none,
    'A': LetterHint.none,
    'S': LetterHint.none,
    'D': LetterHint.none,
    'F': LetterHint.none,
    'G': LetterHint.none,
    'H': LetterHint.none,
    'J': LetterHint.none,
    'K': LetterHint.none,
    'L': LetterHint.none,
    'Z': LetterHint.none,
    'X': LetterHint.none,
    'C': LetterHint.none,
    'V': LetterHint.none,
    'B': LetterHint.none,
    'N': LetterHint.none,
    'M': LetterHint.none,
  };

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
        setState(() {
          _hints[_index][i] = LetterHint.correct;
          _keyMap[myChars[i]] = LetterHint.correct;
        });
        // update duplicate map
        dupeMap.update(myChars[i], ((List<int>, List<int>) value) {
          value.$1.add(i);
          return value;
        }, ifAbsent: () {
          return ([i], []);
        });
        // Correct character, wrong place
      } else if (widget.target.contains(myChars[i])) {
        setState(() {
          _hints[_index][i] = LetterHint.wrongPlace;
          if (_keyMap[myChars[i]] != LetterHint.correct) {
            _keyMap[myChars[i]] = LetterHint.wrongPlace;
          }
        });
        // update map
        dupeMap.update(myChars[i], ((List<int>, List<int>) value) {
          value.$2.add(i);
          return value;
        }, ifAbsent: () {
          return ([], [i]);
        });
        // Wrong character
      } else {
        setState(() {
          _hints[_index][i] = LetterHint.incorrect;
          if (_keyMap[myChars[i]] != LetterHint.correct ||
              _keyMap[myChars[i]] != LetterHint.wrongPlace) {
            _keyMap[myChars[i]] = LetterHint.incorrect;
          }
        });
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
      duration: const Duration(milliseconds: 300),
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
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: keyEventHandler,
        autofocus: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    const Spacer(
                      flex: 1,
                    ),
                    Expanded(
                      flex: 15,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                    ),
                    const Spacer(
                      flex: 1,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 550),
                      child: SoftKeyboard(
                        onCharacterTap: onCharacter,
                        onBackspaceTap: onBackspace,
                        onEnterTap: onEnter,
                        keys: _keyMap,
                      ),
                    ),
                  ],
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
                                    return Theme.of(context)
                                        .colorScheme
                                        .surface;
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
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
      ),
    );
  }
}

class SoftKeyboard extends StatelessWidget {
  const SoftKeyboard(
      {super.key,
      required this.onCharacterTap,
      required this.onBackspaceTap,
      required this.onEnterTap,
      required this.keys,
      this.hintToColor = _defaultHintToKeyColorMap});

  final Map<LetterHint, Color>? hintToColor;
  final Map<String, LetterHint> keys;
  final Function(String) onCharacterTap;
  final Function() onBackspaceTap;
  final Function() onEnterTap;

  final double spacing = 4.0;

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
              color: hintToColor == null ? null : hintToColor![keys['Q']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'W',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['W']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'E',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['E']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'R',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['R']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'T',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['T']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'Y',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['Y']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'U',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['U']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'I',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['I']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'O',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['O']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'P',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['P']],
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
              color: hintToColor == null ? null : hintToColor![keys['A']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'S',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['S']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'D',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['D']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'F',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['F']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'G',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['G']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'H',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['H']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'J',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['J']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'K',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['K']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'L',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['L']],
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
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'Z',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['Z']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'X',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['X']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'C',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['C']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'V',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['V']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'B',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['B']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'N',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['N']],
            ),
            SizedBox(width: spacing),
            CharacterKey(
              character: 'M',
              onTap: onCharacterTap,
              color: hintToColor == null ? null : hintToColor![keys['M']],
            ),
            SizedBox(width: spacing),
            BackspaceKey(
              onTap: onBackspaceTap,
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
      required this.color})
      : assert(character.length == 1);

  final String character;
  final Function(String) onTap;
  final Color? color;

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
              return color;
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
  const EnterKey({super.key, required this.onTap});

  final Function() onTap;

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
          child: Text('ENTER',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall!
                  .copyWith(color: Theme.of(context).colorScheme.onSurface)
                  .copyWith(fontSize: 12)),
        ),
      ),
    );
  }
}

class BackspaceKey extends StatelessWidget {
  const BackspaceKey({super.key, required this.onTap});

  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: SizedBox(
        height: 60,
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(
            Icons.backspace_outlined,
            size: 24,
          ),
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
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Letter(
            char: chars.isNotEmpty ? chars[0] : '',
            hint: hints[0],
            hintToColor: hintToColor,
          ),
          const SizedBox(
            width: 5,
          ),
          Letter(
            char: chars.length > 1 ? chars[1] : '',
            hint: hints[1],
            hintToColor: hintToColor,
          ),
          const SizedBox(
            width: 5,
          ),
          Letter(
            char: chars.length > 2 ? chars[2] : '',
            hint: hints[2],
            hintToColor: hintToColor,
          ),
          const SizedBox(
            width: 5,
          ),
          Letter(
            char: chars.length > 3 ? chars[3] : '',
            hint: hints[3],
            hintToColor: hintToColor,
          ),
          const SizedBox(
            width: 5,
          ),
          Letter(
            char: chars.length > 4 ? chars[4] : '',
            hint: hints[4],
            hintToColor: hintToColor,
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
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hintToColor == null ? null : hintToColor![hint],
          border: hint == LetterHint.none
              ? Border.all(
                  color: Colors.black45,
                  width: 0.5,
                )
              : null,
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
      ),
    );
  }
}
