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
@export var _show_grid : bool = false:
	set(value):
		_show_grid = value
		queue_redraw()
@export_range(1, 60, 1) var _grid_size : int = 6:
	set(value):
		_grid_size = value
		queue_redraw()
@export_range(0.0, 1.0, 0.1) var _grid_opacity : float = 1.0:
	set(value):
		_grid_opacity = value
		queue_redraw()

## Add a [Cell] to the hex grid.
func add_cell(cell : Cell, list : Dictionary = cell_hash) -> void:
	_add_cell_at(cell.cubic, cell, list)
	
## Get a list of every [Cell] in the grid.
func get_cells() -> Array: return cell_hash.values()
	
## Find a [Cell] in the hex grid at [param location].
## Returns [code]<null>[/code] if no Cell is found.
func get_cell_at(location : Vector3, list : Dictionary = cell_hash) -> Cell:
	var index : Vector3 = Cubic.snapped(location)
	return list[index] if index in list else null

func remove_cell_at(location : Vector3, list : Dictionary = cell_hash) -> void:
	var index : Vector3 = Cubic.snapped(location)
	assert(index in list.keys(), "Cannot remove cell %s, does not exist" % index)
	var cell : Cell = get_cell_at(index)
	list.erase(index)
	cell.queue_free()

func _add_cell_at(location : Vector3, cell : Cell, list : Dictionary = cell_hash) -> void:
	var index : Vector3 = Cubic.snapped(location)
	assert(index not in list.keys(), "Cannot add cell %s, already exists" % index)
	list[index] = cell
	
## Update the recorded position of a [Cell] in the hashmap.
## This should be run every time a cell's cubic position changes, to ensure
## the manager is able to find it at that new location.
func update_cell_position(location : Vector3, new_location : Vector3, list : Dictionary = cell_hash) -> void:
	var index = Cubic.snapped(location)
	var new_index = Cubic.snapped(new_location)
	if index.is_equal_approx(new_index): return
	assert(new_index not in list, \
		"Cell @ %s moved to an invalid location: %s, already occupied." % [index, new_index])
	var cell : Cell = list[index]
	list.erase(index)
	list[new_index] = cell
	
## Returns the mouse's current cubic coordinates.
func get_mouse_cubic() -> Vector3:
	return Cubic.from_real(get_local_mouse_position(), grid)

func _ready() -> void:
	position = grid.origin
	
func _process(_delta : float) -> void:
	if Engine.is_editor_hint():
		if grid and position != grid.origin:
			grid.origin = position

func _draw_grid_piece(at : Vector2, alpha : float) -> void:
	var c : Array[Vector2] = Cell.get_points_around(at, grid.outer_radius, grid.oriented)
	c.append(c[0])
	draw_polyline(c, Color(1, 1, 1, alpha), 1)

func _draw() -> void:
	if Engine.is_editor_hint() and _show_grid:
		_draw_grid_piece(Vector2.ZERO, 0.8)
		print("DRAW GRID")
		for r : int in range(1, _grid_size):
			for cell : Vector3 in Cubic.get_ring(Vector3.ZERO, r):
				_draw_grid_piece(Cubic.to_real(cell, grid), _grid_opacity * (0.05+((_grid_size-1.0-r)/_grid_size)))
		#draw_circle(Vector2.ZERO, 10, Color(1, 1, 1))
		
func _get_configuration_warnings() -> PackedStringArray:
	if grid: return []
	return ["Grid must be assigned"]
