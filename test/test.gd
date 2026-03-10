extends Node2D

var solver : TileWFCSolver

func _ready() -> void:
	solver = TileWFCSolver.new()
	solver.set_terrain_tile_set(load("res://test/assets/terrain.tres"))
	solver.set_debug_mode(true)
	solver.run()
