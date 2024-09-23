import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/sudoku_localizations.dart';
import 'package:logger/logger.dart' hide Level;
import 'package:scoped_model/scoped_model.dart';
import 'package:sudoku/ml/yolov8/yolov8_output.dart';
import 'package:sudoku/page/ai_detection_painter.dart';

import '../state/sudoku_state.dart';
import '../sudoku/core.dart';

Logger log = Logger();

/// just define magic 0 to SUDOKU_EMPTY_DIGIT , make code easier to read and know
const int SUDOKU_EMPTY_DIGIT = 0;

/// Detect Ref
///
///
class DetectRef {
  /// puzzle index
  int index;

  /// puzzle value of index
  int value;

  /// puzzle value of index from detect box
  YoloV8DetectionBox box;

  DetectRef({
    required this.index,
    required this.value,
    required this.box,
  });
}

class AIDetectionMainWidget extends StatefulWidget {
  final List<DetectRef?> detectRefs;
  final ui.Image image;
  final Uint8List imageBytes;
  final double widthScale;
  final double heightScale;
  final YoloV8Output output;

  const AIDetectionMainWidget({
    Key? key,
    required this.detectRefs,
    required this.image,
    required this.imageBytes,
    required this.widthScale,
    required this.heightScale,
    required this.output,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AIDetectionMainWidgetState();
}

class _AIDetectionMainWidgetState extends State<AIDetectionMainWidget> {
  /// amendable cell edit on this "amendPuzzle"
  ///
  /// when amendPuzzle[index] != SUDOKU_EMPTY_DIGIT (-1) , grid cell of index will show value with blue color text
  late List<int> amendPuzzle;

  late List<int> solution;
  late String solveMessage;
  int? selectedBox = null;

  /// cacheable widgets
  /// _aiDetectionPainter cache instance
  var _aiDetectionPainter;

  @override
  void initState() {
    super.initState();

    amendPuzzle = _emptyMatrix();
    solution = _emptyMatrix();
    solveMessage = "";

    /// 初始化 AIDetectionPainter
    _aiDetectionPainter = AIDetectionPainter(
      image: widget.image,
      output: widget.output,
      offset: ui.Offset(0, 0),
      widthScale: widget.widthScale,
      heightScale: widget.heightScale,
    );
  }

  _emptyMatrix() {
    return List.generate(81, (_) => SUDOKU_EMPTY_DIGIT);
  }

  _solveSudoku() async {
    log.d("solve sudoku puzzle ...");

    // merge puzzle from detectRefs and amendPuzzle
    final List<int> puzzle = _emptyMatrix();
    for (var index = 0; index < puzzle.length; ++index) {
      DetectRef? detectRef = widget.detectRefs[index];
      if (amendPuzzle[index] != SUDOKU_EMPTY_DIGIT) {
        puzzle[index] = amendPuzzle[index];
      } else if (detectRef != null && detectRef.value != SUDOKU_EMPTY_DIGIT) {
        puzzle[index] = detectRef.value;
      }
    }

    var valid = await Sudoku.checkValidity(puzzle);
    if (valid == 0) {
      setState(() {
        solution = _emptyMatrix();
        solveMessage = AppLocalizations.of(context)!.errorNoSolution;
      });
    } else if (valid == 1) {
      var sudoku =  await Sudoku.from(puzzle);
      setState(() {
        solution = sudoku.solution;
        solveMessage = "";
      });
    } else {
      setState(() {
        solution = _emptyMatrix();
        solveMessage = AppLocalizations.of(context)!.errorMoreThanOneSolution;
      });
    }
  }

  _newCustomGame() async {
    final List<int> puzzle = _emptyMatrix();
    for (var index = 0; index < puzzle.length; ++index) {
      DetectRef? detectRef = widget.detectRefs[index];
      if (amendPuzzle[index] != SUDOKU_EMPTY_DIGIT) {
        puzzle[index] = amendPuzzle[index];
      } else if (detectRef != null && detectRef.value != SUDOKU_EMPTY_DIGIT) {
        puzzle[index] = detectRef.value;
      }
    }

    var valid = await Sudoku.checkValidity(puzzle);
    if (valid == 0) {
      setState(() {
        solution = _emptyMatrix();
        solveMessage = AppLocalizations.of(context)!.errorNoSolution;
      });
    } else if (valid == 1) {
      var sudoku = await Sudoku.from(puzzle);
      SudokuState state = ScopedModel.of<SudokuState>(context);
      state.initialize(sudoku: sudoku);
      state.updateStatus(SudokuGameStatus.pause);
      Navigator.popAndPushNamed(context, "/gaming");
    } else {
      setState(() {
        solution = _emptyMatrix();
        solveMessage = AppLocalizations.of(context)!.errorMoreThanOneSolution;
      });
    }
  }

  /// _notDetectedWidget instance
  _notDetectedWidget(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.block,
          size: 128,
          color: Colors.white,
          shadows: [ui.Shadow(blurRadius: 1.68)],
        ),
        Center(
          child: Text(AppLocalizations.of(context)!.notDetected,
              style: TextStyle(
                fontSize: 36,
                color: Colors.white,
                shadows: [ui.Shadow(blurRadius: 1.68)],
              )),
        ),
      ],
    );
  }

  /// build detected widget function
  ///
  /// with amendable gridview
  _buildDetectedWidget() {
    final detectRefs = widget.detectRefs;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: false,
      itemCount: 81,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 9),
      itemBuilder: ((BuildContext context, int index) {
        DetectRef? detectRef = detectRefs[index];

        // default cell text/style/border style
        // detected by AI , color with yellow
        // amend of cell by user , color with blue
        // solutions from Sudoku Solver , color with white
        var cellTextColor = detectRef != null && detectRef.value != SUDOKU_EMPTY_DIGIT ? Colors.yellow : Colors.white;
        var cellText = "";
        var cellBorder = Border.all(color: Colors.amber, width: 1.5);

        if (amendPuzzle[index] != SUDOKU_EMPTY_DIGIT) {
          // 修正的谜题
          // if this cell of puzzle been amend , change cell text color to blue
          cellText = amendPuzzle[index].toString();
          cellTextColor = Colors.blue;
        } else if (detectRef != null && detectRef.value != SUDOKU_EMPTY_DIGIT) {
          // 检测关联的谜题
          cellText = detectRef.value.toString();
          cellTextColor = Colors.yellow;
        } else if (solution[index] != SUDOKU_EMPTY_DIGIT) {
          // solutions
          cellText = solution[index].toString();
          cellTextColor = Colors.white;
        }

        if (index == selectedBox) {
          // if choose cell , change the border color to blue
          cellBorder = Border.all(color: Colors.blue, width: 2.0);
        }

        var _cellContainer = Container(
          decoration: BoxDecoration(
            border: cellBorder,
          ),
          child: Text(
            cellText,
            style: TextStyle(shadows: [ui.Shadow(blurRadius: 3.68)], fontSize: 30, color: cellTextColor),
          ),
        );

        return GestureDetector(
          child: _cellContainer,
          onTap: () => _selectedBoxSwitch(index),
        );
      }),
    );
  }

  _selectedBoxSwitch(index) {
    setState(() {
      if (index == selectedBox) {
        selectedBox = null;
        // cancel selectedBox
      } else {
        selectedBox = index;
        // @TODO here should show dialog to input amend value from user
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uiImage = widget.image;

    // 主画面控件
    var _mainWidget;

    var hasDetectionSudoku = widget.output.boxes.isNotEmpty;
    if (!hasDetectionSudoku) {
      _mainWidget = _notDetectedWidget(context);
    } else {
      _mainWidget = _buildDetectedWidget();
    }

    var _drawWidget = CustomPaint(
      isComplex: true,
      willChange: true,
      child: _mainWidget,
      painter: _aiDetectionPainter,
    );

    Widget _amendTool(BuildContext context) {
      List<Widget> fillTools = List.generate(9, (index) {
        int num = index + 1;
        var fillOnPressed = () async {
          amendPuzzle[selectedBox!] = num;
          setState(() {});
        };

        return Expanded(
            flex: 1,
            child: Container(
                margin: EdgeInsets.all(1),
                decoration: BoxDecoration(border: BorderDirectional()),
                child: CupertinoButton(
                    color: Colors.black12,
                    padding: EdgeInsets.all(1),
                    child: Text('${index + 1}',
                        style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
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
                    if (amendPuzzle[selectedBox!] > 0) {
                      amendPuzzle[selectedBox!] = 0;
                    } else {
                      DetectRef? detectRef = widget.detectRefs[selectedBox!];
                      if ((detectRef?.value ?? 0) > 0) {
                        detectRef!.value = 0;
                      }
                    }
                    setState(() {});
                  }))));

      return Offstage(offstage: selectedBox == null, child: Row(children: fillTools));
    }

    var _btnWidget = Offstage(
        offstage: !hasDetectionSudoku,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          CupertinoButton(
              padding: EdgeInsets.all(1),
              onPressed:_newCustomGame,
              child: Text(AppLocalizations.of(context)!.iWantTryIt, style: TextStyle(fontSize: 16))),
          CupertinoButton(
              padding: EdgeInsets.all(1),
              onPressed: _solveSudoku,
              child: Text(AppLocalizations.of(context)!.showAnswer, style: TextStyle(fontSize: 16))),
        ]));

    var _bodyWidget = Column(
      children: [
        // show solve message output
        Center(
          child: Container(
              margin: EdgeInsets.all(5),
              width: MediaQuery.of(context).size.width * 0.9,
              child: Text(
                solveMessage,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              )),
        ),
        Center(
          child: SizedBox(width: uiImage.width.toDouble(), height: uiImage.height.toDouble(), child: _drawWidget),
        ),
        Center(
          child: Container(
            margin: EdgeInsets.fromLTRB(0, 5, 0, 0),
            height: 35,
            width: MediaQuery.of(context).size.width * 0.9,
            child: _amendTool(context),
          ),
        ),
        _btnWidget,
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.detectionResult)),
      body: _bodyWidget,
    );
  }
}
