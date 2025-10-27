@tool
@icon("res://icons/Draggable.svg")
extends Cell
class_name Draggable
## [Cell] that can be dragged or moved across the grid.
##
## This cell should, in most cases, be the child of a [TileManager].

## The final tile that this cell will move to.
var move_final : Vector3 = Vector3.INF

## A list of coordinates that the cell will pass through when moving.
var path : Array[Vector3] = []

## If [code]true[/code], the cell should attempt to follow it's [member path].
var moving : bool = false

## The current [member path] index being moved towards.
var move_to : int = 0

## This cell's speed in tiles/second
var move_speed : float = 0.0

## If positive, this cell will draw it's "ghost" at the given time
var ghost_time : float = -1.0:
	set(value):
		if is_equal_approx(ghost_time, value): return
		
		ghost_time = value
		_align_position()
		queue_redraw()

## The maximum number of movements this cell can make at a time.
## In other words, the largest [member path] this cell can have at once.
@export
var max_movements : int = 4

## The amount of tiles this cell can travel per movement.
## In other words, the distance between each tile in [member path].
@export
var tiles_per_move : int = 1

## Whether this cell can make sharp turns (60 degrees).
@export
var sharp_turns : bool = false

## Returns this cell's projected position, using [param time] as a percentage
## of the current turn ([code]0.0[/code] - [code]1.0[/code])
func get_location_during(time : float) -> Vector3:
	return get_point_on_path_during(time, path)

## Returns this cell's projected position on an arbitrary path.
## [param time]: Ratio ([code]0.0[/code] - [code]1.0[/code]) of a turn.
func get_point_on_path_during(time : float, _path : Array[Vector3]):
	assert(time >= 0.0 and time <= 1.0, "Invalid time step: %s" % time)
	assert(_path.size() > 0, "Path has no size")
	var tiles_moved : float = time * manager.turn_time * move_speed
	var moves_made : int = min(tiles_moved / tiles_per_move, _path.size()-1)
	var path_at : Vector3 = _path[moves_made]
	var path_next : Vector3 = _path[min(moves_made + 1, _path.size()-1)]
	var tiles_this_move = tiles_moved - (moves_made * tiles_per_move)
	return path_at + Cubic.direction(path_at, path_next) * tiles_this_move

func _draw() -> void:
	for s : Sprite2D in find_children("*", "Sprite2D"):
		if manager:
			s.scale = Vector2.ONE * manager.grid.outer_radius / DEFAULT_RADIUS
		s.modulate.a = 0.5 if ghost_time > 0 else 1.0
	super._draw()
	
func _align_position() -> void:
	super._align_position()
	if ghost_time > 0.0:
		var ghost : Vector3 = get_location_during(ghost_time) - cubic
		position += Cubic.to_real(ghost, manager.grid)

func _ready() -> void:
	super._ready()
	var seconds = (manager as TileManager).turn_time if (manager as TileManager) else 1.0
	move_speed = (tiles_per_move * max_movements) / seconds

func _process(delta : float) -> void:
	if Engine.is_editor_hint(): super._process(delta)
	if moving:
		# Increment our location towards the next point in the path
		if Cubic.distance(cubic, path[move_to]) > move_speed * delta:
			var movement : Vector3 = Cubic.direction(cubic, path[move_to]) * move_speed * delta
			cubic += Cubic.snapped(movement, 0.001)
		else:
			# If we would've overshot it this step, just snap to it exactly
			cubic = path[move_to]
		# If we've reached that point,
		if cubic.is_equal_approx(path[move_to]):
			# Snap to it (to round off potential floating point errors)
			cubic = path[move_to]
			# If we're now at our intended final tile,
			if cubic.is_equal_approx(move_final):
				# Snap to it, ensuring the final position is in
				#  integer coordinates, and stop moving. The path is finished
				cubic = Cubic.snapped(move_final)
				moving = false
				move_to = 0
				path.clear()
			# Otherwise, start moving towards the next point.
			move_to += 1
