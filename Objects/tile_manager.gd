@tool
@icon("res://icons/TileManager.svg")
extends HexManager
class_name TileManager
## Hex Manager class specifically for handling tile dragging and sliding.


## The cubic position of the cell currently focused by the player.
var drag_selected : Vector3 = Vector3.INF

## The cubic position of the cell last selected by the player while dragging.
var drag_from : Vector3 = Vector3.INF

## A list of the cell positions that can currently be dragged to.
var drag_options : Array[Vector3]

## The cell currently being dragged by the player.
var drag_cell : Draggable

## The last position the currently dragged cell was at.
var drag_last_at : Vector3 = Vector3.INF

## The estimating time the currently dragged cell takes to perform one movement
var drag_step : float = 0.0

## A list of cells that should be moved this turn.
var cells_to_move : Array[Vector3] = []

## Hashmap of all nodals.
var nodal_hash : Dictionary = {}

## The number of seconds that a turn takes.
## i.e. the amount of time it should take a cell to complete a maximal movement.
@export
var turn_time : float = 1.0

## Add a [Nodal] to the hex grid.
func add_nodal(nodal : Nodal) -> void:
	var location : Vector3 = Cubic.snapped(nodal.cubic)
	#TESTING ALTERNATIVE, DISABLED
	#assert(location not in nodal_hash, "Cannot add nodal %s, already exists" % location)
	if location in nodal_hash:
		var occupant : Nodal = nodal_hash[location]
		if occupant as Nodal.NodalGroup:
			occupant.add(nodal)
		else:
			var group = Nodal.NodalGroup.new(occupant.cubic, occupant.real)
			group.add(occupant)
			group.add(nodal)
			nodal_hash[location] = group
	else:
		nodal_hash[location] = nodal

## Get a list of every [Nodal] in the grid.
func get_nodals() -> Array : return nodal_hash.values()

## Find a [Nodal] in the hex grid at [param location].
## Returns [code]<null>[/code] if no Nodal is found.
func get_nodal_at(location : Vector3) -> Nodal:
	var snap : Vector3 = Cubic.snapped(location)
	if snap in nodal_hash: return nodal_hash[snap]
	return
	
## Removes a [Nodal] from the hex grid.
## [br]If [param cell] is specified, then it will also check that nodal's cell
## cubic, and will not remove it if it does not match.
## [br]If the nodal is a [Nodal.NodalGroup], then [param cell] instead
## determines which nodals within that NodalGroup should be removed.
## If this results in the NodalGroup storing only one nodal, it is automatically
## converted into a standard nodal. If it stores zero nodals, it is removed
## entirely.
func remove_nodal(location : Vector3, cell : Vector3 = Vector3.INF) -> void:
	assert(location in nodal_hash,
			"Cannot remove nodal %s, it doesn't exist" % location)
	var nodal : Nodal = get_nodal_at(location)
	if not Cubic.is_null(cell):
		if nodal as Nodal.NodalGroup:
			for n : Nodal in nodal.nodals.duplicate():
				if n.cell.is_equal_approx(cell):
					nodal.nodals.erase(n)
			if nodal.nodals.size() <= 1:
				nodal_hash.erase(location)
			if nodal.nodals.size() == 1:
				add_nodal(nodal.nodals[0])
			return
		else:
			if not nodal.cell.is_equal_approx(cell): return
	nodal_hash.erase(location)
	
func next_turn() -> void:
	for c : Vector3 in cells_to_move:
		get_cell_at(c).moving = true
	cells_to_move.clear()
	nodal_hash.clear()
	
func _get_drag_options(location : Vector3, from : Vector3 = Vector3.INF,
		time : float = 0.0) -> Array[Vector3]:
	# from = The tile we last moved away from, for direction calculations 
	if not from.is_finite(): from = drag_from
	# distance = Distance to check for availability
	var distance : float = drag_cell.tiles_per_move
	# candidates = Array of coordinates that are valid to move to
	var candidates : Array[Vector3] = []
	if from.is_equal_approx(location):
		# If we aren't moving *from* anywhere, we can go any direction we want
		candidates = Cubic.neighbors(location, distance)
	else:
		# Otherwise, we can only move in that direction or 30 degrees away
		var dir : Vector3 = Cubic.direction(from, location)
		var dir_l : Vector3 = Cubic.adjacent_direction(dir, false) 
		var dir_r : Vector3 = Cubic.adjacent_direction(dir, true)
		candidates = [
			location + dir * distance,
			location + dir_l * distance,
			location + dir_r * distance
		]
		# If sharp turns are enabled, we can move another 30 degrees each way
		if drag_cell.sharp_turns:
			candidates.append(
				location + Cubic.adjacent_direction(dir_l, false) * distance
			)
			candidates.append(
				location + Cubic.adjacent_direction(dir_r, true) * distance
			)
	var intersections : Dictionary = _get_moving_cells_in_area(
		location, distance, time, drag_step
	)
	# erasures = invalid candidates, to delete later (for looping reasons)
	var erasures : Array[Vector3] = []
	var test_path = drag_cell.path.duplicate()
	if test_path.size() == 0 or not test_path[-1].is_equal_approx(location):
		test_path.append(location)
	test_path.append(Vector2.INF)
	for c : Vector3 in candidates:
		test_path[-1] = c
		if _test_cell_path_for_collision_at(
				drag_cell, test_path, intersections, distance, time
			):
			erasures.append(c)
	for e : Vector3 in erasures: candidates.erase(e)
	return candidates

## Checks for moving cells in an area.
## [br][param center]: The center of the area being searched.
## [br][param radius]: The radius of the area being searched.
## [br][param time]: The time at which to search the area.
## [br][param speed]: The rate over which to search the area. That is, how far
## into the future (after [param time]) should the furthest edge of the
## [param radius] be checked for cells.
func _get_moving_cells_in_area(
		center : Vector3,
		radius : float,
		time : float = 0.0,
		speed : float = 0.0
		) -> Dictionary:
	
	var potentials : Dictionary = {}
	if cells_to_move.size() != 0:
		for c : Vector3 in cells_to_move:
			var cell : Draggable = get_cell_at(c) as Draggable
			# Where this cell will be during the time we are checking
			for s : int in range(0, (radius * 2) + 1):
				var at_time : float = time + speed * (s / (radius * 2))
				if at_time > 1.0: break
				var prediction : Vector3 = cell.get_location_during(at_time)
				# If this cell is within our movement range at this time,
				#  we need to check it later for collisions.
				if Cubic.distance(prediction, center) <= radius:
					potentials[at_time] = prediction
	return potentials

## [br][param cell]: Draggable Cell being tested (for pathfinding purposes).
## [br][param path]: The path to test against.
## [br][param potentials]: A map of times and associated positions of cells,
## to check for collisions. 
## [br][param distance]: The distance along the path to test.
## [br][param time]: The time at which to check for collisions.
func _test_cell_path_for_collision_at(
		cell : Draggable,
		path : Array[Vector3],
		potentials : Dictionary,
		distance : float = INF,
		time : float = 0.0
		) -> bool:
	
	if not is_finite(distance): distance = path.size() * cell.tiles_per_move
	var speed : float = 1.0 / cell.max_movements
	# Test every half tile along the distance:
	for s : int in range(0, (distance * 2) + 1):
		var at_time : float = time + speed * (s / (cell.tiles_per_move * 2.0))
		if at_time > 1.0: break
		
		var test : Vector3 = cell.get_point_on_path_during(at_time, path)

		# If that tile is occupied, this candidate is invalid
		var cell_check = get_cell_at(test)
		if cell_check:
			if cell_check != cell and cell_check.cubic not in cells_to_move:
				return true
			
		# If that tile is too close to one of our dangerous intersections,
		#  this candidate is invalid
		for i : float in potentials.keys():
			if is_zero_approx(at_time - i):
				var col : Vector3 = potentials[i]
				if Cubic.distance(test, col) < 1.0:
					return true
	
	return false

func _declare_dragging(cell : Cell, from : Vector3, last : Vector3 = Vector3.INF) -> void:
	drag_cell = cell
	drag_selected = cell.cubic
	drag_from = from
	drag_last_at = last
	drag_step = 1.0 / cell.max_movements
	if cell.path.size() == 0:
		drag_options = _get_drag_options(cell.cubic)
		cell.path.append(cell.cubic)
	elif cell.path.size() <= cell.max_movements:
		drag_options = _get_drag_options(drag_from, drag_last_at)
	else:
		drag_options = []

func _input(event : InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_cubic : Vector3 = Cubic.snapped(get_mouse_cubic())
		if event.button_index == MOUSE_BUTTON_LEFT:
			# If LMB Clicked...
			if event.pressed and Cubic.is_null(drag_selected):
				# If we've clicked on a cell and aren't currently dragging one:
				if mouse_cubic in cell_hash:
					var cell := get_cell_at(mouse_cubic) as Draggable
					# Check that cell isn't moving and doesn't already have a path
					if cell and not cell.moving and cell.path.size() == 0:
						# Set that as our dragging cell
						_declare_dragging(cell, cell.cubic)
				# If we've clicked on a nodal:
				if mouse_cubic in nodal_hash:
					var nodal := get_nodal_at(mouse_cubic)
					if nodal as Nodal.NodalGroup:
						# TODO: NodalGroup functionality
						return
					# Check if that's an end-of-path nodal (neagtive id)
					if nodal.id < 0:
						var cell := get_cell_at(nodal.cell) as Draggable
						# Finally check for the cell that nodal belongs to
						if cell and not cell.moving:
							# Remove all that cell's current path nodes
							for n : Vector3 in nodal_hash.keys():
								remove_nodal(n, cell.cubic)
							# And set it as our dragging cell
							cells_to_move.erase(cell.cubic)
							cell.ghost_time = -1
							_declare_dragging(cell, cell.path[-1], cell.path[-2])
			# If we've *released* LMB...
			elif not event.pressed and not Cubic.is_null(drag_selected):
				# Set the final destination of the drag cell
				drag_cell.move_final = drag_cell.path[-1]
				if not drag_cell.move_final.is_equal_approx(drag_cell.cubic):
					# Slate that cell as "to move" for later
					cells_to_move.append(drag_selected)
					for p : int in range(1, drag_cell.path.size()):
						# Add a nodal to each of it's path coordinates.
						var pos : Vector3 = drag_cell.path[p]
						var nodal := Nodal.new(
							pos, 
							Cubic.to_real(pos, grid),
							drag_selected
						)
						nodal.id = p/float(drag_cell.max_movements)
						if (p == drag_cell.path.size() - 1): nodal.id *= -1
						add_nodal(nodal)
				else:
					# If it didn't move at all, just reset it's path entirely.
					drag_cell.path.clear()
				drag_selected = Vector3.INF
				drag_last_at = Vector3.INF
				for c : Vector3 in cells_to_move:
					get_cell_at(c).ghost_time = -1.0
				
func _draw() -> void:
	if Engine.is_editor_hint(): super._draw()
	# _____ Drawing Movements ____
	if not Cubic.is_null(drag_selected):
		# If we have a cell selected, draw it's path so far
		for p : int in range(drag_cell.path.size() - 1):
			draw_line(
				Cubic.to_real(drag_cell.path[p], grid),
				Cubic.to_real(drag_cell.path[p+1], grid),
				Color(1, 1, 1, 0.5),
				grid.height / 2
			)
		var corners : Array[Vector2]
		# If there's a previous dragpoint, indicate it in red
		if not Cubic.is_null(drag_last_at):
			corners = Cell.get_points_around(Cubic.to_real(drag_last_at, grid), grid.inner_radius, grid.oriented)
			draw_colored_polygon(corners, Color(1, 0, 0, 0.5))
		# Indicate all dragpoint options in white
		for c : Vector3 in drag_options:
			corners = Cell.get_points_around(Cubic.to_real(c, grid), grid.inner_radius, grid.oriented)
			draw_colored_polygon(corners, Color(1, 1, 1, 0.25))
				
	# _____ DEBUG _____
	for c : Vector3 in cells_to_move:
		continue
		# Drag predictions (debug)
		var cell : Draggable = get_cell_at(c)
		if not cell: continue
		var predi : float = 20.0
		for i : float in range(predi+1):
			var test : Vector3 = cell.get_location_during(i/predi)
			draw_circle(Cubic.to_real(test, grid), 12, Color(0.0, i/predi, 1.0))
			draw_string(
				ThemeDB.fallback_font,
				Cubic.to_real(test, grid) + Vector2(0, -24),
				str(i/predi),
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.0, i/predi, 1.0)
			)
		continue
		# Drag path (debug)
		for p : int in range(cell.path.size()-1):
			draw_line(
				Cubic.to_real(cell.path[p], grid),
				Cubic.to_real(cell.path[p+1], grid),
				Color(1, 1, 1, 0.5),
				4
			)
			
	# Draw nodals (debug)
	for n : Nodal in nodal_hash.values():
		if n as Nodal.NodalGroup:
			draw_circle(n.real, 8, Color(1, 1, 1, 0.25))	
		draw_circle(n.real, 6, Color(1, 1, 1, 0.25))
		draw_circle(n.real, 4, Color(1, 1, 1, 0.75))
		continue
		draw_string(
			ThemeDB.fallback_font,
			n.real + Vector2(0, 24),
			str(n.id),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1.0, 1.0, 1.0)
		)

func _process(_delta : float) -> void:
	if Engine.is_editor_hint(): super._process(_delta)
	queue_redraw()
	# _____ Dragging Movement Selection _____
	if not Cubic.is_null(drag_selected):
		var mouse_cubic : Vector3 = get_mouse_cubic()
		var time : float
		# If mouse is at the last dragpoint, reverse the path by 1.
		if Cubic.distance(mouse_cubic, drag_last_at) <= 0.25:
			drag_from = drag_last_at
			drag_cell.path.pop_back()
			if drag_cell.path.size() > 1:
				drag_last_at = drag_cell.path[-2]
			else:
				drag_last_at = Vector3.INF
			time = (drag_cell.path.size() - 1) * drag_step
			drag_options = _get_drag_options(drag_from, drag_last_at, time)
		else:
			# Otherwise, loop through our drag options and check for the mouse
			for c : Vector3 in drag_options:
				if Cubic.distance(mouse_cubic, c) <= 0.5:
					# If it's there, progress the path that way
					time = drag_cell.path.size() * drag_step
					if drag_cell.path.size() < drag_cell.max_movements:
						drag_options = _get_drag_options(c, drag_from, time)
					else: drag_options = []
					drag_last_at = drag_cell.path[-1]
					drag_from = c
					drag_cell.path.append(c)
					break
		
		time = min((drag_cell.path.size() - 1) * (drag_step), 1.0)
		if not is_equal_approx(drag_cell.ghost_time, time):
			drag_cell.ghost_time = time
		for c : Vector3 in cells_to_move:
			var cell : Draggable = get_cell_at(c) as Draggable
			if not is_equal_approx(cell.ghost_time, time):
				cell.ghost_time = time
