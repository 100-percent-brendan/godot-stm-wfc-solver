class_name WFCCell extends Node
## A grid cell within a [WFCGrid].
##
## Each cell stores part of a solution state, such as what tiles may appear
## in a cell, if the cell has been populated, etc.
# TODO: Review this description

## The status of this cell.
enum Status {
	OPEN, ## The cell is open for placing a tile in.
	CLOSED ## The cell has a tile in it.
}

var _tile : Vector3i = Vector3i() ## The source ID followed by the atlas coordinates within the source.
var _status : Status = Status.OPEN ## If the cell is populated or not.
var _possibilities : Dictionary[Vector3i, float] = {} ## A collection of possible tiles with weights for this cell.
var _total_weight : float = 0.0 ## The total weight of all possible tiles.
var _entropy : float = 0.0 ## The Shannon entropy.

## Calculate the entropy.
func _calculate_entropy() -> void:
	if _status == Status.CLOSED || !has_possibilities():
		_entropy = 0.0
		return
	
	var entropy : float = 0.0
	for i in _possibilities:
		var prob = _possibilities[i] / _total_weight
		entropy -= (prob * log(prob) / log(2))
	
	_entropy = entropy

## Set cell to contain tile.
##
## The [param tile] is a source ID and atlas coordinates.
func place_tile(tile : Vector3i) -> void:
	_tile = tile
	_status = Status.CLOSED
	clear_possibilities()

## Get the tile.
##
## Be sure to check status to see if a tile exists here first.
func get_tile() -> Vector3i:
	return _tile

## Reset cell to open.
func reset() -> void:
	_tile = Vector3i()
	_status = Status.OPEN

## Get the status.
func get_status() -> Status:
	return _status

## Set possibilities.
##
## This accepts a [Dictionary[Vector3i, float]] with the tile as the index (represented as a
## source ID and atlas coordinates) and the value holding probability weights. This will store
## a reference to the object.
func set_possibilites(possibilities : Dictionary[Vector3i, float]) -> void:
	_possibilities = possibilities
	_total_weight = 0.0
	for i in _possibilities:
		_total_weight += _possibilities[i]
	_entropy = 0.0
	_calculate_entropy()

## Determines if there are any possibilities for this cell.
##
## Returns true on has possibilities, and false otherwise.
func has_possibilities() -> bool:
	return _possibilities && _possibilities.size() > 0

## Clear the possible tiles that could go into this cell.
func clear_possibilities() -> void:
	_possibilities = {}
	_total_weight = 0.0
	_entropy = 0.0

## Get the entropy of the cell.
##
## This represents the number of tiles that could occupy the cell.
func get_entropy() -> int:
	return _entropy

## Get the array of possibilities.
##
## This is a direct reference, do not modify it.
func get_possibilities() -> Dictionary[Vector3i, float]:
	return _possibilities
