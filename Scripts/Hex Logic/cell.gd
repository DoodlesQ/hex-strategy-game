@tool
@icon("res://icons/Cell.svg")
extends Node2D
class_name Cell
## A hex cell object.
##
## All objects that exist on a hex grid should extend this class.
## All instances of this class should be the child of some [HexManager] object.

## The default outer radius of a cell, if no manager is assigned.
const DEFAULT_RADIUS : float = 64.0

## PI / 6, precalculated for speed
const PI_6 : float = PI / 6
## PI / 3, precalculated for speed
const PI_3 : float = PI / 3

## The [HexManager] of this cell.
var manager : HexManager

## The different levels of visibility a cell can have.
enum Visibility {
	TRANSPARENT = 0, ## Completely see-through. Does not block sight.
	PARTIAL = 1, ## Partially see-through, only blocks sight after some depth.
	SOLID = 2, ## Completely opaque. Always blocks sight.
}

## How well this cell can be seen through by [class Token]s.
@export var visibility : Visibility = Visibility.SOLID

#static func _trait_flags() -> String:
	#var flags : String = ""
	#for t : String in Traits.keys(): flags += t.capitalize() + ","
	#return flags.trim_suffix(",")
#
#func _get_property_list() -> Array[Dictionary]:
	#return [{
		#"name": "traits",
		#"type": TYPE_INT,
		#"hint": PROPERTY_HINT_FLAGS,
		#"hint_string": _trait_flags()
	#}]
#func _get(property : StringName) -> Variant:
	#@warning_ignore("incompatible_ternary")
	#return traits if property == "traits" else null
#func _set(property : StringName, value : Variant) -> bool:
	#if property == "traits":
		#traits = traits ^ value
		#return true
	#return false
#func _property_can_revert(property : StringName) -> bool:
	#return true if property == "traits" else false
#func _property_get_revert(property : StringName) -> Variant:
	#return Traits.SOLID if property == "traits" else property_get_revert(property)

## This hex cell's coordinates in hexagonal "cubic" notation.
@export
var cubic : Vector3:
	set(value):
		assert(Cubic.is_valid(value), "Cubic coordinates must be valid")
		if not value.is_equal_approx(cubic):
			if manager: manager.update_cell_position(cubic, value)
		cubic = value
		if manager: _align_position()

@export_tool_button("Snap to Grid", "Snap") var tool_stg : Callable = snap_position


func _align_position() -> void:
	position = Cubic.to_real(cubic, manager.grid)

func snap_position() -> void:
	cubic = Cubic.snapped(cubic)

## Calculate a list of the corners of a hex cell.
## [br][param center]: The center of the hex cell in real-space.
## 		Default [code](0, 0)[/code]
func get_corners(center : Vector2 = Vector2.ZERO) -> Array[Vector2]:
	var radius : float = DEFAULT_RADIUS
	var oriented : HexGrid.Orient = HexGrid.Orient.FLAT
	if manager:
		radius = manager.grid.outer_radius
		oriented = manager.grid.oriented
	return Cell.get_points_around(center, radius, oriented)
	
## Calculate a list of the corners of a hex cell.
## Returns a list of each side's center point.
## [br][param center]: The center of the hex cell in real-space.
## 		Default [code](0, 0)[/code]
func get_sides(center : Vector2 = Vector2.ZERO) -> Array[Vector2]:
	var radius : float = HexGrid.SQRT_3 * DEFAULT_RADIUS * 0.5
	var oriented : HexGrid.Orient = HexGrid.Orient.POINT
	if manager:
		radius = manager.grid.inner_radius
		oriented = HexGrid.other_way(manager.grid.oriented)
	return Cell.get_points_around(center, radius, oriented)
	
## Calculate 6 points evenly distributed around a hex cell.
## Can be used to generate corner or side coordinates, though the non-static
## functions [method get_corners] and [method get_sides] are preferred.
static func get_points_around(center : Vector2, radius : float, orientation : HexGrid.Orient) -> Array[Vector2]:
	var corners : Array[Vector2] = []
	for i : int in range(1, 7):
		var angle = i * PI_3
		if orientation == HexGrid.Orient.POINT: angle -= PI_6
		corners.append(radius * Vector2.from_angle(angle) + center)
	return corners
	
## [br][param location]: The position of the hex cell in "cubic" notation.
func _init(location : Vector3 = Vector3.ZERO) -> void:
	cubic = location

func _ready() -> void:
	manager = get_parent() as HexManager
	#assert(manager, "Cell is not a child of a HexManager object.")
	if manager: manager.add_cell(self)
	
func _draw() -> void:
	var corners = get_corners()
	corners.append(corners[0])
	draw_polyline(corners, Color.BLACK)

func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() as HexManager: return []
	return ["Must be the child of a HexManager. When assigned a HexManager, this cell will change size to align with its HexGrid."]
	
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		manager = get_parent() as HexManager
		queue_redraw()
	
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if not manager:
			cubic = Vector3.ZERO
			position = Vector2.ZERO
		else:
			var new_cubic : Vector3 = Cubic.from_real(position, manager.grid)
			if not cubic.is_equal_approx(new_cubic):
				queue_redraw()
				cubic = new_cubic
