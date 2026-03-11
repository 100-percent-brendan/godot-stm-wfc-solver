class_name TileWFCSolver extends Node
## Tile-based wave function collapse (WFC) solver.
##
## When provided with tilesets and a set of parameters, the solver will attempt
## to create a scene that matches applicable constraints using WFC.
##
## Each instance may only be run in one context for one solution at a time.
## Running in multiple loocations may result in corruption.
## Further, running the same instance in multiple threads is considered unsafe.
# TODO: Review this description, and provide usage instructions.
# TODO: Add deferred signal for debug updates.

const MIN_SIZE : int = 6 ## The minimum size of the scene grid in each dimension.

## The debug message severity. 
enum DebugSeverity {
	INFORMATION, ## An informational message.
	WARNING, ## A warning message.
	ERROR ## An error message.
}

# TODO: Consider adding backtracks
var _debug_mode : bool = false ## Output debug messages and information.
var _seed : int = 0 ## The seed used in the pseudorandom number generator (PRNG).
var _dimensions : Vector2i = Vector2i(MIN_SIZE, MIN_SIZE) ## The dimensions of the scene grid.
var _max_retries : int = 100 ## The maximum number of retry attempts.
var _terrain_tile_set : TileSet ## The tileset for the terrain.

## Conditionally output a debug message.
func _print_debug_message(message: String, severity : DebugSeverity) -> void:
	if _debug_mode:
		match severity:
			DebugSeverity.ERROR:
				push_error(message)
			DebugSeverity.WARNING:
				push_error(message)
			_:
				print(message)

## Get all valid possible tiles from the terrain tile set.
##
## Returns an array containing the source ID and tile index as a [Vector2i].
func _get_valid_tiles() -> Array[Vector2i]:
	# TODO: Add check for get_terrain_set_counts.
	if !_terrain_tile_set:
		return []
	
	var _valid_tiles : Array[Vector2i] = []
	for i in range(_terrain_tile_set.get_source_count()):
		var source_id := _terrain_tile_set.get_source_id(i)
		var source := _terrain_tile_set.get_source(source_id)
		
		if source is TileSetAtlasSource:
			for j in range(source.get_tiles_count()):
				# TODO: Add check here to see if tile is included by custom criteria
				_valid_tiles.push_back(Vector2i(source_id, j))
	
	return _valid_tiles

## Configure if the solver will output debug messages and information.
func set_debug_mode(debug_mode : bool) -> void:
	_debug_mode = debug_mode

## Set the seed for the pseudorandom number generator (PRNG).
func set_seed(prng_seed : int) -> void:
	_seed = prng_seed

## Set the dimensions of the scene grid.
##
## Each space represents a tile unit. Must be larger than the minimum size in
## each dimension.
func set_dimensions(width : int, height : int):
	_dimensions = Vector2i(maxi(width, MIN_SIZE), maxi(height, MIN_SIZE))

## Set the maximum number of retry attempts before the solver gives up.
##
## This must be a positive integer.
func set_max_retries(max_retries : int) -> void:
	_max_retries = maxi(max_retries, 1)

## Set the tile set used for terrain.
##
## The tile set is expected to have a single terrain layer, and for all tiles
## to be 1-tile-by-1-tile.
func set_terrain_tile_set(tile_set : TileSet):
	_terrain_tile_set = tile_set

## Check if the solver is ready to be run.
##
## This contains safety checks for starting the solver.
func can_run() -> bool:
	var check_result : bool = true
	
	if _dimensions.x < MIN_SIZE || _dimensions.y < MIN_SIZE:
		_print_debug_message(
			"Scene grid dimensions must be larger than " + str(MIN_SIZE) + ".",
			DebugSeverity.ERROR
		)
		check_result = false
	
	if _max_retries < 1:
		_print_debug_message("Insufficient max retries.", DebugSeverity.ERROR)
		check_result = false
	
	if !_terrain_tile_set:
		_print_debug_message("Terrain tile set must be supplied.", DebugSeverity.ERROR)
		check_result = false
	
	return check_result

# TODO: This probably won't use tile map layers, update the description below.
## Run the tile solver.
##
## Returns the [TileWFCGrid] with or without a solution. Always check the grid
## status to ensure there were no errors.
func run() -> TileWFCGrid:
	var grid := TileWFCGrid.new(_dimensions.x, _dimensions.y)
	
	if !can_run():
		_print_debug_message(
			"The solver could not start due to a failed pre-check.",
			DebugSeverity.ERROR
		)
		grid.set_failed(TileWFCGrid.FailureCause.ERROR)
		return grid
	
	_print_debug_message(
		"The solver has started with seed " + str(_seed) + ".",
		DebugSeverity.INFORMATION
	)
	
	var start_time : int = Time.get_ticks_msec()
	
	var prng := RandomNumberGenerator.new()
	prng.seed = _seed
	
	# TODO: Core logic here.
	var valid_tiles := _get_valid_tiles()
	
	var end_time : int = Time.get_ticks_msec()
	
	# TODO: Did it give up or succeed?
	_print_debug_message(
		String("The solver has finished and has taken " + str(end_time - start_time) + "ms to run."),
		DebugSeverity.INFORMATION
	)
	# TODO: Add more informational return.
	# TODO: Add complexity scoring.
	# TODO: Add difficulty scoring.
	return grid # TODO: Change this
