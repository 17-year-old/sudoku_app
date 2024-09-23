import 'package:hive/hive.dart';

import '../../sudoku/core.dart';
import '../../sudoku/native_sudoku_api.g.dart';

class SudokuAdapter extends TypeAdapter<Sudoku> {
  @override
  final typeId = 0;

  @override
  void write(BinaryWriter writer, Sudoku obj) {
    writer.writeInt(obj.level.index);
    writer.writeIntList(obj.puzzle);
    writer.writeIntList(obj.solution);
    writer.writeDouble(obj.difficulty);
  }

  @override
  Sudoku read(BinaryReader reader) {
    var _index = reader.readInt();
    var _puzzle = reader.readIntList();
    var _solution = reader.readIntList();
    var _difficulty = reader.readDouble();
    var reslut = Sudoku(Level.values[_index], _puzzle, _solution);
    reslut.difficulty = _difficulty;
    return reslut;
  }
}
