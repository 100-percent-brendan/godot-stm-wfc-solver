# Godot-Based Simple Tiled Model Wave Function Collapse Solver
This repository consists of a Godot 4.X project containing a wave function collapse solver employing the simple tiled model. It also includes a basic test scene for running the solver.

## Running Project
To run this project from the Godot editor, ensure you have [Godot 4.5 or later](https://godotengine.org/), then import the project from within the loader. You can then Run Project from the play button in the upper-right of the editor.

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
- A multi-threading framework

## Included Enhancement
One notable enhancement within my version of the algorithm, is that it uses a local neighborhood reset, where it clears the area (5x5) around unsolvable spaces to ensure a solution occurs for most solvable tile layouts.

## Basis & Supporting Work
The primary basis of the included solver is the original [WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse) constraint solver by Maxim Gumin. His work is further built on earlier works, such as Paul C. Merrell's Model Synthesis, which is further built on Texture Synthesis by Non-parametric Sampling by Alexei A. Efros and Thomas K. Leung. Please see Maxim Gumin's important work for full context on the basis for the algorithm. We stand on the shoulders of giants.
