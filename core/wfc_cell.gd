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
var _possibilities : Array[Vector3i] = [] ## A collection of possible tiles for this cell.

## Set cell to contain tile.
##
## The [param tile] is a source ID and tile index.
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

## Add a possible tile this cell could be occupied with.
##
## The [param tile] is a source ID and tile index.
func add_possibility(tile : Vector3i):
	_possibilities.push_back(Vector3i(tile))

## Clear the possible tiles that could go into this cell.
func clear_possibilities():
	_possibilities = []

## Get the entropy of the cell.
##
## This represents the number of tiles that could occupy the cell.
func get_entropy() -> int:
	return _possibilities.size()

## Get the array of possibilities.
##
## This is a direct reference, do not modify it.
func get_possibilities() -> Array[Vector3i]:
	return _possibilities
