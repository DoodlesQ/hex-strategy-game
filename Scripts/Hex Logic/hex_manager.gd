@tool
@icon("res://icons/Hex.svg")
extends Node2D
class_name HexManager
## Base class for generating and working with a hex-grid.


## A hashmap containing all [Cell] objects within the grid.
var cell_hash : Dictionary

## The [HexGrid] used by this hex grid manager. Contains grid size and
## orientation, as well as origin point within real-space.
## Used to pass these grid properties onto other object methods.
@export
var grid : HexGrid:
	set(value):
		grid = value
		if Engine.is_editor_hint():
			update_configuration_warnings()
			for c : Cell in get_cells():
				c._align_position()

@export_subgroup("Debug")
@export var _show_grid : bool = false

## Add a [Cell] to the hex grid.
func add_cell(cell : Cell) -> void:
	var location = Cubic.snapped(cell.cubic)
	assert(location not in cell_hash, "Cannot add cell %s, already exists" % location)
	cell_hash[location] = cell
	
## Get a list of every [Cell] in the grid.
func get_cells() -> Array: return cell_hash.values()
	
## Find a [Cell] in the hex grid at [param location].
## Returns [code]<null>[/code] if no Cell is found.
func get_cell_at(location : Vector3) -> Cell:
	var snap = Cubic.snapped(location, 0.5)
	if snap in cell_hash: return cell_hash[snap]
	return

func remove_cell_at(location : Vector3) -> void:
	assert(location in cell_hash, "Cannot remove cell %s, does not exist" % location)
	var cell : Cell = get_cell_at(location)
	cell_hash.erase(location)
	cell.queue_free()
	
	
## Update the recorded position of a [Cell] in the hashmap.
## This should be run every time a cell's cubic position changes, to ensure
## the manager is able to find it at that new location.
func update_cell_position(location : Vector3, new_location : Vector3) -> void:
	var snap = Cubic.snapped(location, 0.5)
	var new_snap = Cubic.snapped(new_location, 0.5)
	if snap.is_equal_approx(new_snap): return
	assert(new_snap not in cell_hash, \
		"Cell @ %s moved to an invalid location: %s, already occupied." % [snap, new_snap])
	var temp = get_cell_at(snap)
	cell_hash.erase(snap)
	cell_hash[new_snap] = temp
	
## Returns the mouse's current cubic coordinates.
func get_mouse_cubic() -> Vector3:
	return Cubic.from_real(get_local_mouse_position(), grid)

func _ready() -> void:
	position = grid.origin
	
func _process(_delta : float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		if grid and position != grid.origin:
			grid.origin = position

func _draw_grid_piece(at : Vector2, alpha : float) -> void:
	var c : Array[Vector2] = Cell.get_points_around(at, grid.outer_radius, grid.oriented)
	c.append(c[0])
	draw_polyline(c, Color(1, 1, 1, alpha), 1)

func _draw() -> void:
	if Engine.is_editor_hint() and _show_grid:
		_draw_grid_piece(Vector2.ZERO, 0.8)
		for r : int in range(1, 6):
			for cell : Vector3 in Cubic.get_ring(Vector3.ZERO, r):
				_draw_grid_piece(Cubic.to_real(cell, grid), 0.05+((5-r)/6.0))
		#draw_circle(Vector2.ZERO, 10, Color(1, 1, 1))
		
func _get_configuration_warnings() -> PackedStringArray:
	if grid: return []
	return ["Grid must be assigned"]
