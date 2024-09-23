package com.fubailin.sudoku;

import diuf.sudoku.Cell;
import diuf.sudoku.Grid;
import diuf.sudoku.Link;
import diuf.sudoku.generator.Generator;
import diuf.sudoku.generator.Symmetry;
import diuf.sudoku.solver.DirectHint;
import diuf.sudoku.solver.Hint;
import diuf.sudoku.solver.IndirectHint;
import diuf.sudoku.solver.Solver;
import diuf.sudoku.solver.checks.BruteForceAnalysis;
import diuf.sudoku.solver.checks.DoubleSolutionWarning;
import diuf.sudoku.solver.rules.chaining.ChainingHint;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

import java.util.*;

public class SudokuApiImpl implements FlutterPlugin, SudokuApi.NativeSudokuApi {

    @Override
    public void generate(SudokuApi.Level level, SudokuApi.Result<int[]> result) {
        double minDifficulty = 0;
        double maxDifficulty = 0;
        double includeDifficulty1 = 0;
        double includeDifficulty2 = 0;
        double includeDifficulty3 = 0;
        double excludeDifficulty1 = 0;
        double excludeDifficulty2 = 0;
        double excludeDifficulty3 = 0;
        double notMaxDifficulty1 = 0;
        double notMaxDifficulty2 = 0;
        double notMaxDifficulty3 = 0;
        String excludeTechnique1 = "";
        String excludeTechnique2 = "";
        String excludeTechnique3 = "";
        String includeTechnique1 = "";
        String includeTechnique2 = "";
        String includeTechnique3 = "";
        String notMaxTechnique1 = "";
        String notMaxTechnique2 = "";
        String notMaxTechnique3 = "";
        String getOneOfThree_1 = "";
        String getOneOfThree_2 = "";
        String getOneOfThree_3 = "";

        if (level == SudokuApi.Level.EASY) { //简单
            minDifficulty = 1.0;
            maxDifficulty = 2.0;
        } else if (level == SudokuApi.Level.MEDIUM) {//中等
            minDifficulty = 2.1;
            maxDifficulty = 3.5;
        } else if (level == SudokuApi.Level.HARD) {//困难
            minDifficulty = 3.6;
            maxDifficulty = 7.0;
        } else if (level == SudokuApi.Level.EXPERT) {//专家
            minDifficulty = 7.1;
            maxDifficulty = 100;
        }

        List<Symmetry> symmetries = new ArrayList<>();
        symmetries.add(Symmetry.Orthogonal);
        symmetries.add(Symmetry.BiDiagonal);
        symmetries.add(Symmetry.Rotational180);
        symmetries.add(Symmetry.Rotational90);
        symmetries.add(Symmetry.Full);
        symmetries.add(Symmetry.Full32);

        Generator generator = new Generator();
        Grid grid = generator.generate(symmetries, minDifficulty, maxDifficulty, includeDifficulty1, includeDifficulty2, includeDifficulty3, excludeDifficulty1, excludeDifficulty2, excludeDifficulty3, notMaxDifficulty1, notMaxDifficulty2, notMaxDifficulty3, excludeTechnique1, excludeTechnique2, excludeTechnique3, includeTechnique1, includeTechnique2, includeTechnique3, notMaxTechnique1, notMaxTechnique2, notMaxTechnique3, getOneOfThree_1, getOneOfThree_2, getOneOfThree_3);
        int[] ret = new int[81];
        for (int i = 0; i < 81; i++) {
            ret[i] = grid.getCellValue(i);
        }

        result.success(ret);
    }

    @Override
    public void difficulty(int[] data, SudokuApi.Result<Double> result) {
        Grid grid = new Grid();
        for (int i = 0; i < 81; i++) {
            grid.setCellValue(i, data[i]);
        }
        Solver solver = new Solver(grid);
        solver.rebuildPotentialValues();
        solver.getDifficulty();
        result.success(solver.difficulty);
    }

    @Override
    public void analyse(int[] data, int[] PotentialValues, SudokuApi.Result<String> result) {
        Grid grid = new Grid();
        for (int i = 0; i < 81; i++) {
            grid.setCellValue(i, data[i]);
        }
        Solver solver = new Solver(grid);
        if (PotentialValues.length == 0) {
            solver.rebuildPotentialValues();
        } else {
            for (int i = 0; i < 729; i++) {
                int cl = i / 9;  // cell
                if (PotentialValues[i] >= 1 && PotentialValues[i] <= 9) {
                    grid.addCellPotentialValue(cl, PotentialValues[i]);
                }
            }
            solver.cancelPotentialValues();
        }
        result.success(solver.analyse(null).toHtml(grid));
    }

    @Override
    public void checkValidity(int[] data, SudokuApi.Result<Long> result) {
        long ret;
        Grid grid = new Grid();
        for (int i = 0; i < 81; i++) {
            grid.setCellValue(i, data[i]);
        }
        Solver solver = new Solver(grid);
        solver.rebuildPotentialValues();
        Hint hint = solver.checkValidity();
        if (hint == null) {
            ret = 1;
        } else {
            if (hint instanceof DoubleSolutionWarning) {
                ret = 2;
            } else {
                ret = 0;
            }
        }
        result.success(ret);
    }

    @Override
    public void getDirectHint(int[] data, SudokuApi.NullableResult<SudokuApi.DirectHint> result) {
        Grid grid = new Grid();
        for (int i = 0; i < 81; i++) {
            grid.setCellValue(i, data[i]);
        }

        Solver solver = new Solver(grid);
        solver.rebuildPotentialValues();
        diuf.sudoku.solver.Hint singleHint = solver.getSingleHint();
        if (singleHint instanceof IndirectHint) {
            result.success(null);
        } else {
            Grid.Region[] regions = singleHint.getRegions();
            List<SudokuApi.Region> regionList = new ArrayList<>();
            if (regions != null) {
                for (Grid.Region r : regions) {
                    if (r != null) {
                        SudokuApi.Region apiRegion = new SudokuApi.Region();
                        apiRegion.setRegionType((long) r.getRegionTypeIndex());
                        apiRegion.setRegionIndex((long) r.getRegionIndex());
                        regionList.add(apiRegion);
                    }
                }
            }

            SudokuApi.DirectHint ret = new SudokuApi.DirectHint.Builder()  //
                    .setCellIndex((long) singleHint.getCell().getIndex())  //
                    .setCellValue((long) singleHint.getValue()) //
                    .setRegions(regionList)//
                    .setHintMessage(singleHint.toHtml(grid)).build();
            result.success(ret);
        }
    }

    @Override
    public void getIndirectHint(int[] data, int[] PotentialValues, SudokuApi.NullableResult<SudokuApi.IndirectHint> result) {
        Grid grid = new Grid();
        for (int i = 0; i < 81; i++) {
            grid.setCellValue(i, data[i]);
        }
        for (int i = 0; i < 729; i++) {
            int cl = i / 9;  // cell
            if (PotentialValues[i] >= 1 && PotentialValues[i] <= 9) {
                grid.addCellPotentialValue(cl, PotentialValues[i]);
            }
        }

        Solver solver = new Solver(grid);
        solver.cancelPotentialValues();
        diuf.sudoku.solver.Hint singleHint = solver.getSingleHint();
        if (singleHint instanceof DirectHint) {
            Grid.Region[] regions = singleHint.getRegions();
            List<SudokuApi.Region> regionList = new ArrayList<>();
            if (regions != null) {
                for (Grid.Region r : regions) {
                    if (r != null) {
                        SudokuApi.Region apiRegion = new SudokuApi.Region();
                        apiRegion.setRegionType((long) r.getRegionTypeIndex());
                        apiRegion.setRegionIndex((long) r.getRegionIndex());
                        regionList.add(apiRegion);
                    }
                }
            }

            SudokuApi.IndirectHint ret = new SudokuApi.IndirectHint.Builder()//
                    .setCellIndex((long) singleHint.getCell().getIndex())//
                    .setCellValue((long) singleHint.getValue())//
                    .setRegions(regionList)//
                    .setHintMessage(singleHint.toHtml(grid)).build();
            result.success(ret);
        } else {
            diuf.sudoku.solver.IndirectHint indirectHint;
            do {
                indirectHint = (diuf.sudoku.solver.IndirectHint) singleHint;
                singleHint = solver.getSingleHint();
            } while (!indirectHint.isWorth());

            Grid.Region[] region = singleHint.getRegions();
            List<SudokuApi.Region> regionList = new ArrayList<>();
            if (region != null) {
                for (Grid.Region r : region) {
                    SudokuApi.Region apiRegion = new SudokuApi.Region();
                    apiRegion.setRegionType((long) r.getRegionTypeIndex());
                    apiRegion.setRegionIndex((long) r.getRegionIndex());
                    regionList.add(apiRegion);
                }
            }

            Map<Long, Object> removable = new TreeMap<Long, Object>();
            Map<Cell, BitSet> removablePotentials = indirectHint.getRemovablePotentials();
            for (Map.Entry<Cell, BitSet> entry : removablePotentials.entrySet()) {
                Cell cell = entry.getKey();
                BitSet value = entry.getValue();
                List<Long> temp = new ArrayList<>();
                for (int i = 1; i <= 9; i++) {
                    if (value.get(i)) {
                        temp.add((long) i);
                    }
                }
                removable.put((long) cell.getIndex(), temp);
            }

            Map<Long, Object> red = new TreeMap<Long, Object>();
            try {
                Map<Cell, BitSet> redPotentials = indirectHint.getRedPotentials(grid, 0);
                if (redPotentials != null) {
                    for (Map.Entry<Cell, BitSet> entry : redPotentials.entrySet()) {
                        Cell cell = entry.getKey();
                        BitSet value = entry.getValue();
                        List<Long> temp = new ArrayList<>();
                        for (int i = 1; i <= 9; i++) {
                            if (value.get(i)) {
                                temp.add((long) i);
                            }
                        }
                        red.put((long) cell.getIndex(), temp);
                    }
                }
            } catch (Exception ignored) {
            }

            Map<Long, Object> green = new TreeMap<Long, Object>();
            try {
                Map<Cell, BitSet> greenPotentials = indirectHint.getGreenPotentials(grid, 0);
                if (greenPotentials != null) {
                    for (Map.Entry<Cell, BitSet> entry : greenPotentials.entrySet()) {
                        Cell cell = entry.getKey();
                        BitSet value = entry.getValue();
                        List<Long> temp = new ArrayList<>();
                        for (int i = 1; i <= 9; i++) {
                            if (value.get(i)) {
                                temp.add((long) i);
                            }
                        }
                        green.put((long) cell.getIndex(), temp);
                    }
                }
            } catch (Exception ignored) {
            }

            List<SudokuApi.Link> linkList = new ArrayList<>();
            try {
                Collection<Link> linkCollection = indirectHint.getLinks(grid, 0);
                if (linkCollection != null) {
                    for (Link link : linkCollection) {
                        SudokuApi.Link temp = new SudokuApi.Link();
                        temp.setSrcCellIndex((long) link.getSrcCell().getIndex());
                        temp.setSrcCellValue((long) link.getSrcValue());
                        temp.setDstCellIndex((long) link.getDstCell().getIndex());
                        temp.setDstCellValue((long) link.getDstValue());

                        linkList.add(temp);
                    }
                }
            } catch (Exception ignored) {
            }

            long cellIndex = -1;
            long cellValue = 0;
            if (indirectHint.getCell() != null) {
                cellIndex = indirectHint.getCell().getIndex();
                cellValue = indirectHint.getValue();
            }

            List<Long> selectedCells = new ArrayList<>();
            Cell[] temp = indirectHint.getSelectedCells();
            for (Cell cell : temp) {
                if(cell != null) {
                    selectedCells.add((long) cell.getIndex());
                }
            }

            SudokuApi.IndirectHint ret = new SudokuApi.IndirectHint.Builder()//
                    .setCellIndex(cellIndex) //
                    .setCellValue(cellValue)//
                    .setRegions(regionList)//
                    .setSelectedCells(selectedCells).setRemovablePotentials(removable)//
                    .setRedPotentials(red)//
                    .setGreenPotentials(green)//
                    .setLinks(linkList)//
                    .setHintMessage(indirectHint.toHtml(grid)).build();
            result.success(ret);
        }
    }

    @Override
    public void solve(int[] data, SudokuApi.Result<int[]> result) {
        Grid grid = new Grid();
        for (int i = 0; i < 81; i++) {
            grid.setCellValue(i, data[i]);
        }
        Solver solver = new Solver(grid);
        solver.rebuildPotentialValues();
        BruteForceAnalysis analyser = new BruteForceAnalysis(true);
        analyser.analyse(grid, false);
        int[] ret = new int[81];
        for (int i = 0; i < 81; i++) {
            ret[i] = grid.getCellValue(i);
        }
        result.success(ret);
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        SudokuApi.NativeSudokuApi.setUp(binding.getBinaryMessenger(), this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        SudokuApi.NativeSudokuApi.setUp(binding.getBinaryMessenger(), null);
    }

}
