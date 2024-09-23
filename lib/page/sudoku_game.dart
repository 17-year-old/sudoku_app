import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/sudoku_localizations.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:logger/logger.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sudoku/constant.dart';
import 'package:sudoku/effect/sound_effect.dart';
import 'package:sudoku/page/hint_paint.dart';
import 'package:sudoku/page/sudoku_pause_cover.dart';
import 'package:sudoku/state/sudoku_state.dart';
import 'package:sudoku/util/localization_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../sudoku/core.dart';
import '../sudoku/native_sudoku_api.g.dart';
import '../sudoku/tools.dart';

final Logger log = Logger();

// final AudioPlayer tipsPlayer = AudioPlayer();

final ButtonStyle flatButtonStyle = TextButton.styleFrom(
  foregroundColor: Colors.black54,
  shadowColor: Colors.blue,
  minimumSize: Size(88, 36),
  padding: EdgeInsets.symmetric(horizontal: 16.0),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(3.0)),
  ),
);

final ButtonStyle primaryFlatButtonStyle = TextButton.styleFrom(
  foregroundColor: Colors.white,
  backgroundColor: Colors.lightBlue,
  shadowColor: Colors.blue,
  minimumSize: Size(88, 36),
  padding: EdgeInsets.symmetric(horizontal: 16.0),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(3.0)),
  ),
);

const Image ideaPng = Image(
  image: AssetImage("assets/image/icon_idea.png"),
  width: 25,
  height: 25,
);
const Image lifePng = Image(
  image: AssetImage("assets/image/icon_life.png"),
  width: 25,
  height: 25,
);

class SudokuGamePage extends StatefulWidget {
  SudokuGamePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _SudokuGamePageState createState() => _SudokuGamePageState();
}

class _SudokuGamePageState extends State<SudokuGamePage> with WidgetsBindingObserver {
  int _chooseSudokuBox = -1;
  bool _markOpen = false;
  bool _manualPause = false;
  DirectHint? _directHint;
  IndirectHint? _indirectHint;
  String? _stringHint;

  GlobalKey _sudoku_grid_key = GlobalKey();

  SudokuState get _state => ScopedModel.of<SudokuState>(context);

  _aboutDialogAction(BuildContext context) {
    Widget appIcon = GestureDetector(
        child: Image(image: AssetImage("assets/image/sudoku_logo.png"), width: 45, height: 45),
        onDoubleTap: () {
          WidgetBuilder columnWidget = (BuildContext context) {
            return Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Image(image: AssetImage("assets/image/sudoku_logo.png")),
              CupertinoButton(
                child: Text("Sudoku"),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              )
            ]);
          };
          showDialog(context: context, builder: columnWidget);
        });
    return showAboutDialog(applicationIcon: appIcon, context: context, children: <Widget>[
      GestureDetector(
        child: Text(
          "Github Repository",
          style: TextStyle(color: Colors.blue),
        ),
        onTap: () async {
          if (await canLaunchUrlString(Constant.githubRepository)) {
            if (Platform.isAndroid) {
              await launchUrlString(Constant.githubRepository, mode: LaunchMode.platformDefault);
            } else {
              await launchUrlString(Constant.githubRepository, mode: LaunchMode.externalApplication);
            }
          } else {
            log.e("can't open browser to url : ${Constant.githubRepository}");
          }
        },
      ),
      Container(
          margin: EdgeInsets.fromLTRB(0, 10, 0, 5),
          padding: EdgeInsets.all(0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Sudoku powered by Flutter", style: TextStyle(fontSize: 12)),
            Text(Constant.githubRepository, style: TextStyle(fontSize: 12))
          ]))
    ]);
  }

  bool _isOnlyReadGrid(int index) => (_state.sudoku?.puzzle[index] ?? 0) != 0;

  // 游戏盘点，检查是否游戏结束
  // check the game is done
  void _gameStackCount() {
    if (_state.isComplete) {
      _pauseTimer();
      _state.updateStatus(SudokuGameStatus.success);
      return _gameOver();
    }
  }

  /// game over trigger function
  /// 游戏结束触发 执行判断逻辑
  void _gameOver() async {
    bool isWinner = _state.status == SudokuGameStatus.success;
    String title, conclusion;
    Function playSoundEffect;

    // define i18n begin
    final String elapsedTimeText = AppLocalizations.of(context)!.elapsedTimeText;
    final String winnerConclusionText = AppLocalizations.of(context)!.winnerConclusionText;
    final String failureConclusionText = AppLocalizations.of(context)!.failureConclusionText;
    final String levelLabel = LocalizationUtils.localizationLevelName(context, _state.sudoku!.level);
    // define i18n end
    if (isWinner) {
      title = "Well Done!";
      conclusion = winnerConclusionText.replaceFirst("%level%", levelLabel);
      playSoundEffect = SoundEffect.solveVictory;
    } else {
      title = "Failure";
      conclusion = failureConclusionText.replaceFirst("%level%", levelLabel);
      playSoundEffect = SoundEffect.gameOver;
    }

    // route to game over show widget page
    PageRouteBuilder gameOverPageRouteBuilder = PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, animation, _) {
          // sound effect : victory or failure
          playSoundEffect();
          // game over show widget
          Widget gameOverWidget = Scaffold(
              backgroundColor: Colors.white.withOpacity(0.85),
              body: Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                          flex: 1,
                          child: Align(
                              alignment: Alignment.center,
                              child: Text(title,
                                  style: TextStyle(
                                      color: isWinner ? Colors.black : Colors.redAccent,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold)))),
                      Expanded(
                          flex: 2,
                          child: Column(children: [
                            Container(
                              padding: EdgeInsetsDirectional.fromSTEB(25.0, 0.0, 25.0, 0.0),
                              child: Text(conclusion, style: TextStyle(fontSize: 16, height: 1.5)),
                            ),
                            Container(
                                margin: EdgeInsets.fromLTRB(0, 15, 0, 10),
                                child:
                                    Text("$elapsedTimeText : ${_state.timer}'s", style: TextStyle(color: Colors.blue))),
                            Container(
                                padding: EdgeInsets.all(10),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Offstage(
                                      offstage: _state.status == SudokuGameStatus.success,
                                      child: IconButton(icon: Icon(Icons.tv), onPressed: null)),
                                  IconButton(icon: Icon(Icons.thumb_up), onPressed: null),
                                  IconButton(
                                      icon: Icon(Icons.exit_to_app),
                                      onPressed: () {
                                        Navigator.pop(context, "exit");
                                      })
                                ]))
                          ]))
                    ],
                  )));

          return ScaleTransition(scale: Tween(begin: 3.0, end: 1.0).animate(animation), child: gameOverWidget);
        });
    String signal = await Navigator.of(context).push(gameOverPageRouteBuilder);
    switch (signal) {
      case "ad":
        // @TODO give extra life logic coding
        // may do something to give user extra life , like watch ad video / make comment of this app ?
        break;
      case "exit":
      default:
        Navigator.pop(context);
        break;
    }
  }

  // fill zone [ 1 - 9 ]
  Widget _fillZone(BuildContext context) {
    List<Widget> fillTools = List.generate(9, (index) {
      int num = index + 1;
      bool hasNumStock = _state.hasNumStock(num);
      var fillOnPressed;
      if (!hasNumStock) {
        fillOnPressed = null;
      } else {
        fillOnPressed = () async {
          log.d("input : $num");
          if (_isOnlyReadGrid(_chooseSudokuBox)) {
            // 非填空项
            return;
          }
          if (_state.status != SudokuGameStatus.gaming) {
            // 未在游戏进行时
            return;
          }
          if (_markOpen) {
            /// markOpen , mean use mark notes
            log.d("填写笔记");
            _state.switchMark(_chooseSudokuBox, num);
          } else {
            // 填写数字
            _state.switchRecord(_chooseSudokuBox, num);
            // 判断真伪
            if (_state.record[_chooseSudokuBox] != 0 && _state.sudoku!.solution[_chooseSudokuBox] != num) {
              _state.wrong();
              SoundEffect.stuffError();
              return;
            }
            _gameStackCount();
          }
        };
      }

      Color recordFontColor = hasNumStock ? Colors.black : Colors.white;
      Color recordBgColor = hasNumStock ? Colors.black12 : Colors.white24;

      Color markFontColor = hasNumStock ? Colors.white : Colors.white;
      Color markBgColor = hasNumStock ? Colors.black : Colors.white24;

      return Expanded(
          flex: 1,
          child: Container(
              margin: EdgeInsets.all(1),
              decoration: BoxDecoration(border: BorderDirectional()),
              child: CupertinoButton(
                  color: _markOpen ? markBgColor : recordBgColor,
                  padding: EdgeInsets.all(1),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: _markOpen ? markFontColor : recordFontColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  onPressed: fillOnPressed)));
    });

    fillTools.add(Expanded(
        flex: 1,
        child: Container(
            margin: EdgeInsets.all(1),
            child: CupertinoButton(
                padding: EdgeInsets.all(1),
                child: Image(image: AssetImage("assets/image/icon_eraser.png"), width: 40, height: 40),
                onPressed: () {
                  log.d("""
                  when ${_chooseSudokuBox + 1} is not a puzzle , then clean the choose \n
                  清除 ${_chooseSudokuBox + 1} 选型 , 如果他不是固定值的话
                  """);
                  if (_isOnlyReadGrid(_chooseSudokuBox)) {
                    // read only item , skip it - 只读格
                    return;
                  }
                  if (_state.status != SudokuGameStatus.gaming) {
                    // not playing , skip it - 未在游戏进行时
                    return;
                  }
                  _state.cleanMark(_chooseSudokuBox);
                  _state.cleanRecord(_chooseSudokuBox);
                }))));

    return Container(
        margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
        height: 40,
        width: MediaQuery.of(context).size.width,
        child: Row(children: fillTools));
  }

  Widget _toolZone(BuildContext context) {
    // define i18n text begin
    var exitGameText = AppLocalizations.of(context)!.exitGameText;
    var cancelText = AppLocalizations.of(context)!.cancelText;
    var pauseText = AppLocalizations.of(context)!.pauseText;
    var tipsText = AppLocalizations.of(context)!.tipsText;
    var generateMarksText = AppLocalizations.of(context)!.generateMarksText;
    var enableMarkText = AppLocalizations.of(context)!.enableMarkText;
    var closeMarkText = AppLocalizations.of(context)!.closeMarkText;
    var exitGameContentText = AppLocalizations.of(context)!.exitGameContentText;
    var showAnswer = AppLocalizations.of(context)!.showAnswer;
    var confirmShowAnswerText = AppLocalizations.of(context)!.confirmShowAnswerText;
    var confirmText = AppLocalizations.of(context)!.confirmText;
    var showAnswerText = AppLocalizations.of(context)!.showAnswer;
    var analyseText = AppLocalizations.of(context)!.analyseText;

    // pause button tap function
    var pauseOnPressed = () {
      if (_state.status != SudokuGameStatus.gaming) {
        return;
      }

      // 标记手动暂停
      setState(() {
        _manualPause = true;
      });

      _pause();
      Navigator.push(
          context,
          PageRouteBuilder(
              opaque: false,
              pageBuilder: (BuildContext context, _, __) {
                return SudokuPauseCoverPage();
              })).then((_) {
        _gaming();

        // 解除手动暂停
        setState(() {
          _manualPause = false;
        });
      });
    };

    var analyseOnPressed = () async {
      List<int> record = [];
      record.addAll(_state.record);
      for (int i = 0; i < 81; ++i) {
        if (_state.sudoku!.puzzle[i] > 0) {
          record[i] = _state.sudoku!.puzzle[i];
        }
      }

      this._stringHint = await Sudoku.analyse(Int32List.fromList(record), Int32List.fromList(_state.getCheckedMarks()));
      this._directHint = null;
      this._indirectHint = null;
    };

    // tips button tap function
    var tipsOnPressed = () async {
      List<int> data = [];
      data.addAll(_state.record);
      for (int i = 0; i < 81; ++i) {
        if (_state.sudoku!.puzzle[i] > 0) {
          data[i] = _state.sudoku!.puzzle[i];
        }
      }

      var _api = NativeSudokuApi();
      var directHint = await _api.getDirectHint(Int32List.fromList(data));
      if (directHint != null) {
        this._directHint = directHint;
        this._stringHint = null;
        this._indirectHint = null;
        this._chooseSudokuBox = directHint.cellIndex;
        _state.setMark(this._directHint!.cellIndex, this._directHint!.cellValue);
      } else {
        var indirectHint = _state.CheckMarksHint();
        if (indirectHint != null) {
          this._stringHint = null;
          this._directHint = null;
          this._indirectHint = indirectHint;
        } else {
          List<int> PotentialValues = [];
          for (int i = 0; i < 81; ++i) {
            for (int j = 1; j < 10; j++) {
              if (_state.mark[i][j]) {
                PotentialValues.add(j);
              } else {
                PotentialValues.add(0);
              }
            }
          }
          indirectHint = await _api.getIndirectHint(Int32List.fromList(data), Int32List.fromList(PotentialValues));
          if (indirectHint != null) {
            this._stringHint = null;
            this._directHint = null;
            this._indirectHint = indirectHint;
            if ((indirectHint.cellIndex ?? -1) >= 0) {
              this._chooseSudokuBox = indirectHint.cellIndex!;
              _state.setMark(indirectHint.cellIndex!, indirectHint.cellValue!);
            }
          } else {
            //按道理不会到这里的？如果备选数字不对会不会到这里呢？
            //这样的话直接重新生成备选数
            _state.rebuildMarks();
          }
        }
      }
      this._state.showHint();
      SoundEffect.answerTips();
    };

    // tips button tap function
    var generateMarksnPressed = () async {
      var indirectHint = _state.CheckMarksHint();
      if (indirectHint != null) {
        this._stringHint = null;
        this._directHint = null;
        this._indirectHint = indirectHint;
      }
      this._state.showHint();
      SoundEffect.answerTips();
    };

    var showAnswerPressed = () async {
      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
                title: Text(showAnswer, style: TextStyle(fontWeight: FontWeight.bold)),
                content: Text(confirmShowAnswerText),
                actions: [
                  TextButton(
                    child: Text(confirmText),
                    style: flatButtonStyle,
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                  ),
                  TextButton(
                    child: Text(cancelText),
                    style: primaryFlatButtonStyle,
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                  ),
                ]);
          }).then((val) {
        bool confirm = val;
        if (confirm == true) {
          List<int> puzzle = _state.sudoku!.puzzle;
          List<int> record = _state.record;
          List<int> solution = _state.sudoku!.solution;
          for (int i = 0; i < puzzle.length; i++) {
            if (puzzle[i] == 0 && record[i] == 0) {
              _state.setRecord(i, solution[i]);
              _state.status = SudokuGameStatus.success;
            }
          }
        }
      });
    };

    // mark button tap function
    var markOnPressed = () {
      log.d("enable mark function - 启用笔记功能");
      setState(() {
        _markOpen = !_markOpen;
      });
    };

    // define i18n text end
    var exitGameOnPressed = () async {
      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
                title: Text(exitGameText, style: TextStyle(fontWeight: FontWeight.bold)),
                content: Text(exitGameContentText),
                actions: [
                  TextButton(
                    child: Text(exitGameText),
                    style: flatButtonStyle,
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                  ),
                  TextButton(
                    child: Text(cancelText),
                    style: primaryFlatButtonStyle,
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                  ),
                ]);
          }).then((val) {
        bool confirm = val;
        if (confirm == true) {
          // exit the game 退出游戏
          ScopedModel.of<SudokuState>(context).initialize();
          Navigator.pop(context);
        }
      });
    };

    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
      CupertinoButton(
          padding: EdgeInsets.all(1),
          onPressed: analyseOnPressed,
          child: Text(analyseText, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      // mark 笔记
      CupertinoButton(
          padding: EdgeInsets.all(1),
          onPressed: markOnPressed,
          child: Text("${_markOpen ? closeMarkText : enableMarkText}",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      CupertinoButton(
          padding: EdgeInsets.all(1),
          onPressed: tipsOnPressed,
          child: Text(tipsText, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      CupertinoButton(
          padding: EdgeInsets.all(1),
          onPressed: generateMarksnPressed,
          child: Text(generateMarksText, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      CupertinoButton(
          padding: EdgeInsets.all(1),
          onPressed: showAnswerPressed,
          child: Text(showAnswerText, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      // // 暂停
      // CupertinoButton(
      //     padding: EdgeInsets.all(1),
      //     onPressed: pauseOnPressed,
      //     child: Text(pauseText, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      // // 退出
      // CupertinoButton(
      //     padding: EdgeInsets.all(1),
      //     onPressed: exitGameOnPressed,
      //     child: Text(exitGameText, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))
    ]);
  }

  bool canShowHint() {
    return (_stringHint != null && _stringHint != '') || _directHint != null || _indirectHint != null;
  }

  String getHintMessage() {
    if (_stringHint != null) {
      return _stringHint!;
    }

    if (_directHint != null) {
      return _directHint!.HintMessage;
    }

    if (_indirectHint != null) {
      return _indirectHint!.HintMessage ?? "";
    }

    return "";
  }

  Alignment getHideTipsButtonAlign() {
    if (_directHint != null || _indirectHint != null) {
      return Alignment(0.3, 0.8);
    }
    return Alignment(0, 0.8);
  }

  void applyHint() {
    if (_directHint != null) {
      _state.setRecord(_directHint!.cellIndex, _directHint!.cellValue);
      _gameStackCount();
      _directHint = null;
    } else if (_indirectHint != null) {
      if (_indirectHint!.cellValue != null) {
        if (_indirectHint!.cellValue! > 0) {
          _state.setRecord(_indirectHint!.cellIndex!, _indirectHint!.cellValue!);
        }
      }
      if (_indirectHint!.removablePotentials != null) {
        for (var remove in _indirectHint!.removablePotentials!.entries) {
          var numbers = (remove.value as List<Object?>).cast<int>();
          for (var number in numbers) {
            _state.cleanMark(remove.key!, num: number);
            _chooseSudokuBox = remove.key!;
          }
        }
      }
      if (_indirectHint!.addPotentials != null) {
        for (var add in _indirectHint!.addPotentials!.entries) {
          var numbers = (add.value as List<Object?>).cast<int>();
          for (var number in numbers) {
            _state.setMark(add.key!, number);
            _chooseSudokuBox = add.key!;
          }
        }
      }

      _indirectHint = null;
    }

    SoundEffect.answerTips();
  }

  Widget _hintZone(BuildContext context) {
    return Expanded(
        child: Stack(children: [
      SingleChildScrollView(child: HtmlWidget(getHintMessage())),
      Offstage(
          offstage: !canShowHint(),
          child: Align(
              alignment: getHideTipsButtonAlign(),
              child: CupertinoButton(
                  padding: EdgeInsets.all(1),
                  onPressed: () {
                    this._stringHint = null;
                    this._directHint = null;
                    this._indirectHint = null;
                  },
                  child: Text(AppLocalizations.of(context)!.hideTipsText,
                      style: TextStyle(
                          color: Colors.red[300]?.withOpacity(0.8), fontSize: 18, fontWeight: FontWeight.bold))))),
      Offstage(
          offstage: _directHint == null && _indirectHint == null,
          child: Align(
              alignment: Alignment(-0.3, 0.8),
              child: CupertinoButton(
                  padding: EdgeInsets.all(1),
                  onPressed: applyHint,
                  child: Text(AppLocalizations.of(context)!.applyTipsText,
                      style: TextStyle(
                          color: Colors.red[300]?.withOpacity(0.8), fontSize: 18, fontWeight: FontWeight.bold)))))
    ]));
  }

  Widget _willPopWidget(BuildContext context, Widget child, PopInvokedCallback onWillPop) {
    return PopScope(
      child: child,
      canPop: true,
      onPopInvoked: onWillPop,
    );
  }

  /// 计算网格背景色
  Color _gridCellBgColor(int index) {
    Color gridCellBackgroundColor;

    //如果selectedCells不为空，且包含index时，显示为选中状态
    //如果selectedCells不为空，但不包含index时，不选中
    //只有selectedCells为空时，才判断_chooseSudokuBox
    if (_indirectHint?.selectedCells?.contains(index) ?? false) {
      gridCellBackgroundColor = Color.fromARGB(255, 0x6F, 0xDF, 0xEF);
    } else if ((_indirectHint?.selectedCells?.isEmpty ?? true) && index == _chooseSudokuBox) {
      gridCellBackgroundColor = Color.fromARGB(255, 0x6F, 0xDF, 0xEF);
    } else {
      if (Matrix.getZone(index: index).isOdd) {
        gridCellBackgroundColor = Colors.white;
      } else {
        gridCellBackgroundColor = Color.fromARGB(255, 0xCC, 0xCC, 0xCC);
      }
    }
    return gridCellBackgroundColor;
  }

  ///
  /// 正常网格控件
  Widget _gridCellWidget(BuildContext context, int index, int num, GestureTapCallback onTap) {
    Sudoku sudoku = _state.sudoku!;
    List<int> puzzle = sudoku.puzzle;
    List<int> solution = sudoku.solution;
    List<int> record = _state.record;
    int num = puzzle[index];

    Color textColor = Colors.black54;
    FontWeight textFontWeight = FontWeight.w800;
    if (puzzle[index] == 0) {
      num = record[index];
      // from puzzle number with readonly
      textFontWeight = FontWeight.normal;

      if (record[index] != 0 && record[index] != solution[index]) {
        // is wrong input because not match solution
        textColor = Colors.red;
      } else {
        // from user input num
        textColor = Colors.blue;
      }
    }
    final _cellContainer = Center(
      child: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.all(0.5),
        decoration: BoxDecoration(color: _gridCellBgColor(index), border: Border.all(width: 1, color: Colors.black12)),
        child: Text(
          '${num == 0 ? '' : num}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: textFontWeight,
            color: textColor,
          ),
        ),
      ),
    );

    return InkWell(
        highlightColor: Colors.blue, customBorder: Border.all(color: Colors.blue), child: _cellContainer, onTap: onTap);
  }

  Color getMarkTextColor(int index, int num) {
    Color result;

    bool isRed = false;
    bool isGreen = false;

    if (_indirectHint != null) {
      if (_indirectHint!.redPotentials != null && _indirectHint!.redPotentials!.containsKey(index)) {
        var redMarks = (_indirectHint!.redPotentials![index] as List<Object?>).cast<int>();
        if (redMarks.contains(num + 1)) {
          isRed = true;
        }
      }

      if (_indirectHint!.greenPotentials != null && _indirectHint!.greenPotentials!.containsKey(index)) {
        var greenMarks = (_indirectHint!.greenPotentials![index] as List<Object?>).cast<int>();
        if (greenMarks.contains(num + 1)) {
          isGreen = true;
        }
      }
    }

    if (!isRed && !isGreen) {
      if (_directHint != null) {
        if (_directHint!.cellIndex == index) {
          if (_directHint!.cellValue == num + 1) {
            isGreen = true;
          }
        }
      }

      if (_indirectHint != null) {
        if (_indirectHint!.cellIndex == index) {
          if (_indirectHint!.cellValue == num + 1) {
            isGreen = true;
          }
        }
      }
    }

    result = Color.fromARGB(255, 0x16, 0x69, 0xA9);
    if (isRed && isGreen) {
      result = Colors.orange;
    } else if (isRed) {
      result = Colors.red;
    } else if (isGreen) {
      result = Colors.green;
    }

    return result;
  }

  ///
  /// 笔记网格控件
  ///
  Widget _markGridCellWidget(BuildContext context, int index, GestureTapCallback onTap) {
    Widget markGrid = InkWell(
        highlightColor: Colors.blue,
        customBorder: Border.all(color: Colors.blue),
        onTap: onTap,
        child: Container(
            alignment: Alignment.center,
            margin: EdgeInsets.all(1),
            decoration:
                BoxDecoration(color: _gridCellBgColor(index), border: Border.all(width: 1, color: Colors.black12)),
            child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                itemCount: 9,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                itemBuilder: (BuildContext context, int _index) {
                  String markNum = '${_state.mark[index][_index + 1] ? _index + 1 : ""}';
                  return Text(markNum,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: getMarkTextColor(index, _index), fontSize: 11));
                })));

    return markGrid;
  }

  // cell onTop function
  _cellOnTapBuilder(index) {
    // log.d("_wellOnTapBuilder build $index ...");
    return () {
      setState(() {
        _chooseSudokuBox = index;
      });
      if (_state.sudoku!.puzzle[index] != 0) {
        return;
      }
    };
  }

  Size _getSudokuGridSize(BuildContext context) {
    if (_sudoku_grid_key.currentContext?.findRenderObject() != null) {
      final RenderBox renderBox = _sudoku_grid_key.currentContext?.findRenderObject() as RenderBox;
      return Size(renderBox.size.width, renderBox.size.height);
    }
    return Size(0, 0);
  }

  Widget _bodyWidget(BuildContext context) {
    if (_state.sudoku == null) {
      return Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: Center(
              child:
                  Text('Sudoku Exiting...', style: TextStyle(color: Colors.black), textDirection: TextDirection.ltr)));
    }
    return Container(
      padding: EdgeInsets.all(3.0),
      child: Column(children: [
        /// status zone
        /// life / tips / timer on here
        Container(
          height: 50,
          padding: EdgeInsets.all(5.0),
          child: Row(children: <Widget>[
            Text(
                "${LocalizationUtils.localizationLevelName(context, _state.sudoku!.level)}(${_state.sudoku!.difficulty}) - ${LocalizationUtils.localizationGameStatus(context, _state.status)} - ${_state.timer}"),
            Spacer(),
            Row(children: <Widget>[lifePng, Text(" x ${_state.wrongTimes}", style: TextStyle(fontSize: 18))]),
            Spacer(),
            Row(children: <Widget>[ideaPng, Text(" x ${_state.hintTimes}", style: TextStyle(fontSize: 18))])
          ]),
        ),

        /// 9 x 9 cells sudoku puzzle board
        /// the whole sudoku game draw it here
        Stack(children: [
          GridView.builder(
              key: _sudoku_grid_key,
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 81,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 9),
              itemBuilder: ((BuildContext context, int index) {
                int num = 0;
                if (_state.sudoku?.puzzle.length == 81) {
                  num = _state.sudoku!.puzzle[index];
                }

                // 用户做标记
                bool isUserMark = _state.sudoku!.puzzle[index] == 0 && _state.mark[index].any((element) => element);

                if (isUserMark) {
                  return _markGridCellWidget(context, index, _cellOnTapBuilder(index));
                }
                return _gridCellWidget(context, index, num, _cellOnTapBuilder(index));
              })),
          IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                  size: _getSudokuGridSize(context), painter: HintPainter(this._directHint, this._indirectHint))),
        ]),

        /// user input zone
        /// use fillZone choose number fill cells or mark notes
        /// use toolZone to pause / exit game,
        _fillZone(context),
        _toolZone(context),
        _hintZone(context)
      ]),
    );
  }

  @override
  void deactivate() {
    log.d("on deactivate");
    WidgetsBinding.instance.removeObserver(this);
    super.deactivate();
  }

  @override
  void dispose() {
    log.d("on dispose");
    _pauseTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gaming();
  }

  @override
  void didChangeDependencies() {
    log.d("didChangeDependencies");
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(SudokuGamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    log.d("on did update widget");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        log.d("is paused app lifecycle state");
        _pause();
        break;
      case AppLifecycleState.resumed:
        log.d("is resumed app lifecycle state");
        if (!_manualPause) {
          _gaming();
        }
        break;
      default:
        break;
    }
  }

  // 定时器
  Timer? _timer;

  void _gaming() {
    if (_state.status == SudokuGameStatus.pause) {
      log.d("on _gaming");
      _state.updateStatus(SudokuGameStatus.gaming);
      _state.persistent();
      _beginTimer();
    }
  }

  void _pause() {
    if (_state.status == SudokuGameStatus.gaming) {
      log.d("on _pause");
      _state.updateStatus(SudokuGameStatus.pause);
      _state.persistent();
      _pauseTimer();
    }
  }

  // 开始计时
  void _beginTimer() {
    log.d("timer begin");
    if (_timer == null) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_state.status == SudokuGameStatus.gaming) {
          _state.tick();
          return;
        }
        timer.cancel();
      });
    }
  }

  // 暂停计时
  void _pauseTimer() {
    if (_timer != null) {
      if (_timer!.isActive) {
        _timer!.cancel();
      }
    }
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    Scaffold scaffold = Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
          icon: Icon(Icons.info_outline),
          onPressed: () {
            return _aboutDialogAction(context);
          },
        )
      ]),
      body: _willPopWidget(
        context,
        ScopedModelDescendant<SudokuState>(builder: (context, child, model) => _bodyWidget(context)),
        (didPop) async {
          if (didPop) {
            _pause();
          }
        },
      ),
    );

    return scaffold;
  }
}
