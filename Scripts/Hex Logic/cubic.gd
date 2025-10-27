class_name Cubic
## Helper class containing functions for working with cubic coordinates.
##
## [Cell] objects exist within their own coordinate system, using what is
## called "cubic" notation.
## [br][br]There are three axis in this system:
## [color=green]q[/color],
## [color=cyan]r[/color],
## and [color=violet]s[/color].
## [br]The exact direction of these axis in regular coordinate space depends on
## the [member Hex.Orient] orientation of the hex grid.
## [br][img width=128]res://Scripts/Hex Logic/ref_hexaxis_flat.png[/img]
## [img width=128]res://Scripts/Hex Logic/ref_hexaxis_pointy.png[/img]
## [br][br]Cubic coordinates have a unique property, which is that all three axis values
## must always add up to [code]0[/code].
## You can check if a coordinate is valid using [method Cubic.is_valid]
## [br][br]For more information on cubic coordinates on a hexagonal grid, check
## [url=https://www.redblobgames.com/grids/hexagons/]Amit Patel's Guide to Hexagonal Grids[/url]

#                       q   r   s
const NORTH := Vector3( 0, -1, +1) ## 90 degrees counter-clockwise from the positive [color=green]q[/color]-axis
const SOUTH := Vector3( 0, +1, -1) ## 90 degrees clockwise from the positive [color=green]q[/color]-axis
const EAST  := Vector3(+1,  0, -1) ## 90 degrees counter-clockwise from the positive [color=cyan]r[/color]-axis
const WEST  := Vector3(-1,  0, +1) ## 90 degrees clockwise from the positive [color=cyan]r[/color]-axis
const KATA  := Vector3(-1, +1,  0) ## 90 degrees counter-clockwise from the positive [color=violet]s[/color]-axis
const ANNA  := Vector3(+1, -1,  0) ## 90 degrees clockwise from the positive [color=violet]s[/color]-axis

## List of the six cardinal directions in cubic coordinate space.
## [br]Prefer to use the constant values directly, if applicable.
const DIRECTIONS := [NORTH, ANNA, EAST, SOUTH, KATA, WEST]

## List of colors associated with the six cardinal directions,
## for use in debugging.
static var DEBUG_COLORS := {
	NORTH: Color.GREEN,
	 ANNA: Color.VIOLET,
	 EAST: Color.CYAN.blend(Color(0, 0, 0, 0.5)),
	SOUTH: Color.GREEN.blend(Color(0, 0, 0, 0.5)),
	 KATA: Color.VIOLET.blend(Color(0, 0, 0, 0.5)),
	 WEST: Color.CYAN,
}

## Cubic epsilon value, for infinitesimal adjustments
const EPSILON : Vector3 = Vector3(1e-6, 2e-6, -3e-6)

## 2 / sqrt(3), precalculated for speed
const TWO_SQRT_3 : float = 2.0 / sqrt(3)

## 2/3 * PI, precalculated for speed
const PI_2_3 : float = (2.0 / 3.0) * PI


## Convert a cubic coordinate into real-space coordinates.
static func to_real(cubic : Vector3, grid : HexGrid) -> Vector2:
	var real := Vector2.ZERO
	if grid.oriented == HexGrid.Orient.FLAT:
		real.x = cubic.x * grid.horizontal_spacing
		real.y = (-cubic.z + cubic.y) * grid.vertical_spacing * 0.5
	else:
		real.x = (-cubic.z + cubic.x) * grid.horizontal_spacing * 0.5
		real.y = cubic.y * grid.vertical_spacing
	return real


## Convert a real-space coordinate into cubic coordinates
static func from_real(position : Vector2, grid : HexGrid) -> Vector3:
	var cubic := Vector3.ZERO
	if grid.oriented == HexGrid.Orient.FLAT:
		cubic.x = position.x / grid.horizontal_spacing
		cubic.y = position.y / grid.vertical_spacing - cubic.x * 0.5
		cubic.z = -(cubic.x + cubic.y)
	else:
		cubic.y = position.y / grid.vertical_spacing
		cubic.x = position.x / grid.horizontal_spacing - cubic.y * 0.5
		cubic.z = -(cubic.x + cubic.y)
	return cubic

## Returns a new cubic coordinate snapped to a fixed number of decimal places.
## [br]Will always return a valid cubic coordinate.
static func snapped(location : Vector3, step : float = 1.0) -> Vector3:
	var snapped_location := location.snapped(Vector3(step, step, step))
	if is_valid(snapped_location): return snapped_location
	#old: ~17ms
	#new: ~9ms
	return _snap_revalidate(location, snapped_location)

static func _snap_revalidate(location : Vector3, snapped_location : Vector3) -> Vector3:
	var difference : Vector3 = (snapped_location - location).abs()
	match difference.max_axis_index():
		Vector3.AXIS_X:
			snapped_location.x = -(snapped_location.y + snapped_location.z)
		Vector3.AXIS_Y:
			snapped_location.y = -(snapped_location.x + snapped_location.z)
		_: snapped_location.z = -(snapped_location.x + snapped_location.y)
	return snapped_location

static func _snap_revalidate_old(location : Vector3, snapped_location : Vector3) -> Vector3:
	var A := Vector3(
		snapped_location.x,
		snapped_location.y,
		-(snapped_location.x + snapped_location.y)
	)
	var Ad : float = distance(location, A)
	var B := Vector3(
		snapped_location.x,
		-(snapped_location.x + snapped_location.z),
		snapped_location.z
	)
	var Bd : float = distance(location, B)
	var C := Vector3(
		-(snapped_location.y + snapped_location.z),
		snapped_location.y,
		snapped_location.z
	)
	var Cd : float = distance(location, C)
	match min(Ad, Bd, Cd):
		Ad: return A
		Bd: return B
		Cd: return C
	return snapped_location

## Returns [code]true[/code] if a given [Vector3] is a valid cubic coordinate.
static func is_valid(location : Vector3) -> bool:
	return is_zero_approx(location.x + location.y + location.z)
	
## Returns the sum of all components of a cubic coordinate.
## For valid coordinates, this should return [code]0[/code].
## [br]If you only need to check if a coordinate is valid or not,
## use [method is_valid] instead.
#static func validate(location : Vector3) -> float:
	#return location.x + location.y + location.z

## Returns a random cubic vector in one of the six cardinal directions
static func random() -> Vector3:
	return DIRECTIONS[randi_range(0, 5)]

## Returns the distance between two cubic coordinates
static func distance(location1 : Vector3, location2 : Vector3) -> float:
	var s : Vector3 = (location1 - location2).abs()
	return s[s.max_axis_index()]

## Returns the direction from one cubic coordinate to another
static func direction(location1 : Vector3, location2 : Vector3) -> Vector3:
	var naive = location2 - location1
	var QR = naive.x - naive.y
	var RS = naive.y - naive.z
	var SQ = naive.z - naive.x
	if 0.0 in [QR, RS, SQ]: return Vector3(sign(QR), sign(RS), sign(SQ))
	var d = {-RS: NORTH, RS: SOUTH, -QR: KATA, QR: ANNA, -SQ: EAST, SQ: WEST}
	return d[max(abs(QR), abs(RS), abs(SQ))]

## Returns the six neighbors of a tile.
## If [param length] is specified, offset the returned tiles by that distance.
static func neighbors(location : Vector3, length : float = 0.0) -> Array[Vector3]:
	var n : Array[Vector3]
	for d : Vector3 in DIRECTIONS:
		n.append(location + d * length)
	return n
	
## Returns the direction adjacent to the given direction, either clockwise or
## anti-clockwise.
## [param dir] should be a cubic direction (coordinates bound from [-1, 1])
static func adjacent_direction(dir : Vector3, clockwise : bool) -> Vector3:
	#var offset = Vector3(dir.z, dir.x, dir.y)
	#if not clockwise: offset = Vector3(dir.y, dir.z, dir.x)
	#return dir + offset
	var adjacent : Vector3 = Vector3(dir.y, dir.z, dir.x)
	if not clockwise: adjacent = Vector3(dir.z, dir.x, dir.y)
	return adjacent * -1

## Checks if a cubic is null/intentionally invalid
static func is_null(cubic : Vector3) -> bool:
	return cubic == Vector3.INF

## Returns all spaces in a ring around a cubic coordinate.
static func get_ring(center : Vector3, radius : float, precision : float = 1.0) -> Array[Vector3]:
	var cells : Array[Vector3] = [center + KATA * radius]
	for a in range(6):
		for l in range(radius * precision):
			cells.append(cells[-1] + (DIRECTIONS[a] / precision))
	cells.pop_back()
	return cells

## Returns all spaces bound within a radius around a cubic coordinate.
static func get_area(center : Vector3, radius : float) -> Array[Vector3]:
	var cells : Array[Vector3] = [center]
	for i in range(1, radius+1):
		cells.append_array(get_ring(center, radius))
	return cells

## Returns all space in a line from one cubic coordinate to another.
static func get_line(start : Vector3, end : Vector3, include_end : bool = true) -> Array[Vector3]:
	#start += EPSILON
	end += EPSILON
	var length : float = roundi(distance(start, end))
	#print(length)
	var line : Array[Vector3] = []
	var diff : Vector3 = end - start
	#print(start, end, diff)
	var delta : float = 1 / length
	for i : int in range(length):
		var v := start + diff * i * delta
		line.append(Cubic.snapped(v))
	if include_end:
		var end_snapped : Vector3 = Cubic.snapped(end)
		if not line[-1].is_equal_approx(end_snapped):
			line.append(end_snapped)
	return line
	
## Returns a cubic coordinate of length 1 in the same direction as [param cubic].
static func normalize(cubic : Vector3) -> Vector3:
	var m : float = cubic[cubic.abs().max_axis_index()]
	#print(cubic, ":", m)
	return cubic / abs(m)

## Returns angle in radians of cubic coordinate.
## Angles are calculated as a difference from East ([color=cyan]r[/color]-colored degrees)
static func get_angle(cubic : Vector3) -> float:
	var theta : float = acos((cubic.x - cubic.z) / (2 * euclidean(cubic))) * sign(cubic.y)
	if is_zero_approx(theta) and cubic.x <= 0: theta += PI
	return theta

## Returns the euclidean distance of a cubic coordinate from zero.
static func euclidean(cubic : Vector3) -> float:
	return sqrt((cubic.x ** 2 + cubic.y ** 2 + cubic.z ** 2) / 2)

## Returns a new cubic coordinate at angle [param theta] away from EAST, at
## a distance of [param radius] tiles.
static func from_angle(theta : float, radius : float = 1.0) -> Vector3:
	return Vector3(
		TWO_SQRT_3 * radius * sin(theta + PI_2_3),
		TWO_SQRT_3 * radius * sin(theta),
		TWO_SQRT_3 * radius * sin(theta - PI_2_3)
		)
