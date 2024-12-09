import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      this.hintToColor = _defaultHintToColorMap})
      : assert(target.length == 5),
        assert(alphaCapReg.allMatches(target).length == 5);

  final List<Color>? confettiColors;
  final String target;
  final Color? backgroundColor;
  final Color? textInputColor;
  final Color? textFrozenColor;
  final Map<LetterHint, Color>? hintToColor;

  @override
  State<Wordlet> createState() => _WordletState();
}

class _WordletState extends State<Wordlet> {
  final _wordLength = 5;
  final _maxWords = 6;
  final FocusNode _focusNode = FocusNode();

  ConfettiController _confettiController = ConfettiController(
    duration: const Duration(milliseconds: 100),
  );
  List<String> _targetChars = [];
  List<String> _words = [];
  List<List<LetterHint>> _hints = [];
  int _index = 0;
  GameState _gameState = GameState.inProgress;

  /// Checks if a word is english.
  ///
  /// TODO: implement
  bool isWordValid(String word) {
    return (word.length == _wordLength);
  }

  /// Compares a word against the target.
  bool isWordCorrect(String word) {
    return (word == widget.target);
  }

  void handleWin() {
    setState(() {
      _confettiController.play();
      _focusNode.dispose();
      _gameState = GameState.win;
    });

    if (kDebugMode) {
      print("you win!");
    }
  }

  void updateHints(String word) {
    if (kDebugMode) {
      print("updating hints");
    }

    List<String> myChars = word.split('');
    for (int i = 0; i < _wordLength; i++) {
      if (myChars[i] == _targetChars[i]) {
        setState(() => _hints[_index][i] = LetterHint.correct);
        if (kDebugMode) {
          print("hint[$_index][$i] correct");
        }
      } else if (widget.target.contains(myChars[i])) {
        setState(() => _hints[_index][i] = LetterHint.wrongPlace);
        if (kDebugMode) {
          print("hint[$_index][$i] wrong place");
        }
      } else {
        setState(() => _hints[_index][i] = LetterHint.incorrect);
        if (kDebugMode) {
          print("hint[$_index][$i] incorrect");
        }
      }
    }

    if (kDebugMode) {
      print(_hints);
    }
  }

  void submitWord(String word) {
    updateHints(word);
    if (isWordCorrect(word)) {
      handleWin();
    } else {
      // move to next row
      _index += 1;
      // if all words have been entered lose
      if (_index > _maxWords - 1) {
        setState(() {
          _focusNode.dispose();
          _gameState = GameState.lose;
        });

        if (kDebugMode) {
          print("you lose");
        }
      } else {
        if (kDebugMode) {
          print("incorrect! try again");
        }
      }
    }
  }

  KeyEventResult keyEventHandler(FocusNode node, KeyEvent event) {
    // If [enter] key is pressed down and the word is 5 letters
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        _words[_index].length == _wordLength &&
        event.runtimeType == KeyDownEvent) {
      // If word is valid english
      if (isWordValid(_words[_index])) {
        // Submit
        submitWord(_words[_index]);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _words[_index].isNotEmpty &&
        event.runtimeType == KeyDownEvent) {
      setState(() {
        _words[_index] = _words[_index].substring(0, _words[_index].length - 1);
      });
      if (kDebugMode) {
        print(_words[_index]);
      }
      return KeyEventResult.handled;
    } else if (event.character != null) {
      var upper = event.character!.toUpperCase();
      if (upper.contains(alphaLowReg) && _words[_index].length < _wordLength) {
        setState(() {
          _words[_index] += upper;
        });
        if (kDebugMode) {
          print(_words[_index]);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
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

    super.initState();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      descendantsAreFocusable: false,
      focusNode: _focusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        // If [enter] key is pressed down and the word is 5 letters
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            _words[_index].length == _wordLength &&
            event.runtimeType == KeyDownEvent) {
          // If word is valid english
          if (isWordValid(_words[_index])) {
            // Submit
            submitWord(_words[_index]);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
          // If [backspace] was pressed
        } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
            _words[_index].isNotEmpty &&
            event.runtimeType == KeyDownEvent) {
          setState(() {
            _words[_index] =
                _words[_index].substring(0, _words[_index].length - 1);
          });
          if (kDebugMode) {
            print(_words[_index]);
          }
          return KeyEventResult.handled;
          // If a character was pressed
        } else if (event.character != null) {
          var upper = event.character!.toUpperCase();
          if (upper.contains(alphaCapReg) &&
              _words[_index].length < _wordLength) {
            setState(() {
              _words[_index] += upper;
            });
            if (kDebugMode) {
              print(_words[_index]);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.82),
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Letter(
            char: chars.isNotEmpty ? chars[0] : '',
            hint: hints[0],
            hintToColor: hintToColor,
          ),
          Letter(
            char: chars.length > 1 ? chars[1] : '',
            hint: hints[1],
            hintToColor: hintToColor,
          ),
          Letter(
            char: chars.length > 2 ? chars[2] : '',
            hint: hints[2],
            hintToColor: hintToColor,
          ),
          Letter(
            char: chars.length > 3 ? chars[3] : '',
            hint: hints[3],
            hintToColor: hintToColor,
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
    if (kDebugMode) {
      print(hintToColor);
    }
    return Container(
      width: 70,
      height: 70,
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
