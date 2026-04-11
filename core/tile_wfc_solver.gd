class_name TiledWFCSolver extends Node
## Simple tiled model wave function collapse (WFC) solver.
##
## This supports square tiles with edge and corner terrain matching.
## This does not suppose alternate tiles.
##
## When provided with tilesets and a set of parameters, the solver will attempt
## to create a scene that matches applicable constraints using WFC.
##
## Each instance may only be run in one context for one solution at a time.
## Running in multiple loocations may result in corruption.
## Further, running the same instance in multiple threads is considered unsafe.
# TODO: Review this description, and provide usage instructions.
# TODO: Check all comments. Any documentation comments should have ##, but others should have #.

## A debugging-only signal for when a tile is placed.
signal tile_placed(coords : Vector2i, source_id : int, atlas_coords : Vector2i)

## A debugging-only signal for when a tile is removed.
signal tile_removed(coords : Vector2i)

## A debugging-only signal for when the grid is reset. 
signal grid_reset()

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

## All valid tile set cell neighbors.
const VALID_TILE_SET_CELL_NEIGHBORS : Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
]

## Tile set cell neighbors for the top edge.
const TILE_SET_TOP_CELL_NEIGHBORS : Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER
]

## Tile set cell neighbors for the right edge.
const TILE_SET_RIGHT_CELL_NEIGHBORS : Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
]

## Tile set cell neighbors for the bottom edge.
const TILE_SET_BOTTOM_CELL_NEIGHBORS : Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
]

## Tile set cell neighbors for the left edge.
const TILE_SET_LEFT_CELL_NEIGHBORS : Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
]


const MIN_SIZE : int = 6 ## The minimum size of the scene grid in each dimension.

# TODO: Consider adding backtracks
var _debug_mode : bool = false ## Output debug messages and information.
var _debug_delay : float = 0.0 ## Delay between tile placements and other major actions.
var _seed : int = 0 ## The seed used in the pseudorandom number generator (PRNG).
var _dimensions : Vector2i = Vector2i(MIN_SIZE, MIN_SIZE) ## The dimensions of the scene grid.
var _max_retries : int = 100 ## The maximum number of retry attempts.
var _terrain_tile_set : TileSet ## The tileset for the terrain.
var _neighbor_counts : Dictionary ## The neighbor counts used for adjacency constraints and probabilities.

## Initialize the wave function collapse solver.
##
## The [param tile_set] is expected to have a single terrain layer, and for all tiles
## to be one-tile-by-one-tile.
##
## The [param input_maps] are expected to contain examples of tile maps used to
## configure pattern probabilities.
func _init(tile_set : TileSet, input_maps : Array[TileMapLayer]) -> void:
	_terrain_tile_set = tile_set
	# TODO: Verify terrain elements here
	_process_input_maps(input_maps)

## Process the input maps.
##
## The [param input_maps] are expected to contain examples of tile maps which are
## used to extract pattern probabilities.
func _process_input_maps(input_maps : Array[TileMapLayer]) -> void:
	_neighbor_counts = {}
	
	# Interate over cells and check neighbors for adjacency
	# Add one to probabilities for each neighbor seen
	# Ignore empty cells
	for map in input_maps:
		# Ensure tile set matches
		if !map.tile_set || map.tile_set != _terrain_tile_set:
			continue
		
		for cell in map.get_used_cells():
			var source_id = map.get_cell_source_id(cell)
			var atlas_coords = map.get_cell_atlas_coords(cell)
			var source = map.tile_set.get_source(source_id)
			if source is TileSetAtlasSource:
				var unique_id : Vector3i = Vector3i(source_id, atlas_coords.x, atlas_coords.y)
				if !_neighbor_counts.has(unique_id):
					_neighbor_counts[unique_id] = {"neighbors": {}}
				
				## Surrounding cells are organized top, right, bottom, and then left.
				var neighbor_cells : Array = []
				neighbor_cells.push_back([
					Vector2i(cell.x, cell.y - 1), ComparisonDirection.BOTTOM_TO_TOP
				])
				neighbor_cells.push_back([
					Vector2i(cell.x + 1, cell.y), ComparisonDirection.LEFT_TO_RIGHT
				])
				neighbor_cells.push_back([
					Vector2i(cell.x, cell.y + 1), ComparisonDirection.TOP_TO_BOTTOM
				])
				neighbor_cells.push_back([
					Vector2i(cell.x - 1, cell.y), ComparisonDirection.RIGHT_TO_LEFT
				])
				
				for neighbor in neighbor_cells:
					var neighbor_source_id = map.get_cell_source_id(neighbor[0])
					var neighbor_atlas_coords = map.get_cell_atlas_coords(neighbor[0])
					if neighbor_source_id == -1:
						continue
					
					var neighbor_tile : Vector3i = Vector3i(
						neighbor_source_id, neighbor_atlas_coords.x, neighbor_atlas_coords.y
					)
					
					if !_neighbor_counts[unique_id].neighbors.has(neighbor[1]):
						_neighbor_counts[unique_id].neighbors[neighbor[1]] = {}
					
					if !_neighbor_counts[unique_id].neighbors[neighbor[1]].has(neighbor_tile):
						_neighbor_counts[unique_id].neighbors[neighbor[1]][neighbor_tile] = 0
					
					_neighbor_counts[unique_id].neighbors[neighbor[1]][neighbor_tile] += 1

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
## Returns an array containing the source ID and atlas coordinates as a [Vector3i].
func _get_valid_terrain_tiles() -> Array[Vector3i]:
	# TODO: Add check for get_terrain_set_counts.
	if !_terrain_tile_set:
		return []
	
	var _valid_tiles : Array[Vector3i] = []
	for i in range(_terrain_tile_set.get_source_count()):
		var source_id := _terrain_tile_set.get_source_id(i)
		var source := _terrain_tile_set.get_source(source_id)
		
		if source is TileSetAtlasSource:
			for j in range(source.get_tiles_count()):
				# TODO: Add check here to see if tile is included by custom criteria
				var atlas_coords = source.get_tile_id(j)
				_valid_tiles.push_back(Vector3i(source_id, atlas_coords.x, atlas_coords.y))
	
	return _valid_tiles

## Get tile data.
##
## This uses the source ID and tile index packaged into a [Vector2i] to get tile data.
func _get_tile_data(tile : Vector3i) -> TileData:
	var source := _terrain_tile_set.get_source(tile.x)
	if source is TileSetAtlasSource:
		## Alterrnative tiles are not supported, so the second parameter is 0
		var tile_data : TileData = source.get_tile_data(Vector2i(tile.y, tile.z), 0)
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
		return TILE_SET_RIGHT_CELL_NEIGHBORS
	elif (
		(direction == ComparisonDirection.RIGHT_TO_LEFT && is_a) ||\
		(direction == ComparisonDirection.LEFT_TO_RIGHT && !is_a)
	):
		return TILE_SET_LEFT_CELL_NEIGHBORS
	elif (
		(direction == ComparisonDirection.TOP_TO_BOTTOM && is_a) ||\
		(direction == ComparisonDirection.BOTTOM_TO_TOP && !is_a)
	):
		return TILE_SET_BOTTOM_CELL_NEIGHBORS
	else:
		return TILE_SET_TOP_CELL_NEIGHBORS

## Helper for getting the insection of two Vector2i arrays.
##
## Order is not guarenteed.
func _get_vector3i_array_intersection(a : Array[Vector3i], b : Array[Vector3i]) -> Array[Vector3i]:
	var c : Array[Vector3i] = []
	
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
	tile_a : Vector3i, tile_b : Vector3i, direction : ComparisonDirection
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

## Update the terrain possibilities within a cell.
##
## Requires a list of valid terrain tiles, the grid, and the coordinates of
## which cell is being updated.
func _update_cell_possibilities(terrain_tiles : Array[Vector3i], grid : WFCGrid, coords : Vector2i) -> void:
	if !terrain_tiles || !grid:
		return
	
	var cell := grid.get_cell(coords.x, coords.y)
	if !cell:
		return
	
	if cell.get_status() == WFCCell.Status.CLOSED:
		return
	
	## Surrounding cells are organized top, right, bottom, and then left.
	## Cells may be null, this will be treated as an empty tile for possibility selection.
	var neighbor_cells : Array = []
	neighbor_cells.push_back([
		grid.get_cell(coords.x, coords.y - 1),
		ComparisonDirection.BOTTOM_TO_TOP
	])
	neighbor_cells.push_back([
		grid.get_cell(coords.x + 1, coords.y),
		ComparisonDirection.LEFT_TO_RIGHT
	])
	neighbor_cells.push_back([
		grid.get_cell(coords.x, coords.y + 1),
		ComparisonDirection.TOP_TO_BOTTOM
	])
	neighbor_cells.push_back([
		grid.get_cell(coords.x - 1, coords.y),
		ComparisonDirection.RIGHT_TO_LEFT
	])
	
	var combined_possibilities : Array[Vector3i] = terrain_tiles.duplicate()
	var possibility_spaces : Array[Array] = []
	
	for neighbor_cell in neighbor_cells:
		var neighbor : WFCCell = neighbor_cell[0]
		var direction : ComparisonDirection = neighbor_cell[1]
		## Don't both making a neighbor possibility space if the cell is open or non-existent.
		## All possibilites are valid.
		if !neighbor || neighbor.get_status() == WFCCell.Status.OPEN:
			continue
		
		# TODO: Optimize: Move building this to a central step and tile-specific index
		var possibilities : Array[Vector3i]
		for tile in terrain_tiles:
			if _compare_terrain_tiles(tile, neighbor.get_tile(), direction):
				possibilities.push_back(tile)
		possibility_spaces.push_back(possibilities)
	
	for possibilities in possibility_spaces:
		combined_possibilities = _get_vector3i_array_intersection(combined_possibilities, possibilities)
	
	cell.clear_possibilities()
	for tile in combined_possibilities:
		cell.add_possibility(tile)

## Place or remove a tile from a cell.
##
## This updates the cell possibilities of this tile and all surrounding tiles,
## if relevant.
## Requires a list of valid terrain tiles, the grid, the coordinates of
## which cell is being changed, and the tile its being changed to (or the remove flag).
func _place_tile(
	terrain_tiles : Array[Vector3i], grid : WFCGrid, coords : Vector2i,
	tile : Vector3i, remove_tile : bool = false
) -> void:
	if !terrain_tiles || !grid:
		return
	
	var cell : WFCCell = grid.get_cell(coords.x, coords.y)
	if !cell:
		return
	
	if remove_tile:
		cell.open()
		_update_cell_possibilities(terrain_tiles, grid, coords)
		if _debug_mode:
			tile_removed.emit(coords)
	else:
		cell.place_tile(tile)
		if _debug_mode:
			var source := _terrain_tile_set.get_source(tile.x)
			if source is TileSetAtlasSource:
				tile_placed.emit(coords, tile.x, Vector2i(tile.y, tile.z))
	
	## Surrounding cells are organized top, right, bottom, and then left.
	var neighbor_coords : Array[Vector2i] = []
	neighbor_coords.push_back(Vector2i(coords.x, coords.y - 1))
	neighbor_coords.push_back(Vector2i(coords.x + 1, coords.y))
	neighbor_coords.push_back(Vector2i(coords.x, coords.y + 1))
	neighbor_coords.push_back(Vector2i(coords.x - 1, coords.y))
	
	## Update all the surrounding cell possibilities
	for neighbor in neighbor_coords:
		## This will ignore null cells
		_update_cell_possibilities(terrain_tiles, grid, neighbor)

## Place a random tile in a cell.
##
## This updates the cell possibilities of this tile and all surrounding tiles,
## if relevant.
## Requires a list of valid terrain tiles, the pseudorandom number generator,
## the grid, and the coordinates of which cell is being changed.
##
## If was able to roll to place a tile, will return true, otherwise false.
func _place_random_tile(
	terrain_tiles : Array[Vector3i], prng : RandomNumberGenerator, grid : WFCGrid, coords : Vector2i
) -> bool:
	# TODO: Upgrade this to take into account tile probabilities
	
	if terrain_tiles.size() < 1:
		return false
	
	var cell : WFCCell = grid.get_cell(coords.x, coords.y)
	if !cell:
		return false
	
	var possibilities := cell.get_possibilities()
	
	if possibilities.size() < 1:
		return false
	
	## Each probability prospect has a weight and a tile.
	var probabilities : Array[Array] = [] # ------------------------------------------------------------------------------------------------------- HERE
	var total_weight : float = 0.0
	for tile in possibilities:
		var tile_data : TileData = _get_tile_data(tile)
		var weight : float
		
		## Get base probability weight from tile data itself
		if tile_data && tile_data.probability > 0.0:
			weight = tile_data.probability
		else:
			continue
			
		probabilities.push_back([weight, tile])
		total_weight += weight
	
	if total_weight <= 0.0:
		return false
	
	var roll := prng.randf() * total_weight
	for prospect in probabilities:
		if roll <= prospect[0]:
			_place_tile(terrain_tiles, grid, coords, prospect[1])
			return true
		
		roll -= prospect[0]
	
	return false

## Remove a tile from a cell.
##
## This updates the cell possibilities of this tile and all surrounding tiles,
## if relevant.
## Requires a list of valid terrain tiles, the grid, and the coordinates of
## the cell where the tile is being removed.
func _remove_tile(
	terrain_tiles : Array[Vector3i], grid : WFCGrid, coords : Vector2i
) -> void:
	_place_tile(terrain_tiles, grid, coords, Vector3i(), true)

## Initialize grid.
##
## Initialize the [WFCGrid] with possibilities.
## Requires a list of valid terrain tiles and the grid.
func _init_grid(terrain_tiles : Array[Vector3i], grid : WFCGrid) -> void:
	if !terrain_tiles || terrain_tiles.is_empty():
		_print_debug_message("No terrain tiles available.", DebugSeverity.WARNING)
		return
	
	if !grid:
		_print_debug_message("No grid to initialize.", DebugSeverity.WARNING)
		return
	
	var dimensions = grid.get_dimensions()
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			_update_cell_possibilities(terrain_tiles, grid, Vector2i(x, y))

## Sort cells left.
##
## This is a helper function that sorts the cells left array first by entropy
## (to choose the lowest entropy cell) and then by distance from the center.
##
## The general idea is that by starting in the center, and working on the
## lowest entropy cells, the algorithm can: stop as soon as it detects an
## unsolvable state and avoid solving edge pieces first, which are more likely to
## have more options near the end.
##
## This expects an Array[Array] which each array contains a Vector2i (cell
## coordinates) and a [WFCCell].
func _sort_cells_left(cells_left : Array) -> void:
	cells_left.sort_custom(_compare_cells_left)

## Compare cells for the custom sort in [code]_sort_cells_left()[/code].
func _compare_cells_left(a, b):
	if a[1].get_entropy() == b[1].get_entropy():
		return a[0].distance_to(_dimensions/2.0) < b[0].distance_to(_dimensions/2.0)
	# TODO: Make this into true Shannon entropy
	return a[1].get_entropy() < b[1].get_entropy()

## Configure if the solver will output debug messages and information.
func set_debug_mode(debug_mode : bool) -> void:
	_debug_mode = debug_mode

## Set the amount of time between major actions, such as tile placements, when debugging.
func set_debug_delay(delay : float) -> void:
	_debug_delay = max(delay, 0.0)

## Set the seed for the pseudorandom number generator (PRNG).
func set_seed(prng_seed : int) -> void:
	_seed = prng_seed

## Set the dimensions of the scene grid.
##
## Each cell represents a tile unit. Must be larger than the minimum size in
## each dimension.
func set_dimensions(width : int, height : int):
	_dimensions = Vector2i(maxi(width, MIN_SIZE), maxi(height, MIN_SIZE))

## Set the maximum number of retry attempts before the solver gives up.
##
## This must be a positive integer.
func set_max_retries(max_retries : int) -> void:
	_max_retries = maxi(max_retries, 1)

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
## Returns the [WFCGrid] with or without a solution. Always check the grid
## status to ensure there were no errors.
func run() -> WFCGrid:
	if !can_run():
		_print_debug_message(
			"The solver could not start due to a failed pre-check.",
			DebugSeverity.ERROR
		)
		var error_grid := WFCGrid.new(0, 0)
		error_grid.set_failed(WFCGrid.FailureCause.ERROR)
		return error_grid
	
	_print_debug_message(
		"The solver has started with seed " + str(_seed) + ".",
		DebugSeverity.INFORMATION
	)
	
	var prng := RandomNumberGenerator.new()
	prng.seed = _seed
	
	var start_time : int = Time.get_ticks_msec() ## When the process started
	var retry : int = 0 ## The current retry
	
	var terrain_tiles := _get_valid_terrain_tiles()
	var grid := WFCGrid.new(_dimensions.x, _dimensions.y)
	_init_grid(terrain_tiles, grid)
	
	while true:
		var has_no_solution : bool = false ## If the current solution state is unsolvable
		
		## Cells, partnered with their coordinates
		var cells_left : Array = []
		var grid_dims := grid.get_dimensions()
		for y in grid_dims.y:
			for x in grid_dims.x:
				cells_left.push_back([Vector2i(x, y), grid.get_cell(x, y)])
		
		while cells_left.size() > 0:
			if _debug_mode && _debug_delay > 0.0:
				await Engine.get_main_loop().create_timer(_debug_delay).timeout
			_sort_cells_left(cells_left)
			var current_cell = cells_left.pop_front()
			if current_cell[1].get_entropy() > 0:
				_place_random_tile(terrain_tiles, prng, grid, current_cell[0])
			else:
				has_no_solution = true
				break
		
		if has_no_solution && retry < _max_retries:
			if _debug_mode && _debug_delay > 0.0:
				await Engine.get_main_loop().create_timer(_debug_delay).timeout
			retry += 1
			_print_debug_message(
				"No solution found. Restarting on retry " + str(retry) + ".",
				DebugSeverity.INFORMATION
			)
			grid = WFCGrid.new(_dimensions.x, _dimensions.y)
			_init_grid(terrain_tiles, grid)
			if _debug_mode:
				grid_reset.emit()
			continue
		elif has_no_solution:
			grid.set_failed(WFCGrid.FailureCause.NO_SOLUTION)
			_print_debug_message(
				"No solution found. Retries exhausted.",
				DebugSeverity.INFORMATION
			)
			break
		else:
			_print_debug_message(
				"Solution found.",
				DebugSeverity.INFORMATION
			)
			grid.set_solved()
			break
			
	
	var end_time : int = Time.get_ticks_msec() ## When the process ended
	
	# TODO: Did it give up or succeed?
	_print_debug_message(
		String("The solver has finished and has taken " + str(end_time - start_time) + "ms to run."),
		DebugSeverity.INFORMATION
	)
	
	# TODO: Add complexity scoring.
	# TODO: Add difficulty scoring.
	return grid
