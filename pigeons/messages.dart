import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
    dartOut: 'lib/sudoku/native_sudoku_api.g.dart',
    dartOptions: DartOptions(),
    javaOut: 'android/app/src/main/java/com/fubailin/sudoku/SudokuApi.java',
    javaOptions: JavaOptions(package: 'com.fubailin.sudoku')))
enum Level { easy, medium, hard, expert, custom }

class Region {
  // 用来可视化某些按区域来分析的提示，在区域外面画框框
  // regionType表示区域类型：0小九宫,1行, 2列
  // regionIndex分别表示：哪个九宫，哪一行，哪一列
  int regionType;
  int regionIndex;
  Region(this.regionType, this.regionIndex);
}

class DirectHint {
  int cellIndex;
  int cellValue;
  String HintMessage;
  List<Region?> regions;

  DirectHint(this.cellIndex, this.cellValue,this.HintMessage, this.regions);
}

class Link {
  //用来可视化某些按小的格子来分析的提示
  //在备选数之间连线
  int srcCellIndex;
  int srcCellValue;
  int dstCellIndex;
  int dstCellValue;

  Link(this.srcCellIndex, this.srcCellValue, this.dstCellIndex, this.dstCellValue);
}

class IndirectHint {
  int? cellIndex;
  int? cellValue;
  String? HintMessage;
  List<Region?>? regions;
  List<int?>? selectedCells;

  //k表示哪个格子，相当于cellIndex, v中存的是哪些备选数字要被删掉，1-9,实际是List<int>
  Map<int?, Object?>? removablePotentials;
  Map<int?, Object?>? redPotentials;
  Map<int?, Object?>? greenPotentials;

  List<Link?>? links;
  //需要增加备选数的情况
  Map<int?, Object?>? addPotentials;
}


@HostApi()
abstract class NativeSudokuApi {
  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  Int32List generate(Level level);

  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  int checkValidity(Int32List data);

  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String analyse(Int32List data, Int32List PotentialValues);

  @async
  //有下面这个注解才能在后台运行，不然始终是在主线程执行
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  double difficulty(Int32List data);

  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DirectHint? getDirectHint(Int32List data);

  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  IndirectHint? getIndirectHint(Int32List data, Int32List PotentialValues);

  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  Int32List solve(Int32List data);
}
