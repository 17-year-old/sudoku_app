import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/sudoku_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logger/logger.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sudoku/effect/sound_effect.dart';
import 'package:sudoku/page/bootstrap.dart';
import 'package:sudoku/page/sudoku_game.dart';
import 'package:sudoku/state/sudoku_state.dart';

import 'ml/detector.dart';

final Logger log = Logger();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // warmed up effect when application build before
  _soundEffectWarmedUp() async {
    await SoundEffect.init();
  }

  _modelWarmedUp() async {
    await DetectorFactory.getSudokuDetector();
    await DetectorFactory.getDigitsDetector();
  }

  Future<SudokuState> _loadState() async {
    _soundEffectWarmedUp();
    _modelWarmedUp();
    return await SudokuState.resumeFromDB();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SudokuState>(
      future: _loadState(),
      builder: (context, AsyncSnapshot<SudokuState> snapshot) {
        SudokuState sudokuState = SudokuState();
        BootstrapPage bootstrapPage = BootstrapPage(title: "Loading");
        SudokuGamePage sudokuGamePage = SudokuGamePage(title: "Sudoku");

        var app = MaterialApp(
            title: 'Sudoku',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: bootstrapPage,
            routes: <String, WidgetBuilder>{
              "/bootstrap": (context) => bootstrapPage,
              "/newGame": (context) => sudokuGamePage,
              "/gaming": (context) => sudokuGamePage
            });

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ScopedModel<SudokuState>(
            model: sudokuState,
            child: app,
          );
        }
        if (snapshot.hasError) {
          log.w("here is builder future throws error you should see it");
          final e = snapshot.error as Error;
          log.w(snapshot.error, stackTrace: e.stackTrace);
        }

        sudokuState = snapshot.data ?? SudokuState();
        return ScopedModel<SudokuState>(
          model: sudokuState,
          child: app,
        );
      },
    );
  }
}
