import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart' hide Level;
import 'package:scoped_model/scoped_model.dart';
import 'package:sprintf/sprintf.dart';
import 'package:sudoku/constant.dart';
import 'package:sudoku/state/hive/sudoku_type_adapter.dart';

import '../sudoku/core.dart';
import '../sudoku/native_sudoku_api.g.dart';
import '../sudoku/tools.dart';

part 'sudoku_state.g.dart';

final Logger log = Logger();

@HiveType(typeId: 1)
enum SudokuGameStatus {
  @HiveField(0)
  initialize,
  @HiveField(1)
  gaming,
  @HiveField(2)
  pause,
  @HiveField(3)
  fail,
  @HiveField(4)
  success
}

@HiveType(typeId: 2)
class SudokuState extends Model {
  static const String _hiveBoxName = "sudoku.store";
  static const String _hiveStateName = "state";

  @HiveField(0)
  late SudokuGameStatus status;

  // sudoku
  @HiveField(1)
  Sudoku? sudoku;

  // timing
  @HiveField(2)
  late int timing;

  // 错误次数
  @HiveField(3)
  late int wrongTimes;

  // 提示次数
  @HiveField(4)
  late int hintTimes;

  // sudoku 填写记录
  @HiveField(5)
  late List<int> record;

  // 笔记
  @HiveField(6)
  late List<List<bool>> mark;

  // 是否完成
  bool get isComplete {
    if (sudoku == null) {
      return false;
    }
    int value;
    for (int i = 0; i < 81; ++i) {
      value = sudoku!.puzzle[i];
      if (value == 0) {
        value = record[i];
      }
      if (value == 0) {
        return false;
      }
    }

    return true;
  }

  SudokuState({Sudoku? sudoku}) {
    initialize(sudoku: sudoku);
  }

  static SudokuState newSudokuState({Sudoku? sudoku}) {
    SudokuState state = new SudokuState(sudoku: sudoku);
    return state;
  }

  void initialize({Sudoku? sudoku}) {
    status = SudokuGameStatus.initialize;
    this.sudoku = sudoku;
    this.timing = 0;
    this.wrongTimes = 0;
    this.hintTimes = 0;
    this.record = List.generate(81, (index) => 0);
    //默认不显示备选数字
    this.mark = List.generate(81, (index) => List.generate(10, (index) => false));
    if(this.sudoku != null) {
      this.sudoku!.getDifficulty();
    }
    notifyListeners();
  }

  void tick() {
    this.timing++;
    notifyListeners();
  }

  String get timer => sprintf("%02i:%02i", [timing ~/ 60, timing % 60]);

  void wrong() {
    this.wrongTimes++;
    notifyListeners();
  }

  void showHint() {
    this.hintTimes++;
    notifyListeners();
  }

  void rebuildMarks() {
    this.mark = List.generate(81, (index) => List.generate(10, (index) => true));
    for (int index = 0; index < 81; ++index) {
      if (sudoku!.puzzle[index] != 0) {
        cleanMark(index);

        List<int> colIndexes = Matrix.getColIndexes(Matrix.getCol(index));
        List<int> rowIndexes = Matrix.getRowIndexes(Matrix.getRow(index));
        List<int> zoneIndexes = Matrix.getZoneIndexes(zone: Matrix.getZone(index: index));

        colIndexes.forEach((_) {
          cleanMark(_, num: sudoku!.puzzle[index]);
        });
        rowIndexes.forEach((_) {
          cleanMark(_, num: sudoku!.puzzle[index]);
        });
        zoneIndexes.forEach((_) {
          cleanMark(_, num: sudoku!.puzzle[index]);
        });
      }
    }
  }

  IndirectHint? CheckMarksHint() {
    Map<int?, List<int>?> removablePotentials = new Map();
    Map<int?, List<int>?> addPotentials = new Map();
    Map<int?, List<int>?> redPotentials = new Map();
    Map<int?, List<int>?> greenPotentials = new Map();
    List<Link?> links = List.empty();
    String hintMessage = '<html><body><h2>Update marks</h2>';

    for (int index = 0; index < 81; ++index) {
      if (sudoku!.puzzle[index] == 0 && record[index] == 0) {
        //不是题目中给出的数字,并且未填写答案的格子
        List<int> colIndexes = Matrix.getColIndexes(Matrix.getCol(index));
        List<int> rowIndexes = Matrix.getRowIndexes(Matrix.getRow(index));
        List<int> zoneIndexes = Matrix.getZoneIndexes(zone: Matrix.getZone(index: index));

        int row = index ~/ 9;
        int col = index % 9;

        //重新计算备选数
        //默认所有数字都是备选数
        //在任何一个区域中如果出现了某个数字，则从备选数中去掉
        //这里可以重复去掉，不会有问题
        List<bool> newMarks = List.generate(10, (index) => true);
        colIndexes.forEach((_) {
          newMarks[sudoku!.puzzle[_]] = false;
          newMarks[record[_]] = false;
        });

        rowIndexes.forEach((_) {
          newMarks[sudoku!.puzzle[_]] = false;
          newMarks[record[_]] = false;
        });

        zoneIndexes.forEach((_) {
          newMarks[sudoku!.puzzle[_]] = false;
          newMarks[record[_]] = false;
        });

        List<bool> oldMarks = this.mark[index];
        if (oldMarks.getRange(1, 10).any((v) => v)) {
          //有备选数字，可能有多余的被选数需要删除
          //如果少了的数字是答案要加进去，否则不用加进去
          List<int> deleteMarklist = [];
          for (int j = 1; j < 10; j++) {
            if (oldMarks[j] && !newMarks[j]) {
              deleteMarklist.add(j);
            }
          }

          if(!oldMarks[sudoku!.solution[index]]) {
            List<int> addMarklist = [sudoku!.solution[index]];
            addPotentials[index] = addMarklist;
            hintMessage = hintMessage + '<p>add cell r${row + 1}c${col + 1} marks ' + addMarklist.toString() + '</p>';
          }

          if (!deleteMarklist.isEmpty) {
            removablePotentials[index] = deleteMarklist;
            redPotentials[index] = deleteMarklist;
            hintMessage =
                hintMessage + '<p>remove  r${row + 1}c${col + 1} invalid marks ' + deleteMarklist.toString() + '</p>';
          }
        } else {
          //一个选数字都没有？不对，应该要加上所有备选数字
          List<int> addMarklist = [];
          for (int j = 1; j < 10; j++) {
            if (newMarks[j]) {
              addMarklist.add(j);
            }
          }

          if (!addMarklist.isEmpty) {
            addPotentials[index] = addMarklist;
            hintMessage = hintMessage + '<p>add cell r${row + 1}c${col + 1} marks ' + addMarklist.toString() + '</p>';
          }
        }
      }
    }

    if (removablePotentials.isEmpty && addPotentials.isEmpty) {
      return null;
    } else {
      hintMessage = hintMessage + '</body></html>';
      var result = IndirectHint(removablePotentials: removablePotentials,redPotentials: redPotentials, HintMessage: hintMessage);
      result.addPotentials = addPotentials;
      return result;
    }
  }

  List<int> getCheckedMarks() {
    List<List<bool>> checkedMarkList = List.generate(81, (index) => List.generate(10, (index) => false));

    for (int index = 0; index < 81; ++index) {
      if (sudoku!.puzzle[index] == 0 && record[index] == 0) {
        //不是题目中给出的数字,并且未填写答案
        List<int> colIndexes = Matrix.getColIndexes(Matrix.getCol(index));
        List<int> rowIndexes = Matrix.getRowIndexes(Matrix.getRow(index));
        List<int> zoneIndexes = Matrix.getZoneIndexes(zone: Matrix.getZone(index: index));

        int row = index ~/ 9;
        int col = index % 9;

        //重新计算备选数
        //默认所有数字都是备选数
        //在任何一个区域中如果出现了某个数字(题目或已填答案)，则从备选数中去掉
        //这里可以重复去掉，不会有问题
        List<bool> checkedMarks = List.generate(10, (index) => true);
        colIndexes.forEach((_) {
          checkedMarks[sudoku!.puzzle[_]] = false;
          checkedMarks[record[_]] = false;
        });

        rowIndexes.forEach((_) {
          checkedMarks[sudoku!.puzzle[_]] = false;
          checkedMarks[record[_]] = false;
        });

        zoneIndexes.forEach((_) {
          checkedMarks[sudoku!.puzzle[_]] = false;
          checkedMarks[record[_]] = false;
        });

        List<bool> currentMarks = this.mark[index];
        if (currentMarks.getRange(1, 10).any((v) => v)) {
          //有备选数字
          //把已经排除的备选数字排除
          List<bool> temp = List<bool>.of(checkedMarks);
          for (int j = 1; j < 10; j++) {
            if (!currentMarks[j] && checkedMarks[j]) {
              temp[j] = false;
            }
          }

          //这里判断一下排除的备选数是否正确，如果排除后没有备选数了，则现有的备选数不正确，直接修改为计算的结果
          if (temp.getRange(1, 10).any((v) => v)) {
            checkedMarkList[index] = temp;
          } else {
            checkedMarkList[index] = checkedMarks;
          }
        } else {
          //目前一个选数字都没有？说明还没有使用备选数，这里要加上所有备选数字
          checkedMarkList[index] = checkedMarks;
        }
      }
    }

    List<int> PotentialValues = [];
    for (int i = 0; i < 81; ++i) {
      for (int j = 1; j < 10; j++) {
        if (checkedMarkList[i][j]) {
          PotentialValues.add(j);
        } else {
          PotentialValues.add(0);
        }
      }
    }

    return PotentialValues;
  }

  void setRecord(int index, int num) {
    if (index < 0 || index > 80 || num < 0 || num > 9) {
      throw new ArgumentError('index border [0,80] num border [0,9] , input index:$index | num:$num out of the border');
    }
    if (this.status == SudokuGameStatus.initialize) {
      throw new ArgumentError("can't update record in \"initialize\" status");
    }

    List<int> puzzle = this.sudoku!.puzzle;

    if (puzzle[index] != 0) {
      this.record[index] = 0;
      notifyListeners();
      return;
    }
    this.record[index] = num;
    // 清空笔记
    cleanMark(index);

    if (this.sudoku!.solution[index] == num) {
      /// 填写正确
      /// 更新填写记录,笔记清除
      /// 清空当前index笔记
      /// 移除 zone row col 中的对应笔记
      List<int> colIndexes = Matrix.getColIndexes(Matrix.getCol(index));
      List<int> rowIndexes = Matrix.getRowIndexes(Matrix.getRow(index));
      List<int> zoneIndexes = Matrix.getZoneIndexes(zone: Matrix.getZone(index: index));

      colIndexes.forEach((_) {
        cleanMark(_, num: num);
      });
      rowIndexes.forEach((_) {
        cleanMark(_, num: num);
      });
      zoneIndexes.forEach((_) {
        cleanMark(_, num: num);
      });
    }
  }

  void cleanRecord(int index) {
    if (this.status == SudokuGameStatus.initialize) {
      throw new ArgumentError("can't update record in \"initialize\" status");
    }
    List<int> puzzle = this.sudoku!.puzzle;
    if (puzzle[index] == 0) {
      this.record[index] = 0;
    }
    notifyListeners();
  }

  void switchRecord(int index, int num) {
    log.d('switchRecord $index - $num');
    if (index < 0 || index > 80 || num < 0 || num > 9) {
      throw new ArgumentError('index border [0,80] num border [0,9] , input index:$index | num:$num out of the border');
    }
    if (this.status == SudokuGameStatus.initialize) {
      throw new ArgumentError("can't update record in \"initialize\" status");
    }
    if (sudoku!.puzzle[index] != 0) {
      return;
    }
    if (record[index] == num) {
      cleanRecord(index);
    } else {
      setRecord(index, num);
    }
  }

  void setMark(int index, int num) {
    // index表示单元格，num表示选的哪个数字
    if (index < 0 || index > 80) {
      throw new ArgumentError('index border [0,80], input index:$index out of the border');
    }
    if (num < 1 || num > 9) {
      throw new ArgumentError("num must be [1,9]");
    }

    if (sudoku!.puzzle[index] != 0) {
      return;
    }

    if (this.record[index] != 0) {
      return;
    }

    // 清空数字
    // 设置备选数字，意味着原来的答案可能填错了（如果填了的话，所以要清空一下）
    cleanRecord(index);

    List<bool> markPoint = this.mark[index];
    markPoint[num] = true;
    this.mark[index] = markPoint;
    notifyListeners();
  }

  void cleanMark(int index, {int? num}) {
    //num为null表示全部清空，否则只清空指定数字
    if (index < 0 || index > 80) {
      throw new ArgumentError('index border [0,80], input index:$index out of the border');
    }
    List<bool> markPoint = this.mark[index];
    if (num == null) {
      markPoint = List.generate(10, (index) => false);
    } else {
      markPoint[num] = false;
    }
    this.mark[index] = markPoint; //??
    notifyListeners();
  }

  void switchMark(int index, int num) {
    //开关，反转选中状态
    if (index < 0 || index > 80) {
      throw new ArgumentError('index border [0,80], input index:$index out of the border');
    }
    if (num < 1 || num > 9) {
      throw new ArgumentError("num must be [1,9]");
    }

    List<bool> markPoint = this.mark[index];
    if (!markPoint[num]) {
      setMark(index, num);
    } else {
      cleanMark(index, num: num);
    }
  }

  void updateSudoku(Sudoku sudoku) {
    this.sudoku = sudoku;
    if(this.sudoku != null) {
      this.sudoku!.getDifficulty();
    }
    notifyListeners();
  }

  void updateStatus(SudokuGameStatus status) {
    this.status = status;
    notifyListeners();
  }

  // 检查该数字是否还有库存(判断是否填写满)
  bool hasNumStock(int num) {
    if (this.status == SudokuGameStatus.initialize) {
      throw new ArgumentError("can't check num stock in \"initialize\" status");
    }
    int puzzleLength = sudoku!.puzzle.where((element) => element == num).length;
    int recordLength = record.where((element) => element == num).length;
    return 9 > (puzzleLength + recordLength);
  }

  void persistent() async {
    await _initHive();
    var sudokuStore = await Hive.openBox(_hiveBoxName);
    await sudokuStore.put(_hiveStateName, this);
    if (sudokuStore.isOpen) {
      await sudokuStore.compact();
      await sudokuStore.close();
    }

    log.d("hive persistent");
  }

  ///
  /// resume SudokuState from db(hive)
  static Future<SudokuState> resumeFromDB() async {
    await _initHive();

    SudokuState state;
    Box? sudokuStore;

    try {
      sudokuStore = await Hive.openBox(_hiveBoxName);
      state = sudokuStore.get(_hiveStateName, defaultValue: SudokuState.newSudokuState());
    } catch (e) {
      log.d(e);
      state = SudokuState.newSudokuState();
    } finally {
      if (sudokuStore?.isOpen ?? false) {
        await sudokuStore!.close();
      }
    }

    return state;
  }

  static final SudokuAdapter _sudokuAdapter = SudokuAdapter();
  static final SudokuStateAdapter _sudokuStateAdapter = SudokuStateAdapter();
  static final SudokuGameStatusAdapter _sudokuGameStatusAdapter = SudokuGameStatusAdapter();

  static _initHive() async {
    await Hive.initFlutter(Constant.packageName);
    if (!Hive.isAdapterRegistered(_sudokuAdapter.typeId)) {
      Hive.registerAdapter<Sudoku>(_sudokuAdapter);
    }
    if (!Hive.isAdapterRegistered(_sudokuStateAdapter.typeId)) {
      Hive.registerAdapter<SudokuState>(_sudokuStateAdapter);
    }
    if (!Hive.isAdapterRegistered(_sudokuGameStatusAdapter.typeId)) {
      Hive.registerAdapter<SudokuGameStatus>(_sudokuGameStatusAdapter);
    }
  }
}
