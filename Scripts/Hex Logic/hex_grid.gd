@tool
@icon("res://icons/HexGrid.svg")
extends Resource
class_name HexGrid
## Data storage for a hex grid, containing the grid size and orientation.


## sqrt(3), precalculated for speed
const SQRT_3 : float = sqrt(3.0)

## Orientation used for calculating tile data.
enum Orient {
	FLAT, ## Flat-topped hexagon orientation
	POINT, ## Point-topped hexagon orientation
}

## The width of a tile within the grid,
## from leftmost edge to rightmost edge.
var width : float

## The width of a tile within the grid,
## from topmost edge to bottommost edge.
var height : float

## The horizontal spacing of the hex grid
## (from tile center to tile center).
var horizontal_spacing : float

## The vertical spacing of the hex grid
## (from tile center to tile center).
var vertical_spacing : float

## The inner radius of all tiles within the grid.
var inner_radius : float

## The origin point [code](0, 0, 0)[/code] of the hex grid in real-space.
@export var origin : Vector2

## The outer radius of all tiles within the grid.
## Also referred to as the "size".
@export_range(0, 1600, 0.01, "hide_slider")
var outer_radius : float = 1.0:
	set(value):
		outer_radius = value
		inner_radius = SQRT_3 * outer_radius * 0.5
		_calculate_sizes()

## The orientation of the hex grid.
@export var oriented : Orient:
	set(value):
		oriented = value
		_calculate_sizes()

	
## Returns the opposite orientation compared to the [param orientation] given.
## [br]i.e. if [param orientation] is equal to [member Orient.FLAT],
## returns [member Orient.POINTED]
static func other_way(orientation : Orient) -> Orient:
	if orientation == Orient.FLAT: return Orient.POINT
	return Orient.FLAT
	
func _calculate_sizes() -> void:
	width = _calculate_width(outer_radius, oriented)
	height = _calculate_height(outer_radius, oriented)
	horizontal_spacing = HexGrid._spacing(true, self)
	vertical_spacing = HexGrid._spacing(false, self)
	
static func _spacing(horizontal : bool, grid : HexGrid) -> float:
	if (horizontal and grid.oriented == Orient.FLAT) \
			or (not horizontal and grid.oriented == Orient.POINT):
		return 1.5 * grid.outer_radius
	if horizontal: return grid.width
	return grid.height
	
static func _calculate_width(grid_size : float, orientation : Orient) -> float:
	if orientation == Orient.FLAT: return 2 * grid_size
	return SQRT_3 * grid_size

static func _calculate_height(grid_size : float, orientation : Orient) -> float:
	return _calculate_width(grid_size, other_way(orientation))

func _to_string() -> String:
	return "{ Grid\n\t@: "+str(origin)+"\n"+\
			"\tSize: "+str(outer_radius)+" "+str(Vector2(width, height))+"\n"+\
			"\tSpacing: "+str(Vector2(horizontal_spacing, vertical_spacing))+"\n"+\
			"\tOrientation: "+Orient.keys()[oriented]+"\n"+\
			"}"
			
