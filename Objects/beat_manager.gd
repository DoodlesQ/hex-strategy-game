@tool
@icon("res://icons/TileManager.svg")
extends HexManager
class_name BeatManager

var beat_editing : int = 0
var beat_perform : int = -1

var can_edit : bool = true

var beat_confirm_sum : int = 0
var beat_confirmed : int = 0
var beat_step : int = 0

var selected : Token = null
var selected_moves : Array[Vector3] = []

var tokens : Array[Token] = []

enum Tool {MOVE, COMMAND}

var tool : Tool = Tool.COMMAND
var do_command : bool = false
var command : Command.Type

var control_faction : Token.Faction = Token.Faction.ONE

func _ready() -> void:
	for cell in get_cells():
		if cell as Token: tokens.append(cell)

func set_selected(location : Vector3) -> void:
	if selected:
		selected.selected = false
		selected.action = Token.Action.NONE
	var token : Token = get_cell_at(location)
	if token and token.faction == control_faction:
		selected = token
		token.selected = true
		if tool == Tool.MOVE:
			token.action = Token.Action.MOVING
			beat_editing = token.last_move_set + 1
			selected_moves = token.get_all_moves()
		else:
			token.action = Token.Action.AIMING
	else:
		if selected and tool == Tool.MOVE: selected.validate()
		selected = null
	queue_redraw()
	
func _input(event : InputEvent) -> void:
	if not can_edit: return
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		if event.is_action("select"):
			var mouse : Vector3 = Cubic.snapped(get_mouse_cubic())
			
			if tool == Tool.MOVE:
				var do_select : bool = true
				if selected:
					if mouse in selected_moves:
						selected.set_move(beat_editing, mouse)
						selected_moves = selected.get_all_moves()
						beat_editing += 1
						selected.queue_redraw()
						queue_redraw()
						do_select = false
				if do_select: set_selected(mouse)
				
			if tool == Tool.COMMAND:
				if selected and do_command:
					confirm_command()
				else:
					for token : Token in tokens:
						if token.faction != control_faction: continue
						var at : Vector3 = token.backsolve(beat_editing)
						if not selected and mouse.is_equal_approx(at):
							# Do command
							print("COMMANDING ", token)
							# Do aim
							set_selected(token.cubic)
							do_command = false
							#token.focused = true
							var i : int = -20
							var buttons : Array[Button] = []
							var options : Array[Command.Type] = [Command.Type.UNDEFINED]
							options.append_array(token.command_options)
							for type : Command.Type in options:
								buttons.append(Button.new())
								buttons[-1].position = token.position + Vector2(i, 0)
								buttons[-1].text = str(type)
								buttons[-1].pressed.connect(func():
									command = type
									do_command = true
									for b : Button in buttons:
										b.queue_free()
								)
								add_child(buttons[-1])
								i += 40
			
		if event.is_action("move_undo"):
			if tool == Tool.MOVE:
				if selected and beat_editing > 0:
					selected.pop_move()
					selected_moves = selected.get_all_moves()
					beat_editing -= 1
					selected.queue_redraw()
					queue_redraw()
		
		if event.is_action("change_tool"):
			set_selected(Vector3.INF)
			if tool == Tool.COMMAND:
				tool = Tool.MOVE
				beat_editing += 1
			elif tool == Tool.MOVE:
				tool = Tool.COMMAND
				beat_editing -= 1
		
		if event.is_action("change_faction"):
			if control_faction == Token.Faction.ONE:
				control_faction = Token.Faction.TWO
			else:
				control_faction = Token.Faction.ONE
		
		if tool == Tool.COMMAND:
			if event.is_action("beat_cycle_up"):
				beat_editing += 1 if beat_editing < 3 else -3
			if event.is_action("beat_cycle_down"):
				beat_editing -= 1 if beat_editing > 0 else -3

func remove_token(token : Token) -> void:
	assert(token in tokens, "Cannot remove token %s, not in token list." % token)
	tokens.erase(token)
	confirm_beat_complete(token.cubic)
	remove_cell_at(token.cubic)

func confirm_turn() -> void:
	var invalid_tokens : Array[Token] = validate_tokens()
	if invalid_tokens.size() == 0:
		can_edit = false
		selected = null
		
		beat_step = 0
		beat_perform = 0
		for token : Token in tokens:
			token.action = Token.Action.NONE
			token.facing = token.last_facing
		perform_beat_step()

func confirm_beat_complete(id : Vector3 = Vector3.INF) -> void:
	print("CONFIRMATION ", (str(id) if id.is_finite() else ""))
	beat_confirmed += 1
	print(beat_confirmed, " vs ", beat_confirm_sum)
	if beat_confirmed == beat_confirm_sum:
		if beat_step == 0:
			for token : Token in tokens:
				token.cubic = token.backsolve(beat_perform)
			beat_step += 1
		elif beat_step == 1:
			beat_step = 0
			beat_perform += 1
		if beat_perform >= 4:
			print("TURN COMPLETED")
			for token : Token in tokens:
				token.reset()
			queue_redraw()
			can_edit = true
		else: perform_beat_step()

signal perform_beat(beat : int)
func perform_beat_step() -> void:
	print("PERFORM BEAT ", beat_perform, " STEP ", beat_step)
	beat_confirmed = 0
	beat_confirm_sum = 0
	for token : Token in tokens:
		if beat_step == 0:
			token.perform_move_to_beat(beat_perform)
		else:
			token.perform_command_to_beat(beat_perform)
		beat_confirm_sum += 1
	perform_beat.emit(beat_perform)

func validate_tokens() -> Array[Token]:
	var invalid : Array[Token] = []
	for token : Token in tokens:
		if not token.validate(): invalid.append(token)
	return invalid

func confirm_command() -> void:
	var c : Command
	match command:
		Command.Type.AIM:
			c = Command.Aim.new(selected.facing)
		Command.Type.AIM_TARGET:
			c = Command.Aim_Target.new(selected.target_tile)
		Command.Type.WATCH:
			c = Command.Watch.new()
		_:
			c = Command.Undefined.new()
	selected.facing = selected.last_facing
	selected.target_tile = Vector3.INF
	selected.beats[beat_editing].command = c
	#print("COMMANDSET: ", selected.beats[beat_editing].command.direction)
	set_selected(Vector3.INF)
	do_command = false
	

func _draw() -> void:
	super._draw()
	if can_edit:
		if tool == Tool.MOVE:
			if selected:
				for m : Vector3 in selected_moves:
					draw_circle(
						Cubic.to_real(m, grid), 
						grid.inner_radius, 
						Color(1.0, 1.0, 1.0, 0.5)
					)
			for token : Token in tokens:
				if token.faction == control_faction:
					Token.draw_path(self, token, token.position, 0.25)
		
		if tool == Tool.COMMAND:
			for token : Token in tokens:
				if token.faction == control_faction:
					Token.draw_path(self, token, token.position, 0.125)
					for i : int in range(4):
						var b : Vector3 = token.backsolve(i)
						var a : float = 0.2 if i != beat_editing else 0.5
						draw_circle(Cubic.to_real(b, grid), 50 * a, Color(1,1,1,a))
						var com : Command = token.backsolve_command(i)
						var draw_cone : bool = false
						var dir : float = INF
						match com.type:
							Command.Type.AIM:
								draw_cone = true
								dir = com.direction
							Command.Type.AIM_TARGET:
								draw_cone = true
								dir = Cubic.get_angle(com.target - b)
						if draw_cone:
							Token.draw_vision_cone(self, token, dir, Cubic.to_real(b, grid), a * 0.5)
						elif com.type == Command.Type.WATCH:
							Token.draw_periphery(self, token, Cubic.to_real(b, grid), a * 0.5)
						

		var c : float = 1.0 if tool == Tool.COMMAND else 0.0
		var d : float = 1.0 if do_command else 0.0
		draw_circle(get_local_mouse_position(), 4, Color(c, 1.0-c, d, 0.5))

func _process(_delta : float) -> void:
	if tool == Tool.COMMAND and selected:
		if do_command:
			match command:
				Command.Type.AIM, Command.Type.AIM_TARGET:
					var aim_from : Vector3 = selected.backsolve(beat_editing)
					var target_tile : Vector3 = Cubic.snapped(get_mouse_cubic())
					if target_tile != aim_from:
						selected.target_tile = target_tile
						selected.facing = Cubic.get_angle(target_tile - aim_from)
						selected.calculate_view_cones()
						selected.generate_vision(beat_editing)
						selected.queue_redraw()
				_:
					confirm_command()
			
	queue_redraw()
