extends Node2D
# @TODO Add documentation

@onready var tile_map_layer : TileMapLayer = $TileMapLayer

var solver : TileWFCSolver

func _ready() -> void:
	solver = TileWFCSolver.new()
	solver.set_seed(44)
	solver.set_terrain_tile_set(load("res://test/assets/terrain.tres"))
	solver.set_debug_mode(true)
	solver.set_debug_delay(0.03)
	solver.set_dimensions(30, 20)
	solver.tile_placed.connect(_on_tile_placed)
	solver.tile_removed.connect(_on_tile_removed)
	solver.grid_reset.connect(_on_grid_reset)
	var _grid := await solver.run()
	# TODO: Setup code to transpose solution to a tile map layer

func _on_tile_placed(coords : Vector2i, source_id : int, atlas_coords : Vector2i) -> void:
	tile_map_layer.set_cell(coords, source_id, atlas_coords)

func _on_tile_removed(coords : Vector2i) -> void:
	tile_map_layer.set_cell(coords)

func _on_grid_reset() -> void:
	tile_map_layer.clear()
