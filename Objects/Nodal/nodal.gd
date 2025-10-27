extends Resource
class_name Nodal
## A resource the represents a position on a hex-grid assigned to a [Cell].

## The cubic location of this nodal
var cubic : Vector3

## The real position of this nodal
var real : Vector2

## The cell this nodal is associated with
var cell : Vector3

## An identifier for this nodal (optional)
var id : float = 0

func _init(_cubic : Vector3, _real : Vector2, _cell : Vector3, _id : float = 0) -> void:
	cubic = _cubic
	real = _real
	cell = _cell
	id = _id

## A special [Nodal] that serves as a group of regular Nodals.
##
## A NodalGroup has no cell associated with it or an id. Both are set to
## [member Vector3.INF] and [member @GDScript.INF] respectively.
class NodalGroup:
	extends Nodal
	
	var nodals : Array[Nodal]
	
	func add(nodal : Nodal) -> void: nodals.append(nodal)
	
	func _init(_cubic : Vector3, _real : Vector2, _nodals : Array[Nodal] = []) -> void:
		cubic = _cubic
		real = _real
		cell = Vector3.INF
		id = INF
		nodals = _nodals
