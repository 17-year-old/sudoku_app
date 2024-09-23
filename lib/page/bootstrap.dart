import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/sudoku_localizations.dart';
import 'package:logger/logger.dart' hide Level;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sudoku/state/sudoku_state.dart';
import 'package:sudoku/util/localization_util.dart';

import '../sudoku/core.dart';
import '../sudoku/native_sudoku_api.g.dart';
import 'ai_scan.dart';

final Logger log = Logger();

class BootstrapPage extends StatefulWidget {
  BootstrapPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _BootstrapPageState createState() => _BootstrapPageState();
}

Widget _buttonWrapper(BuildContext context, Widget childBuilder(BuildContext content)) {
  return Container(margin: EdgeInsets.fromLTRB(0, 10, 0, 10), width: 300, height: 60, child: childBuilder(context));
}

Widget _aiSolverButton(BuildContext context) {
  String buttonLabel = AppLocalizations.of(context)!.menuAISolver;
  return _buttonWrapper(
      context,
      (content) => CupertinoButton(
            color: Colors.blue,
            child: Text("$buttonLabel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              log.d("AI Solver Scanner");
              WidgetsFlutterBinding.ensureInitialized();

              final cameras = await availableCameras();
              final firstCamera = cameras.first;
              final aiScanPage = AIScanPage(camera: firstCamera);

              Navigator.push(
                  context,
                  PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (BuildContext context, _, __) {
                        return aiScanPage;
                      }));
            },
          ));
}

Widget _continueGameButton(BuildContext context) {
  return ScopedModelDescendant<SudokuState>(builder: (context, child, state) {
    String buttonLabel = AppLocalizations.of(context)!.menuContinueGame;
    String continueMessage =
        "${LocalizationUtils.localizationLevelName(context, state.sudoku?.level ?? Level.custom)} - ${state.timer}";
    return Offstage(
        offstage: state.status != SudokuGameStatus.pause,
        child: Container(
          width: 300,
          height: 80,
          child: CupertinoButton(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                      child: Text(buttonLabel, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                  Container(child: Text(continueMessage, style: TextStyle(fontSize: 13)))
                ],
              ),
              onPressed: () {
                Navigator.pushNamed(context, "/gaming");
              }),
        ));
  });
}

Widget _newGameButton(BuildContext context) {
  return _buttonWrapper(
      context,
      (_) => CupertinoButton(
          color: Colors.blue,
          child: Text(
            AppLocalizations.of(context)!.menuNewGame,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            // cancel new game button
            Widget cancelButton = SizedBox(
                height: 60,
                width: MediaQuery.of(context).size.width,
                child: Container(
                    margin: EdgeInsets.fromLTRB(0, 5, 0, 0),
                    child: CupertinoButton(
                      //                      color: Colors.red,
                      child: Text(AppLocalizations.of(context)!.levelCancel),
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                    )));

            // iterative difficulty build buttons
            List<Widget> buttons = [];
            Level.values.forEach((Level level) {
              if (level != Level.custom) {
                String levelName = LocalizationUtils.localizationLevelName(context, level);
                buttons.add(SizedBox(
                    height: 60,
                    width: MediaQuery.of(context).size.width,
                    child: Container(
                        margin: EdgeInsets.all(2.0),
                        child: CupertinoButton(
                          child: Text(
                            levelName,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            log.d("begin generator Sudoku with level : $levelName");
                            await _sudokuGenerate(context, level);
                            Navigator.popAndPushNamed(context, "/gaming");
                          },
                        ))));
              }
            });
            buttons.add(cancelButton);

            showCupertinoModalBottomSheet(
              context: context,
              builder: (context) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Material(
                        child: Container(
                            height: 300, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: buttons))),
                  ),
                );
              },
            );
          }));
}

_sudokuGenerate(BuildContext context, Level level) async {
  String sudokuGenerateText = AppLocalizations.of(context)!.sudokuGenerateText;
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
          child: Container(
              padding: EdgeInsets.all(10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                Container(margin: EdgeInsets.fromLTRB(10, 0, 0, 0), child: Text(sudokuGenerateText))
              ]))));

  var sudoku = await Sudoku.generate(level);
  SudokuState state = ScopedModel.of<SudokuState>(context);
  state.initialize(sudoku: sudoku);
  state.updateStatus(SudokuGameStatus.pause);
  Navigator.pop(context);
}

class _BootstrapPageState extends State<BootstrapPage> {
  @override
  Widget build(BuildContext context) {
    Widget body = Container(
        color: Colors.white,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Expanded(flex: 1, child: Image(image: AssetImage("assets/image/icon_logo.png"))),
          Expanded(
            flex: 1,
            child: Column(
              children: [_continueGameButton(context), _newGameButton(context), _aiSolverButton(context)],
            ),
          ),
        ]));

    return ScopedModelDescendant<SudokuState>(builder: (context, child, model) => Scaffold(body: body));
  }
}
