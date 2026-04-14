# Godot-Based Simple Tiled Model Wave Function Collapse Solver
This repository consists of a Godot 4.X project containing a wave function collapse solver employing the simple tiled model. It also includes a basic test scene for running the solver.

In this context, the wave function collapse solver is used to generate a grid of cells, which can be used to populate a Godot tile map.

## Basic Steps
- Setup:
  - A tile set is input, along with one or several input tile maps
  - Based on the input tile maps, the weights for how likely one tile is to appear next to another tile are determined
- Initialize the Grid
  - Setup an output grid, standing in for a tile map
  - Determine what tiles are valid for each space; all tiles with weights are valid on an empty grid
- Iterate Over Cells
  - Draw the grid cell with the lowest [Shannon entropy](https://en.wikipedia.org/wiki/Entropy_(information_theory)) or, on conflict, the one that is closest to the center
  - Populate that grid cell with a random tile from its valid possibilities; weights are used to determine probabilities; where two neighbors allow different weights for a valid tile, the lower weight of the two is used
  - Propogate the change to its neighbor cells, so that they are adjusted to only allow tiles which are valid when next to the added tile
  - If a cell has no valid tiles and there are valid "neighborhood resets" remaining, clear a 5x5 area around the cell, propogate changes, and reiterate
  - If no solution can be found and there are retries remaining, empty the grid and restart the process from grid initialization, otherwise fail

## Animation
![wfc](https://github.com/user-attachments/assets/8c6a9eb5-ae0d-498d-b049-2d7c76fb862c)

## Running Project
To run this project from the Godot editor, ensure you have [Godot 4.5 or later](https://godotengine.org/), then import the project from within Godot. You can then Run Project from the play button in the upper-right of the editor.

## Goals
My goals with this project were two-fold:
- To learn about how to assemble a basic wave function collapse solver.
- To learn how such a solver could integrate with Godot 4.

## Room for Improvement
This project is only a very basic implementation of the simple tiled model variant of the wave function collapse (WFC) algorithm. It is noted that there are many improvements that could be made, including but not limited to:
- Data structure and memory optimizations
- Speed optimizations
- Solver generalization
- Improved tile layouts
- Layering of multiple inter-connected tile sets
- Integration of noise
- Awareness of Godot terrain mappings
- Rotation of tile patterns to smooth out probabilities
- A multi-threading framework

## Included Enhancement
One notable enhancement within my version of the algorithm is that it uses a local "neighborhood reset", where it clears the area (5x5) around unsolvable spaces to ensure a solution occurs for most solvable tile layouts.

## Artificial Limit
This wave function collapse implementation is artificially limited by its debug delay. To see it operate at close to full speed, comment out the debug delay in the test scene.

## Basis & Supporting Work
The primary basis of the included solver is the original [WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse) constraint solver by Maxim Gumin. His work is further built on earlier works, such as Paul C. Merrell's Model Synthesis, which is further built on Texture Synthesis by Non-parametric Sampling by Alexei A. Efros and Thomas K. Leung. Please see Maxim Gumin's important work for full context on the basis for the algorithm. We stand on the shoulders of giants.
