class_name TileWFCGridSpace extends Node
## A grid space within a [TileWFCGrid].
##
## Each space stores part of a solution state, such as what tiles may appear
## in a space, if the space has been populated, etc.
# TODO: Review this description

## The status of this space.
enum Status {
	OPEN, ## The space is open for placing a tile in.
	CLOSED ## The space has a tile in it.
}

var _tile : Vector3i = Vector3i() ## The source ID followed by the atlas coordinates within the source.
var _status : Status = Status.OPEN ## If the space is populated or not.
var _possibilities : Array[Vector3i] = [] ## A collection of possible tiles for this space.

## Set space to contain tile.
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

## Reset space to open.
func open_space() -> void:
	_tile = Vector3i()
	_status = Status.OPEN

## Get the status.
func get_status() -> Status:
	return _status

## Add a possible tile this space could be occupied with.
##
## The [param tile] is a source ID and tile index.
func add_possibility(tile : Vector3i):
	_possibilities.push_back(Vector3i(tile))

## Clear the possible tiles that could go into this space.
func clear_possibilities():
	_possibilities = []

## Get the entropy of the space.
##
## This represents the number of tiles that could occupy the space.
func get_entropy() -> int:
	return _possibilities.size()

## Get the array of possibilities.
##
## This is a direct reference, do not modify it.
func get_possibilities() -> Array[Vector3i]:
	return _possibilities
