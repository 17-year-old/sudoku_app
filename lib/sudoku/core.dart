import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_sudoku_api.g.dart';

class Sudoku {
  Level level;
  List<int> puzzle;
  List<int> solution;
  double difficulty = 0;

  Sudoku(this.level, this.puzzle, this.solution);

  static Future<Sudoku> generate(Level level) async {
    var _api = NativeSudokuApi();
    var _puzzle = await _api.generate(level);
    var _solution = await _api.solve(_puzzle);
    var result = Sudoku(level, _puzzle, _solution);
    return result;
  }

  static Future<Sudoku> from(List<int> puzzle) async {
    var _api = NativeSudokuApi();
    var _solution = await _api.solve(Int32List.fromList(puzzle));
    var result = Sudoku(Level.custom, puzzle, _solution);
    return result;
  }

  static Future<int> checkValidity(List<int> puzzle) async {
    var _api = NativeSudokuApi();
    return await _api.checkValidity(Int32List.fromList(puzzle));
  }

  void getDifficulty() async {
    RootIsolateToken rootIsolateToken = ServicesBinding.rootIsolateToken!;
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_internalGetDifficulty, [rootIsolateToken, this.puzzle, receivePort.sendPort]);
    this.difficulty = await receivePort.first;
  }

  static _internalGetDifficulty(List<dynamic> args) async {
    RootIsolateToken rootIsolateToken = args[0];
    List<int> puzzle = args[1];
    SendPort sendPort = args[2];
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    var _api = NativeSudokuApi();
    var result = await _api.difficulty(Int32List.fromList(puzzle));
    sendPort.send(result);
  }

  static Future<String> analyse(List<int> puzzle, List<int> marks) async {
    RootIsolateToken rootIsolateToken = ServicesBinding.rootIsolateToken!;
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_internalAnalyse, [rootIsolateToken, puzzle, marks, receivePort.sendPort]);
    return await receivePort.first;
  }

  static _internalAnalyse(List<dynamic> args) async {
    RootIsolateToken rootIsolateToken = args[0];
    List<int> puzzle = args[1];
    List<int> marks = args[2];
    SendPort sendPort = args[3];
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    var _api = NativeSudokuApi();
    var result = await _api.analyse(Int32List.fromList(puzzle), Int32List.fromList(marks));
    sendPort.send(result);
  }
}
