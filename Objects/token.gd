@tool
@icon("res://icons/Draggable.svg")
extends Cell
class_name Token

## The default "do nothing" beat values.
var BLANK_BEAT : Dictionary = { "move": Vector3.INF, "command": Command.Undefined.new()}

## A list of the movement and commands this token will follow in a turn.
var beats : Array[Dictionary] = [
	BLANK_BEAT.duplicate(), BLANK_BEAT.duplicate(),
	BLANK_BEAT.duplicate(), BLANK_BEAT.duplicate()
]

enum Action{ NONE, MOVING, AIMING }
var action : Action = Action.NONE

enum Faction{ NONE, ONE, TWO }
@export var faction : Faction = Faction.NONE


# _____ MOVEMENT _____

@export_group("Movement")

## The number of movement this token can perform in a turn.
@export_range(1, 4) var move_limit : int = 4

## The number of tiles this token can travel per movement.
@export_range(1, 4, 1, "or_greater", "suffix:tiles") var move_length : int = 1

## The last beat that had a movement set for it.
var last_move_set : int = -1

## Whether the current movement sequence is valid or not.
## i.e. whether this token will intersect with other ally tokens.
var valid : bool = true

## Whether this token is currently selected.
var selected : bool = false:
	set(value):
		selected = value
		queue_redraw()

## Returns [code]true[/code] if the provided move data will result in a valid move.
## i.e. whether this token will intersect with other ally tokens.
func check_move_valid(
		direction : Vector3,
		distance : int,
		move_from : Vector3,
		beat : int
	) -> bool:
	if distance > move_length: return false
	for d : int in range(distance):
		var space = direction * (d + 1) + move_from
		var other : Cell = manager.get_cell_at(space)
		if other and not other is Token: return false
		for test : Token in manager.tokens:
			if test == self: continue
			var test_is_at : Vector3 = test.backsolve(beat)
			if test_is_at.is_equal_approx(space): return false
	return true

## Returns this token's position during a beat.
## If this token has no defined position for that beat, checks each previous
## beat and returns the first defined position found.
func backsolve(beat : int) -> Vector3:
		var token_position : Vector3 = Vector3.INF
		var solve_beat : int = beat
		while Cubic.is_null(token_position):
			if solve_beat == -1:
				token_position = cubic
				break
			token_position = beats[solve_beat].move
			solve_beat -= 1
		return token_position

## Checks if this token will intersect with any ally tokens during it's
## currently defined movement.
func validate() -> bool:
	for beat : int in range(4):
		var current : Vector3 = backsolve(beat)
		for token : Token in manager.tokens:
			if token == self: continue
			var other : Vector3 = token.backsolve(beat)
			if other.is_equal_approx(current):
				valid = false
				return false
	valid = true
	return true

## Returns all possible valid moves, starting from this token's last defined
## position.
func get_all_moves() -> Array[Vector3]:
	var moves : Array[Vector3] = []
	if last_move_set == 3: return moves
	var move_from : Vector3 = cubic
	if last_move_set != -1: move_from = beats[last_move_set].move
	if check_move_valid(Vector3.ZERO, 1, move_from, last_move_set + 1):
		moves.append(move_from)
	for d : int in range(move_length):
		for a : Vector3 in Cubic.DIRECTIONS:
			if check_move_valid(a, d + 1, move_from, last_move_set + 1):
				moves.append(a * (d + 1) + move_from)
	return moves

## Define this token's position at the given beat.
func set_move(beat : int, location : Vector3) -> void:
	beats[beat].move = location
	last_move_set = beat

## Remove this token's last defined position.
func pop_move() -> Vector3:
	var last_move : Vector3 = beats[last_move_set].move
	beats[last_move_set].move = BLANK_BEAT.move
	last_move_set -= 1
	return last_move

## Animate this token's movement to new position [param move].
## [br][param callback]: Function to run after this token has finished moving.
func tween_to_move(beat : int, callback : Callable) -> void:
	var move : Vector3 = backsolve(beat)
	var tween : Tween = self.create_tween()
	var final_position : Vector2 = Cubic.to_real(move, manager.grid)
	#var move_vector : Vector2 = final_position - position
	#var length : float = 0.2 + Cubic.distance(cubic, move) * 0.4
	#facing = position.angle_to_point(final_position)
	var face_towards : float = facing
	var next_command : Command = backsolve_command(beat)
	look_smooth = true
	print(next_command.type)
	match next_command.type:
		Command.Type.AIM:
			face_towards = next_command.direction
		Command.Type.AIM_TARGET:
			face_towards = Cubic.get_angle(next_command.target - move)
		_:
			face_towards = position.angle_to_point(final_position) - Cell.PI_6
	if alert:
		if Command.is_overwritable(next_command.type):
			face_towards = Cubic.get_angle(target_tile - move)
	tween.tween_interval(randf() * 0.5)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 1.0)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(self, "position", final_position, 1.2)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(self, "facing", Command.Aim.get_rotate_to(facing, face_towards), 1.2)
	tween.tween_property(self, "facing", face_towards, 0)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.6)
	tween.tween_interval(0.3)
	tween.tween_callback(func ():
		look_smooth = false
		callback.call()
	)

## Returns a list of this token's specified moves, in beat order.
func get_move_list() -> Array[Vector3]:
	var l : Array[Vector3] = []
	for b : Dictionary in beats: l.append(b.move)
	return l

# ______ AIMING & VISION ______

@export_group("Vision")

## The short-range view distance of this token.
## Used in most cases.
@export_range(1, 25, 1, "or_greater", "suffix:tiles") var radial_distance : int = 4

## The long-range "focused" view distance of this token.
## Used when aiming.
@export_range(1, 25, 1, "or_greater", "suffix:tiles") var focus_distance : int = 8

## The angle of this token's field of view when focused.
@export_range(0, 90, 15, "radians_as_degrees") var focus_angle : float = PI / 6

## The angle of this token's field of periphery when focused.
@export_range(0, 90, 15, "radians_as_degrees") var periphery : float = PI / 2

var _tries_radial : Array[Array] = []

var _tries_focus : Array[Array] = []

var _focus_cone : Array[Array] = []

var _periphery_cone : Array[Array] = []

## The tiles currently visible by this token.
var visible_tiles : Array[Vector3] = []

## The tiles currently partially visible by this token, due to occlusion.
var partial_visible_tiles : Array[Vector3] = []

## The tiles in this token's periphery field.
var periphery_tiles : Array[Vector3] = []

## The tiles at which this token has detected enemies.
var enemy_tiles : Dictionary = {}

## Whether this token is currently focused.
var focused : bool = true

## If false, then any values set to [member facing] are first snapped to one
## of 24 directions.
var look_smooth : bool = false

## The angle that this token is currently facing.
var facing : float = -Cell.PI_6:
	set(value):
		var new_facing : float = wrapf(value, -PI, PI)
		if not look_smooth:
			new_facing = snappedf(new_facing, Cell.PI_6 / 2)
		if not is_equal_approx(facing, new_facing):
			#print("new facing: ", new_facing)
			facing = new_facing

## The angle this token was facing at the end of the last turn.
var last_facing : float = -Cell.PI_6

## The tile being targeted by this token.
var target_tile : Vector3 = Vector3.INF

## Returns [code]true[/code] if [param value] is less than or equal to zero.
func is_zero_or_less_approx(value : float) -> bool:
	return value < 0 or is_zero_approx(value)

## Returns [code]true[/code] if [param value] is greater than or equal to zero.
func is_zero_or_greater_approx(value : float) -> bool:
	return value > 0 or is_zero_approx(value)

## Calculates the list of tries for this token's focus and periphery cones
func calculate_view_cones() -> void:	
	_focus_cone = _calculate_view_cone(_tries_focus, focus_angle)
	_periphery_cone = _calculate_view_cone(_tries_focus, focus_angle + periphery)

## Returns a generated list of tries to the points along a circle of radius
## [param view_distance].
func _pregenerate_tries(view_distance : float) -> Array[Array]:
	var outer_ring : Array[Vector3] = Cubic.get_ring(Vector3.ZERO, view_distance, 1.0)
	var tries : Array[Array] = []
	for r : Vector3 in outer_ring:
		# Calculate trie
		var trie : Array[Vector3] = Cubic.get_line(Vector3.ZERO, r)
		
		# Cull trie to circle
		var target_distance : float = view_distance / Cubic.TWO_SQRT_3
		for j : int in range(len(trie)):
			var p : Vector3 = trie[j]
			if is_zero_or_greater_approx(Cubic.euclidean(p) - target_distance):
				trie.resize(j)
				break
		
		# Add trie to list
		tries.append(trie)
	return tries

## Returns a sublist of tries, trimmed to only include ones angled up to
## [param view_angle] away from the angle [member facing].
func _calculate_view_cone(tries : Array[Array], view_angle : float) -> Array[Array]:
	view_angle += 0.005
	var view_cone : Array[Array] = []
	# For each trie,
	for i : int in range(len(tries)):
		var t : Array[Vector3] = tries[i]
		var theta : float = Cubic.get_angle(t[-1])
		
		# If outside vision cone, skip it
		var difference : float = angle_difference(theta, facing)
		if is_zero_or_less_approx(difference + view_angle):
			continue
		if is_zero_or_greater_approx(difference - view_angle):
			continue
			
		#if is_equal_approx(Cell.PI_6, abs(fmod(theta, Cell.PI_3))):
			#if not is_equal_approx(theta, facing):
				#var offset : Vector3 = Cubic.from_angle(facing + Cell.PI_3 * sign(difference), 0.1)
				#t = Cubic.get_line(offset, t[-1] + offset)
		
		# Remove origin from trie, to prevent self-detection later
		while t[0].is_zero_approx(): t.pop_front()
		
		view_cone.append(t)
	return view_cone

## Runs line-of-sight calculations on all tries currently active. Stores the
## results in [member visible_tiles] and [member partial_visible_tiles].
## Uses [member radial_distance] if [member focused] is [code]false[/code],
## and uses [member focus_distance] limited by [member focus angle] and
## [member periphery] if [member focused] is [code]true[/code].
func generate_vision(beat : int) -> void:
	var center : Vector3 = backsolve(beat)
	visible_tiles = []
	partial_visible_tiles = []
	periphery_tiles = []
	enemy_tiles = {}
	for trie : Array[Vector3] in _tries_radial:
		_line_of_sight(center, trie, false)
	if focused:
		for trie : Array[Vector3] in _focus_cone:
			_line_of_sight(center, trie, true)
		for trie : Array[Vector3] in _periphery_cone:
			_line_of_sight(center, trie, false)

func _line_of_sight(center : Vector3, trie : Array[Vector3], focus : bool) -> void:
	var partial : bool = !focus
	for point : Vector3 in trie:
		var skip : bool = false
		if point.is_zero_approx(): skip = true
		elif point in visible_tiles: skip = true
		elif partial and point in partial_visible_tiles: skip = true
		elif not focus and point in periphery_tiles: skip = true
		if skip:
			if point in enemy_tiles.keys(): break
			continue
		if point in periphery_tiles: periphery_tiles.erase(point)
		if not partial and point in partial_visible_tiles:
			partial_visible_tiles.erase(point)
		var other : Cell = manager.get_cell_at(point + center)
		if other:
			if other is Token:
				if (other.faction == 0 or other.faction != faction):
					if point in enemy_tiles.keys(): break
					else:
						enemy_tiles[point] = other
				if partial:
					if not focus: periphery_tiles.append(point)
					else: partial_visible_tiles.append(point)
					break
				else:
					visible_tiles.append(point)
					partial = true
					continue
			else:
				if not focus:
					if other.visibility != Visibility.TRANSPARENT: break
				else:
					match other.visibility:
						Cell.Visibility.SOLID: break
						Cell.Visibility.PARTIAL:
							if partial: break
							else: partial = true
		if not focus: periphery_tiles.append(point)
		else:
			if partial: partial_visible_tiles.append(point)
			else: visible_tiles.append(point)

## Animate token to aim in direction [param direction]
func tween_to_aim(direction : float, callback : Callable, speed : float = 1.0) -> Tween:
	var tween : Tween = self.create_tween()
	look_smooth = true
	var face_towards : float = Command.Aim.get_rotate_to(facing, direction)
	print("facing %s, direction %s, face_towards %s" % [facing/PI, direction/PI, face_towards/PI])
	tween.tween_property(self, "facing", face_towards, 0.5 * speed)
	tween.tween_property(self, "facing", direction, 0)
	tween.tween_callback(func():
		calculate_view_cones()
		print("final facing ", facing/PI)
		look_smooth = false
		focused = true
		callback.call()
	)
	return tween
	

# ______ BEAT EXECUTION ______

var command_options : Array[Command.Type] = [
	Command.Type.WATCH,
	Command.Type.AIM,
	Command.Type.AIM_TARGET,
]

## Whether this token is alerted.
var alert : bool = false

@export_group("Statistics")

## The amount of "hits" this token can withstand.
@export var max_health : float = 3.0

## This token's current health.
var health : float

## The chance for any attack on this token to miss, dealing reduced damage.
## Negative values indicate that this token is easier to hit than average.
## [br][code]1.0[/code] means this token is a guaranteed miss.
## [br][code]-1.0[/code] means this token is a guaranteed hit, not accounting for
## attack accuracy.
@export_range(-1.0, 1.0, 0.01, "suffix:/1.0") var evasion : float = 0.2

## The amount of "hits" this token inflicts when attacking.
@export var damage : float = 1.0

## The chance for any attack this token makes to miss, dealing reduced damage.
## [br][code]1.0[/code] means this token will always hit, not accounting for
## target evasion.
## [br][code]0.0[/code] means this token will always miss.
@export_range(0.0, 1.0, 0.01, "suffix:/1.0")  var accuracy : float = 0.8

func backsolve_command(beat : int) -> Command:
	var c : Command = beats[beat].command
	while c.type == Command.Type.UNDEFINED:
		if beat == 0:
			c = Command.Watch.new()
			break
		c = beats[beat - 1].command
		beat -= 1
	return c

## Perform the move defined in [member beats] for the given [param beat].
## Waits for the signal [signal BeatManager.perform_beat] from its
## [member Cell.manager] before executing.
func perform_move_to_beat(beat : int) -> void:
	await manager.perform_beat
	
	print("MOVE ", beat)
	
	tween_to_move(beat, func():
		manager.confirm_beat_complete()
	)

var debug_draw_vision : bool = false
## Perform the command defined in [member beats] for the given [param beat].
## Waits for the signal [signal BeatManager.perform_beat] from its
## [member Cell.manager] before executing.
func perform_command_to_beat(beat : int) -> void:
	await manager.perform_beat
	
	print("COMMAND ", beat, " : FACTION ", faction)
	
	var command : Command = beats[beat].command
	if command.type == Command.Type.UNDEFINED:
		command = backsolve_command(beat)
		match command.type:
			Command.Type.AIM, Command.Type.AIM_TARGET, Command.Type.WATCH:
				pass
			_:
				command = Command.Watch.new()
	print(command.type)
	if alert and Command.is_overwritable(command.type):
		command = Command.Aim_Target.new(target_tile)
	command.execute(beat, self, func():
		debug_draw_vision = true
		queue_redraw()
		await get_tree().create_timer(1.0).timeout
		debug_draw_vision = false
		manager.confirm_beat_complete(cubic)
	)
	
	if beat == 3: reset()


## Scan the current generated visible spaces from [method generate_vision] for
## tokens of a differing faction.
## [br]Returns an array containing the nearest enemy found and at what
## visibility that enemy was found (0 for peripheral, 1 for partial, 2 for
## fully visible)
func scan_for_enemy() -> Array:
	if len(enemy_tiles) > 0:
		var closest : float = INF
		var targets : Array[Vector3] = []
		for e : Vector3 in enemy_tiles.keys():
			var e_distance : float = Cubic.distance(e, Vector3.ZERO)
			if e_distance <= closest:
				closest = e_distance
				targets.append(e + cubic)
		var target : Vector3 = targets[0]
		if len(targets) > 1: target = targets.pick_random()
		var target_visibility : int = 0
		if target in partial_visible_tiles: target_visibility = 1
		if target in visible_tiles: target_visibility = 2
		print("ENEMY SPOTTED @ ", target, ", VISIBILITY ", target_visibility)
		return [target, target_visibility]
	return []

## Initiate some act upon an enemy location's.
## Token becomes [param alert] if the target is within peripheral and turns to
## face it, otherwise it attempts to fire upon the target.
func act_on_enemy(beat : int, target : Vector3, target_visibility : int) -> void:
	var moment_accuracy : float = accuracy
	if target_visibility == 0:
		var aim_to : float = Cubic.get_angle(target - cubic)
		aim_to = wrapf(snappedf(aim_to, Cell.PI_6 / 2), -PI, PI)
		tween_to_aim(aim_to, func(): generate_vision(beat), 0.5)
		alert = true
		target_tile = target
		moment_accuracy *= 0.5
	if target_visibility == 1: moment_accuracy *= 0.5
	var enemy : Token = enemy_tiles[target]
	var shot : float = randf() - enemy.evasion
	if shot < moment_accuracy and shot > 0.0:
		enemy.deal_damage(damage)
	else:
		enemy.deal_damage(damage * 0.5)

func deal_damage(hits : float) -> void:
	health = max(0.0, health - hits)

## Reset this token's beats to the values defined in [member BLANK_BEAT].
func reset() -> void:
	beats = [
		BLANK_BEAT.duplicate(), BLANK_BEAT.duplicate(),
		BLANK_BEAT.duplicate(), BLANK_BEAT.duplicate()
	]
	alert = false
	target_tile = Vector3.INF
	last_move_set = -1
	last_facing = facing
	queue_redraw()
	

# ______ BUILT-IN ______

func _ready() -> void:
	super._ready()
	_tries_radial = _pregenerate_tries(radial_distance)
	_tries_focus = _pregenerate_tries(focus_distance)
	health = max_health
	#last_facing = 0.0

func _draw() -> void:
	draw_line(
		Vector2.ZERO,
		Cubic.to_real(Cubic.from_angle(facing, 1.0), manager.grid),
		Color(1.0, 1.0, 0.0)
	)
	#draw_line(
	#	Vector2.ZERO,
	#	Cubic.to_real(Cubic.from_angle(last_facing, 1.0), manager.grid),
	#	Color(1.0, 1.0, 0.0, 0.5)
	#)
	
	if selected:
		if action == Action.MOVING:
			draw_path(self, self)
			draw_circle(
				Vector2.ZERO,
				manager.grid.outer_radius,
				Color(1.0, 1.0, 1.0, 0.5)
			)
		if action == Action.AIMING:
			draw_vision(Cubic.to_real(beats[manager.beat_editing].move, manager.grid) - position)
	
	if focused:
		draw_line(
			Vector2.ZERO,
			Cubic.to_real(Cubic.from_angle(facing, 1.0), manager.grid),
			Color(1.0, 0.0, 0.0)
		)
	else:
		draw_circle(
			Vector2.ZERO,
			manager.grid.outer_radius * 0.6,
			Color(1.0, 0.0, 0.0),
			false
		)
	
	if debug_draw_vision:
		draw_vision()
	
	match faction:
		Faction.ONE:
			draw_circle(Vector2.ZERO, manager.grid.inner_radius, Color(0,1,1,0.3))
		Faction.TWO:
			draw_circle(Vector2.ZERO, manager.grid.inner_radius, Color(1,0,1,0.3))
	super._draw()

func draw_vision(center : Vector2 = Vector2.ZERO) -> void:
	draw_set_transform(center)
	
	for v in visible_tiles:
		var hex : Array[Vector2] = Cell.get_points_around(Cubic.to_real(v, manager.grid), manager.grid.outer_radius, manager.grid.oriented)
		#draw_circle(, 20, Color(1,1,1,0.2))
		draw_colored_polygon(hex, Color(0.5,1,0.5,0.2))
		
	for v in partial_visible_tiles:
		var hex : Array[Vector2] = Cell.get_points_around(Cubic.to_real(v, manager.grid), manager.grid.outer_radius, manager.grid.oriented)
		#draw_circle(, 20, Color(1,1,1,0.2))
		draw_colored_polygon(hex, Color(0.5,1,0.5,0.1))
		
	for v in periphery_tiles:
		var hex : Array[Vector2] = Cell.get_points_around(Cubic.to_real(v, manager.grid), manager.grid.outer_radius, manager.grid.oriented)
		#draw_circle(, 20, Color(1,1,1,0.2))
		draw_colored_polygon(hex, Color(1,1,1,0.1))
		
	for v in enemy_tiles.keys():
		var hex : Array[Vector2] = Cell.get_points_around(Cubic.to_real(v, manager.grid), manager.grid.outer_radius, manager.grid.oriented)
		#draw_circle(, 20, Color(1,1,1,0.2))
		draw_colored_polygon(hex, Color(1,0,0,0.0))
	
	draw_set_transform(Vector2.ZERO)

## Draw [param token]'s projected path, as defined by the movements listed in
## [member beats]. Path drawn will start from [param origin].
## [br]This function must only be called in [method CanvasItem._draw], and
## [param canvas] must be set to [code]self[/code].
static func draw_path(
		canvas : CanvasItem,
		token : Token,
		origin : Vector2 = Vector2.ZERO,
		alpha : float = 0.5
	) -> void:
	#print(canvas.position, token.position, token.position - canvas.position, canvas.position - token.position)
	canvas.draw_set_transform(origin)
	var color : Color = Color(1.0, 1.0, 1.0, alpha)
	if not token.selected and not token.valid: color = Color(1.0, 0.0, 0.0, alpha)
	for i : int in range(4):
		var beat : Dictionary = token.beats[i]
		if not Cubic.is_null(beat.move):
			canvas.draw_circle(
				Cubic.to_real(beat.move - token.cubic, token.manager.grid),
				token.manager.grid.inner_radius * 0.5,
				color
			)
			var last_at : Vector3 = token.cubic
			if i > 0:
				last_at = token.beats[i - 1].move
			canvas.draw_line(
				Cubic.to_real(last_at - token.cubic, token.manager.grid),
				Cubic.to_real(beat.move - token.cubic, token.manager.grid),
				color,
				4
			)
	canvas.draw_set_transform(Vector2.ZERO)

func _process(_delta : float) -> void:
	super._process(_delta)
	if faction == Faction.ONE:
		#facing = get_local_mouse_position().angle() - Cell.PI_6
		#calculate_view_cones()
		#generate_vision(0)
		pass
	queue_redraw()
	
