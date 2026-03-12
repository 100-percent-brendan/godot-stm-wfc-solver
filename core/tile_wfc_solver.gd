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

## The direction used to make a tile comparison.
enum ComparisonDirection {
	LEFT_TO_RIGHT, ## A left-to-right tile comparison.
	TOP_TO_BOTTOM, ## A top-to-bottom tile comparison.
	RIGHT_TO_LEFT, ## A right-to-left tile comparison.
	BOTTOM_TO_TOP ## A bottom-to-top tile comparison.
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
func _get_valid_terrain_tiles() -> Array[Vector2i]:
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

## Get tile data.
##
## This uses the source ID and tile index packaged into a [Vector2i] to get tile data.
func _get_tile_data(tile : Vector2i) -> TileData:
	var source := _terrain_tile_set.get_source(tile.x)
	if source is TileSetAtlasSource:
		# TODO: Investigate second parameter: alternate tile
		var tile_data : TileData = source.get_tile_data(source.get_tile_id(tile.y), 0)
		return tile_data
	
	return null

## Helper function that outputs the [TileSet.CellNeighbor] values on an edge.
##
## This is only intended to be used within internal comparison functions.
## It is guarenteed to return three values.
func _get_tile_set_cell_neighbors(
	is_a : bool, direction : ComparisonDirection
) -> Array[TileSet.CellNeighbor]:
	if (
		(direction == ComparisonDirection.LEFT_TO_RIGHT && is_a) ||\
		(direction == ComparisonDirection.RIGHT_TO_LEFT && !is_a)
	):
		return [
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
		]
	elif (
		(direction == ComparisonDirection.RIGHT_TO_LEFT && is_a) ||\
		(direction == ComparisonDirection.LEFT_TO_RIGHT && !is_a)
	):
		return [
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_LEFT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
		]
	elif (
		(direction == ComparisonDirection.TOP_TO_BOTTOM && is_a) ||\
		(direction == ComparisonDirection.BOTTOM_TO_TOP && !is_a)
	):
		return [
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
		]
	else:
		return [
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
			TileSet.CELL_NEIGHBOR_TOP_SIDE,
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER
		]

## Helper for getting the insection of two arrays.
##
## Order is not guarenteed.
func _get_array_intersection(a : Array, b : Array) -> Array:
	var c : Array = []
	
	if !a || !b:
		return c
	
	for q in a:
		if b.has(q):
			c.push_back(q)
	
	return c
		

## Compare two tiles to see if one can be placed next to another.
##
## This checks to have matching terrain on their facing edges and other
## constraints. The [param direction] is used to determine how the tiles are
## positioned compared to each other.
func _compare_terrain_tiles(
	tile_a : Vector2i, tile_b : Vector2i, direction : ComparisonDirection
) -> bool:
	if !_terrain_tile_set:
		return false
	
	var tile_data_a : TileData = _get_tile_data(tile_a)
	var tile_data_b : TileData = _get_tile_data(tile_b)
	
	## Enforce that terrains must be comparable, then compare the edges
	# TODO: Add validation somewhere to make sure tile set supports the right TerrainMode
	if tile_data_a && tile_data_b && tile_data_a.terrain_set == tile_data_b.terrain_set:
		## Get the cell neighbors, used to compare terrain values
		var a_cell_neighbors : Array[TileSet.CellNeighbor] = _get_tile_set_cell_neighbors(true, direction)
		var b_cell_neighbors : Array[TileSet.CellNeighbor] = _get_tile_set_cell_neighbors(false, direction)
		
		var matches : int = 0
		for i in range(3):
			var bit_a : TileSet.CellNeighbor = a_cell_neighbors[i]
			var bit_b : TileSet.CellNeighbor = b_cell_neighbors[i]
			
			## Ensure the edges have valid terrain bits prior to comparison
			if !tile_data_a.is_valid_terrain_peering_bit(bit_a):
				continue
			if !tile_data_b.is_valid_terrain_peering_bit(bit_b):
				continue
			
			## Compare the terrain bit in the edges to see if they have matching terrain
			if tile_data_a.get_terrain_peering_bit(bit_a) == tile_data_b.get_terrain_peering_bit(bit_b):
				matches += 1
		
		## The edges match
		if matches == 3:
			return true
	
	return false

## Update the terrain possibilities within a space.
##
## Requires a list of valid terrain tiles, the grid, and the coordinates of
## which space is being updated.
func _update_space_possibilities(terrain_tiles : Array[Vector2i], grid : TileWFCGrid, coords : Vector2i) -> void:
	if !terrain_tiles || !grid:
		return
	
	var space := grid.get_space(coords.x, coords.y)
	if !space:
		return
	
	if space.get_status() == TileWFCGridSpace.Status.CLOSED:
		return
	
	## Surrounding spaces are organized top, right, bottom, and then left.
	## Spaces may be null, this will be treated as an empty tile for possibility selection.
	var neighbor_spaces : Array = []
	neighbor_spaces.push_back([
		grid.get_space(coords.x, coords.y - 1),
		ComparisonDirection.BOTTOM_TO_TOP
	])
	neighbor_spaces.push_back(
		[grid.get_space(coords.x + 1, coords.y),
		ComparisonDirection.LEFT_TO_RIGHT
	])
	neighbor_spaces.push_back([
		grid.get_space(coords.x, coords.y + 1),
		ComparisonDirection.TOP_TO_BOTTOM
	])
	neighbor_spaces.push_back([
		grid.get_space(coords.x - 1, coords.y),
		ComparisonDirection.RIGHT_TO_LEFT
	])
	
	var combined_possibility_space : Array[Vector2i] = terrain_tiles.duplicate()
	var possibility_spaces : Array[Array] = []
	
	for neighbor_space in neighbor_spaces:
		var neighbor : TileWFCGridSpace = neighbor_space[0]
		var direction : ComparisonDirection = neighbor_space[1]
		## Don't both making a neighbor possibility space if the space is open or non-existent.
		## All possibilites are valid.
		if !neighbor || neighbor.get_status() == TileWFCGridSpace.Status.OPEN:
			continue
		
		# TODO: Finish this: likely requires adding methods to spaces
		#var current_space : Array[Vector2i]
		#for tile in terrain_tiles:
		#	if _compare_terrain_tiles(space., tile):
	
	print(coords)
	print(neighbor_spaces)

## Initialize grid.
##
## Initialize the [TileWFCGrid] with possibilities.
## Requires a list of valid terrain tiles and the grid.
func _init_grid(terrain_tiles : Array[Vector2i], grid : TileWFCGrid) -> void:
	if !terrain_tiles || terrain_tiles.is_empty():
		_print_debug_message("No terrain tiles available.", DebugSeverity.WARNING)
		return
	
	if !grid:
		_print_debug_message("No grid to initialize.", DebugSeverity.WARNING)
		return
	
	var dimensions = grid.get_dimensions()
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			_update_space_possibilities(terrain_tiles, grid, Vector2i(x, y))

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
	var terrain_tiles := _get_valid_terrain_tiles()
	_init_grid(terrain_tiles, grid)
	
	# TODO: Remove this test
	for i in terrain_tiles:
		var found = 0
		for j in terrain_tiles:
			if _compare_terrain_tiles(i, j, ComparisonDirection.BOTTOM_TO_TOP):
				if i.x == 0 && i.y == 2:
					print(_terrain_tile_set.get_source(j.x).get_tile_id(j.y))
				found += 1
		print("Matches found for ", i, ": ", found)
	print(_terrain_tile_set.get_source(0).get_tile_id(2))
	
	var end_time : int = Time.get_ticks_msec()
	
	# TODO: Did it give up or succeed?
	_print_debug_message(
		String("The solver has finished and has taken " + str(end_time - start_time) + "ms to run."),
		DebugSeverity.INFORMATION
	)
	
	# TODO: Add complexity scoring.
	# TODO: Add difficulty scoring.
	return grid
