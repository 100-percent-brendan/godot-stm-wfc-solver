class_name TileWFCGridSpace extends Node
## A grid space within a [TileWFCGrid].
##
## Each space stores part of a solution state, such as what tiles may appear
## in a space, if the space has been populated, etc.
# TODO: Review this description

## The status of this space.
enum Status {
	OPEN,
	POPULATED
}

var _source_id : int = 0 ## The source of the tile in the relevant TileSet.
var _tile_id : int = 0 ## The unique ID of the tile in the relevant TileSet.
var _status : Status = Status.OPEN ## If the space is populated or not.
