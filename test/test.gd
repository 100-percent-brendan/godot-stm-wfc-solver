extends Node2D
## A simple test of the [TiledWFCSolver].
##
## This uses an incrementing seed to aid in debugging the solver, as well as
## demonstration.

@onready var tile_map_layer : TileMapLayer = $TileMapLayer ## A Tile Map Layer to place tiles within.

var solver : TiledWFCSolver ## The solver used for debugging.

## Run the solver when the test scene is ready.
func _ready() -> void:
	for i in range(100):
		var input1 = load("res://test/assets/input1.tscn").instantiate()
		var input2 = load("res://test/assets/input2.tscn").instantiate()
		solver = TiledWFCSolver.new(load("res://test/assets/terrain.tres"), [input1, input2])
		solver.set_seed(i)
		solver.set_debug_mode(true)
		solver.set_debug_delay(0.002)
		solver.set_dimensions(30, 20)
		solver.tile_placed.connect(_on_tile_placed)
		solver.tile_removed.connect(_on_tile_removed)
		solver.grid_reset.connect(_on_grid_reset)
		
		var _grid := await solver.run()
		
		# Wait 3 seconds after success
		await get_tree().create_timer(3.0).timeout
		
		# Clear tiles between runs
		tile_map_layer.clear()

## When a tile is placed in the solver, place it on the test [TileMapLayer].
func _on_tile_placed(coords : Vector2i, source_id : int, atlas_coords : Vector2i) -> void:
	tile_map_layer.set_cell(coords, source_id, atlas_coords)

## When a tile is removed in the solver, remove it from the test [TileMapLayer].
func _on_tile_removed(coords : Vector2i) -> void:
	tile_map_layer.set_cell(coords)

## When the grid is reset in the solver, clear the [TileMapLayer].
func _on_grid_reset() -> void:
	tile_map_layer.clear()
