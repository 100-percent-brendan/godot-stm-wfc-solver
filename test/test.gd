extends Node2D
## A simple test of the [TiledWFCSolver].
##
## This uses a static seed to aid in debugging the solver.

@onready var tile_map_layer : TileMapLayer = $TileMapLayer ## A Tile Map Layer to place tiles within.

var solver : TiledWFCSolver ## The solver used for debugging.

## Run the solver when the test scene is ready.
func _ready() -> void:
	var input1 = load("res://test/assets/input1.tscn").instantiate()
	solver = TiledWFCSolver.new(load("res://test/assets/terrain.tres"), [input1])
	solver.set_seed(44)
	solver.set_debug_mode(true)
	solver.set_debug_delay(0.002)
	solver.set_dimensions(30, 20)
	solver.tile_placed.connect(_on_tile_placed)
	solver.tile_removed.connect(_on_tile_removed)
	solver.grid_reset.connect(_on_grid_reset)
	var _grid := await solver.run()
	# TODO: Setup code to transpose solution to a tile map layer

## When a tile is placed in the solver, place it on the test [TileMapLayer].
func _on_tile_placed(coords : Vector2i, source_id : int, atlas_coords : Vector2i) -> void:
	tile_map_layer.set_cell(coords, source_id, atlas_coords)

## When a tile is removed in the solver, remove it from the test [TileMapLayer].
func _on_tile_removed(coords : Vector2i) -> void:
	tile_map_layer.set_cell(coords)

## When the grid is reset in the solver, clear the [TileMapLayer].
func _on_grid_reset() -> void:
	tile_map_layer.clear()
