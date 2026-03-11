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

var _source_id : int = 0 ## The source of the tile in the relevant TileSet.
var _tile_index : int = 0 ## The unique index of the tile in the source.
var _status : Status = Status.OPEN ## If the space is populated or not.
var _possibilities : Array[Vector2i] = [] ## A collection of possible tiles for this space.

## Set space to contain tile.
func place_tile(source_id : int, tile_id : int) -> void:
	_source_id = source_id
	_tile_index = tile_id
	_status = Status.CLOSED

## Reset space to open.
func open_space() -> void:
	_source_id = 0
	_tile_index = 0
	_status = Status.OPEN

## Get the status.
func get_status() -> Status:
	return _status

## Add a possible tile this space could be occupied with.
func add_possibility(source_id : int, tile_id : int):
	_possibilities.push_back(Vector2i(source_id, tile_id))

## Clear the possible tiles that could go into this space.
func clear_possibilities():
	_possibilities = []

## Get the entropy of the space.
##
## This represents the number of tiles that could occupy the space.
func get_entropy() -> int:
	return _possibilities.size()
