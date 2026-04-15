class_name TiledWFCSolver extends Node
## Simple tiled model wave function collapse (WFC) solver.
##
## When provided with tilesets, at least one input map (TileMapLayer), and a
## set of parameters, the solver will attempt to create a tile layout that emulates
## the input.
##
## After this is run, it will output a [WFCGrid]. This grid indicates whether or
## not generation was successful. When successful, it includes cells that can be
## mapped back to the [TileSet] originally supplied. It can be used directly
## to place tiles on a [TileMapLayer].
##
## This was not designed to be thread safe.

## A signal for when a tile is placed.
signal tile_placed(coords : Vector2i, source_id : int, atlas_coords : Vector2i)

## A signal for when a tile is removed.
signal tile_removed(coords : Vector2i)

## A signal for when tile possibilities are updated.
signal tile_possibilities_updated(coords : Vector2i, count : int, entropy : float)

## A signal for when the grid is reset. 
signal grid_reset()

## The debug message severity.
enum DebugSeverity {
	INFORMATION, ## An informational message.
	WARNING, ## A warning message.
	ERROR ## An error message.
}

## The direction used for tile comparison.
enum ComparisonDirection {
	LEFT_TO_RIGHT, ## A left-to-right tile comparison.
	TOP_TO_BOTTOM, ## A top-to-bottom tile comparison.
	RIGHT_TO_LEFT, ## A right-to-left tile comparison.
	BOTTOM_TO_TOP ## A bottom-to-top tile comparison.
}

const MIN_SIZE : int = 6 ## The minimum size of the output grid in each dimension.

var _debug_mode : bool = false ## Output debug messages and information.
var _debug_delay : float = 0.0 ## Delay between tile placements and other major actions.
var _seed : int = 0 ## The seed used in the pseudorandom number generator (PRNG).
var _dimensions : Vector2i = Vector2i(MIN_SIZE, MIN_SIZE) ## The dimensions of the output grid.
var _max_retries : int = 100 ## The maximum number of retry attempts.
var _max_local_resets : int = 100 ## The maximum number of local resets.
var _tile_set : TileSet ## The tileset.
var _neighbor_counts : Dictionary ## The neighbor counts used for adjacency constraints and probabilities.
var _valid_tiles : Array[Vector3i] ## A list of all valid tiles from the tile set.

## Initialize the wave function collapse solver.
##
## The [param tile_set] is expected for all tiles to be one-tile-by-one-tile in size.
##
## The [param input_maps] are expected to contain examples of tile maps. These
## are used to configure adjacency constraints and probabilities.
func _init(tile_set : TileSet, input_maps : Array[TileMapLayer]) -> void:
	_tile_set = tile_set
	_process_input_maps(input_maps)
	_valid_tiles = _get_valid_tiles()

## Process the input maps.
##
## The [param input_maps] are expected to contain examples of tile maps. These
## are used to configure adjacency constraints and probabilities.
func _process_input_maps(input_maps : Array[TileMapLayer]) -> void:
	_neighbor_counts = {}
	
	# Interate over cells and check neighbors for adjacency.
	# Add one to counts for each neighbor tile seen.
	# Ignore empty cells.
	for map in input_maps:
		# Ensure tile set matches.
		if !map.tile_set || map.tile_set != _tile_set:
			continue
		
		for cell in map.get_used_cells():
			var source_id = map.get_cell_source_id(cell)
			var atlas_coords = map.get_cell_atlas_coords(cell)
			var source = map.tile_set.get_source(source_id)
			if source is TileSetAtlasSource:
				var unique_id : Vector3i = Vector3i(source_id, atlas_coords.x, atlas_coords.y)
				if !_neighbor_counts.has(unique_id):
					_neighbor_counts[unique_id] = {"count": 0, "neighbors": {}}
				_neighbor_counts[unique_id].count += 1
				
				# Surrounding cells are organized top, right, bottom, and then left.
				var neighbor_cells : Array = []
				neighbor_cells.push_back([
					Vector2i(cell.x, cell.y - 1), ComparisonDirection.TOP_TO_BOTTOM
				])
				neighbor_cells.push_back([
					Vector2i(cell.x + 1, cell.y), ComparisonDirection.RIGHT_TO_LEFT
				])
				neighbor_cells.push_back([
					Vector2i(cell.x, cell.y + 1), ComparisonDirection.BOTTOM_TO_TOP
				])
				neighbor_cells.push_back([
					Vector2i(cell.x - 1, cell.y), ComparisonDirection.LEFT_TO_RIGHT
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

## Conditionally output a debug message at a given severity level.
func _print_debug_message(message: String, severity : DebugSeverity) -> void:
	if _debug_mode:
		match severity:
			DebugSeverity.ERROR:
				push_error(message)
			DebugSeverity.WARNING:
				push_error(message)
			_:
				print(message)

## Get all valid possible tiles from the tile set.
##
## Returns an array containing the source ID and atlas coordinates as a [Vector3i].
func _get_valid_tiles() -> Array[Vector3i]:
	if !_tile_set:
		return []
	
	var valid_tiles : Array[Vector3i] = []
	for i : Vector3i in _neighbor_counts:
		valid_tiles.push_back(i)
	
	return valid_tiles

## Update the terrain possibilities within a cell.
##
## Requires the grid and the coordinates of the cell being updated.
func _update_cell_possibilities(grid : WFCGrid, coords : Vector2i) -> void:
	if !_valid_tiles || !grid:
		return
	
	var cell : WFCCell = grid.get_cell(coords.x, coords.y)
	if !cell:
		return
	
	if cell.get_status() == WFCCell.Status.CLOSED:
		return
	
	# Surrounding cells are organized top, right, bottom, and then left.
	# Cells may be null, this will be treated as an empty tile for possibility selection.
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
	
	# Start with base weights and widdle down the possibilities.
	var possibilities : Dictionary[Vector3i, float] = {}
	for tile : Vector3i in _valid_tiles:
		if _neighbor_counts.has(tile) && _neighbor_counts[tile].count > 0:
			possibilities[tile] = _neighbor_counts[tile].count
	
	for neighbor_cell in neighbor_cells:
		var neighbor : WFCCell = neighbor_cell[0]
		var direction : ComparisonDirection = neighbor_cell[1]
		# All adjacency possibilites are valid, skin this direction.
		if !neighbor || neighbor.get_status() == WFCCell.Status.OPEN:
			continue
		
		var neighbor_tile : Vector3i = neighbor.get_tile()
		if !_neighbor_counts[neighbor_tile] || !_neighbor_counts[neighbor_tile].neighbors.has(direction):
			continue
		
		for tile in _valid_tiles:
			if _neighbor_counts[neighbor_tile].neighbors[direction].has(tile):
				if possibilities.has(tile):
					# Choose the most constrained weight, either the existing weight or the one provided by the neighbor
					if possibilities[tile] > _neighbor_counts[neighbor_tile].neighbors[direction][tile]:
						possibilities[tile] = _neighbor_counts[neighbor_tile].neighbors[direction][tile]
			else:
				# Remove an invalid possibility
				possibilities.erase(tile)
	
	cell.set_possibilites(possibilities)
	tile_possibilities_updated.emit(coords, possibilities.size(), cell.get_entropy())

## Place or remove a tile from a cell.
##
## This updates the cell possibilities of this tile and all surrounding tiles,
## if relevant.
## Requires the grid, the coordinates of which cell is being changed, and the tile its being changed to.
##
## Alternatively, if the remove flag is supplied, this will remove the tile
## at a given set of grid coordinates.
func _place_tile(
	grid : WFCGrid, coords : Vector2i,
	tile : Vector3i, remove_tile : bool = false
) -> void:
	if !grid:
		return
	
	var cell : WFCCell = grid.get_cell(coords.x, coords.y)
	if !cell:
		return
	
	if remove_tile:
		cell.reset()
		_update_cell_possibilities(grid, coords)
		tile_removed.emit(coords)
	else:
		cell.place_tile(tile)
		var source := _tile_set.get_source(tile.x)
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
		_update_cell_possibilities(grid, neighbor)

## Place a random tile in a cell.
##
## This updates the possibilities of this cell and all surrounding cells,
## if relevant.
##
## Requires the pseudorandom number generator, the grid, and the coordinates of
## which cell is being changed.
##
## If was able to roll to place a tile, will return true, otherwise false.
func _place_random_tile(
	prng : RandomNumberGenerator, grid : WFCGrid, coords : Vector2i
) -> bool:
	var cell : WFCCell = grid.get_cell(coords.x, coords.y)
	if !cell:
		return false
	
	var possibilities := cell.get_possibilities()
	
	if possibilities.size() < 1:
		return false
	
	## Each probability prospect has a weight and a tile.
	var total_weight : float = 0.0
	for tile in possibilities:
		total_weight += possibilities[tile]
	
	if total_weight <= 0.0:
		return false
	
	var roll := prng.randf() * total_weight
	for tile in possibilities:
		var weight := possibilities[tile]
		if roll <= weight:
			_place_tile(grid, coords, tile)
			tile_possibilities_updated.emit(coords, 0, 0)
			return true
		
		roll -= weight
	
	return false

## Remove a tile from a cell.
##
## This updates the possibilities of this cell and all surrounding cells,
## if relevant.
##
## Requires the grid and the coordinates of the cell where the tile is being removed.
func _remove_tile(
	grid : WFCGrid, coords : Vector2i
) -> void:
	_place_tile(grid, coords, Vector3i(), true)

## Remove tiles from cells in local neighborhood.
##
## Remove the tiles from all surrounding cells in the local neighborhood.
## The neighborhood is defined as by being within a certain distance of the center tile
## in either or both X or Y.
##
## Returns any cells that had tiles removed as [coordinates, WFCCell].
func _remove_neighbor_tiles(
	grid : WFCGrid, coords : Vector2i, distance : int = 1
) -> Array[Array]:
	# Distance must be at least 1
	distance = maxi(distance, 1)
	
	# Surrounding cells are organized top, right, bottom, and then left.
	var neighbors : Array[Vector2i] = []
	for x in range(-distance, distance + 1):
		for y in range(-distance, distance + 1):
			if x != 0 || y != 0:
				neighbors.push_back(Vector2i(coords.x + x, coords.y + y))
	
	var neighbors_removed : Array[Array] = []
	
	# Remove neighbors, where they exist
	for neighbor_coords : Vector2i in neighbors:
		var cell = grid.get_cell(neighbor_coords.x, neighbor_coords.y)
		# Step over open or non-existent cells
		if !cell || cell.get_status() == WFCCell.Status.OPEN:
			continue
		_remove_tile(grid, neighbor_coords)
		neighbors_removed.push_back([neighbor_coords, cell])
	
	return neighbors_removed

## Initialize grid.
##
## Initialize the [WFCGrid] with possibilities.
## Requires the grid being initialized.
func _init_grid(grid : WFCGrid) -> void:
	if !_valid_tiles || _valid_tiles.is_empty():
		_print_debug_message("No tiles available.", DebugSeverity.WARNING)
		return
	
	if !grid:
		_print_debug_message("No grid to initialize.", DebugSeverity.WARNING)
		return
	
	var dimensions = grid.get_dimensions()
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			_update_cell_possibilities(grid, Vector2i(x, y))

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
	return a[1].get_entropy() < b[1].get_entropy()

## Set if the solver will output debug messages and information.
func set_debug_mode(debug_mode : bool) -> void:
	_debug_mode = debug_mode

## Set the amount of time between major actions, such as tile placements, when debugging.
##
## The delay will likely sync to the nearest physics cycle above it in time.
func set_debug_delay(delay : float) -> void:
	_debug_delay = max(delay, 0.0)

## Set the seed for the pseudorandom number generator (PRNG).
func set_seed(prng_seed : int) -> void:
	_seed = prng_seed

## Set the dimensions of the output grid.
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

## Set the maximum number of local retries before the solver gives up.
##
## This must be zero or above.
func set_max_local_resets(max_local_resets : int) -> void:
	_max_local_resets = maxi(max_local_resets, 1)

## Check if the solver is ready to be run.
##
## This contains safety checks for starting the solver.
func can_run() -> bool:
	var check_result : bool = true
	
	if _dimensions.x < MIN_SIZE || _dimensions.y < MIN_SIZE:
		_print_debug_message(
			"Grid dimensions must be larger than " + str(MIN_SIZE) + ".",
			DebugSeverity.ERROR
		)
		check_result = false
	
	if _max_retries < 1:
		_print_debug_message("Insufficient max retries.", DebugSeverity.ERROR)
		check_result = false
	
	if !_tile_set:
		_print_debug_message("Tile set must be supplied.", DebugSeverity.ERROR)
		check_result = false
	
	if !_valid_tiles:
		_print_debug_message("No valid tiles found.", DebugSeverity.ERROR)
		check_result = false
	
	if !_neighbor_counts || _neighbor_counts.is_empty():
		_print_debug_message("Neighbor tiles data structure does not have meaningful items.", DebugSeverity.ERROR)
		check_result = false
	
	return check_result

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
	var local_reset : int = 0 ## How many local resets have been used; a local reset clears and requeues all neighbors cells
	var last_defer : float = Time.get_ticks_msec() ## Total time since last defer.
	
	var grid := WFCGrid.new(_dimensions.x, _dimensions.y)
	_init_grid(grid)
	
	while true:
		var has_no_solution : bool = false ## If the current solution state is unsolvable.
		
		# Cells, partnered with their coordinates.
		var cells_left : Array[Array] = []
		var grid_dims := grid.get_dimensions()
		for y in grid_dims.y:
			for x in grid_dims.x:
				cells_left.push_back([Vector2i(x, y), grid.get_cell(x, y)])
		
		while cells_left.size() > 0:
			if _debug_mode && _debug_delay > 0.0:
				# Apply debugging delay
				await Engine.get_main_loop().create_timer(_debug_delay).timeout
			else:
				# Defer to the main loop every physics tick to prevent hanging
				if (Time.get_ticks_msec() - last_defer) > (1000.0 / Engine.physics_ticks_per_second):
					last_defer = Time.get_ticks_msec()
					await Engine.get_main_loop().process_frame
			
			# Sort cells to find lowest entrop
			_sort_cells_left(cells_left)
			var current_cell = cells_left.pop_front()
			
			if current_cell[1].has_possibilities():
				# If there are possible tiles for a cell, place a tile
				_place_random_tile(prng, grid, current_cell[0])
			else:
				# No solution state triggered
				if local_reset < _max_local_resets:
					# If there are local resets remaining, reset the local neighborhood
					# Requeue any cleared cells, and the current cell
					var cleared_cells := _remove_neighbor_tiles(grid, current_cell[0], 2)
					for cleared_cell in cleared_cells:
						cells_left.push_back(cleared_cell)
					cells_left.push_back(current_cell)
					local_reset += 1
				else:
					# If no solution state found, break
					has_no_solution = true
					break
		
		# On no solution, restart and retry if there are retries remaining
		if has_no_solution && retry < _max_retries:
			if _debug_mode && _debug_delay > 0.0:
				await Engine.get_main_loop().create_timer(_debug_delay).timeout
			retry += 1
			_print_debug_message(
				"No solution found. Restarting on retry " + str(retry) + ".",
				DebugSeverity.INFORMATION
			)
			grid = WFCGrid.new(_dimensions.x, _dimensions.y)
			_init_grid(grid)
			local_reset = 0
			if _debug_mode:
				grid_reset.emit()
			continue
		elif has_no_solution:
			# No solution found and out of retries, fail out
			grid.set_failed(WFCGrid.FailureCause.NO_SOLUTION)
			_print_debug_message(
				"No solution found. Retries exhausted.",
				DebugSeverity.INFORMATION
			)
			break
		else:
			# A solution was successfully found, mark the solution as successful
			_print_debug_message(
				"Solution found.",
				DebugSeverity.INFORMATION
			)
			grid.set_solved()
			break
			
	
	var end_time : int = Time.get_ticks_msec() ## When the process ended
	
	_print_debug_message(
		String("The solver has finished and has taken " + str(end_time - start_time) + "ms to run."),
		DebugSeverity.INFORMATION
	)
	
	return grid
