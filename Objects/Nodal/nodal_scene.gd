extends Node2D

@onready var Radial : Node2D = $Radial

var pressed : bool = false
var active : bool = false
var can_hover : bool = false
var hover : int = 0
var can_menu : bool = false
var menu : int = 0

var tween_Radial : Tween

func get_MenuItems(half : int) -> Array[Node]:
	return Radial.get_node(str(half)).find_children("*", "Area2D")

func set_radial(enable : bool):
	hover = 0
	active = enable
	var process : Node.ProcessMode = process_mode
	if not enable: process = Node.PROCESS_MODE_DISABLED
	for half : int in [1, 2]:
		var n : Area2D = Radial.get_node(str(half))
		n.process_mode = process
		if enable:
			tween_Half_Do(half, Color.WHITE, 1.0, false, true)

func radial_tween(tween_in : float, tween_out : float = INF) -> void:
	if tween_Radial: tween_Radial.kill()
	tween_Radial = Radial.create_tween()
	tween_Radial.set_trans(Tween.TRANS_QUART)
	tween_Radial.set_ease(Tween.EASE_IN)
	tween_Radial.tween_property(Radial, "scale", Vector2(tween_in, tween_in), 0.15)
	if is_finite(tween_out):
		tween_Radial.set_ease(Tween.EASE_OUT)
		tween_Radial.tween_property(Radial, "scale", Vector2(tween_out, tween_out), 0.15)
	
func _ready() -> void:
	Radial.scale = Vector2.ZERO
	set_radial(false)
	var menu_items : Array[Array] = [get_MenuItems(1), get_MenuItems(2)]
	for m : Array[Node] in menu_items:
		for i : int in range(4):
			m[i].input_event.connect(_on_menu_item_input_event.bind(i).unbind(1))

func _on_initial_radius_input_event(_viewport : Node, event : InputEvent, _shape_idx : int) -> void:
	if event as InputEventMouseMotion:
		if active:
			can_hover = true
	if event as InputEventMouseButton:
		if not active:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if pressed and not event.pressed:
					$Dot.scale = Vector2(16.0, 16.0)
					radial_tween(1.05, 1.0)
					set_radial(true)
					tween_Radial.tween_callback(func():
						pass
					)
				elif event.pressed:
					$Dot.scale = Vector2(12.0, 12.0)
					pressed = true

func _on_capture_radius_exited() -> void:
	$Dot.scale = Vector2(16.0, 16.0)
	pressed = false
	can_hover = false
	set_radial(false)
	radial_tween(0.0)

var tween_Half : Dictionary

func tween_Half_Do(half : int, color : Color, scalar : float, do_menu : bool, instant : bool = false) -> void:
	var time : float = 0.3 if not instant else 0.0
	if half in tween_Half and tween_Half[half]: tween_Half[half].kill()
	var half_node : Area2D = Radial.get_node(str(half))
	tween_Half[half] = half_node.create_tween()
	tween_Half[half].set_trans(Tween.TRANS_QUART)
	tween_Half[half].set_ease(Tween.EASE_IN_OUT)
	tween_Half[half].tween_property(half_node, "modulate", color, time)
	tween_Half[half].set_parallel()
	tween_Half[half].tween_property(half_node, "scale", Vector2(scalar, scalar), time)
	var mscale : float = 1 / scalar if do_menu else 2.0
	if half == 2: mscale *= -1
	var mcolor : Color = Color(color.r, color.g, color.b, color.a if do_menu else 0.0)
	for m : Node in get_MenuItems(half):
		tween_Half[half].tween_property(m, "modulate", mcolor, time)
		tween_Half[half].tween_property(m, "scale", Vector2(mscale, abs(mscale)), time)

func _radial_left_entered() -> void:
	if can_hover:
		hover = 1
		can_menu = false
		tween_Half_Do(1, Color.WHITE, 0.75, true)
		tween_Half_Do(2, Color(0.5, 0.5, 0.5, 0.5), 1.0, false)
		get_tree().create_timer(0.15).timeout.connect(func():
			if hover == 1: can_menu = true
		)
		
	
func _radial_right_entered() -> void:
	if can_hover:
		hover = 2
		can_menu = false
		tween_Half_Do(2, Color.WHITE, 0.75, true)
		tween_Half_Do(1, Color(0.5, 0.5, 0.5, 0.5), 1.0, false)
		get_tree().create_timer(0.1).timeout.connect(func():
			if hover == 2: can_menu = true
		)

func _on_radial_deadzone_entered() -> void:
	if can_hover:
		hover = 0
		get_tree().create_timer(0.5).timeout.connect(func():
			if hover == 0:
				can_menu = false
				tween_Half_Do(1, Color.WHITE, 1.0, false)
				tween_Half_Do(2, Color.WHITE, 1.0, false)
		)

var tween_Menu : Dictionary

func get_menu(m : int) -> Node:
	var id : int = m & 0b11
	var side : int = m >> 2
	return Radial.get_node(str(side)).get_node(str(id))

func _on_menu_item_input_event(_viewport : Node, event : InputEvent, id: int) -> void:
	if event as InputEventMouseMotion:
		if can_menu and hover:
			var new_menu : int = (hover << 2) + id
			if new_menu != menu:
				menu = (hover << 2) + id
				if menu in tween_Menu: tween_Menu[menu].kill()
				var tween_node : Area2D = get_menu(menu)
				tween_Menu[menu] = tween_node.create_tween()
				tween_Menu[menu].set_trans(Tween.TRANS_QUART)
				tween_Menu[menu].set_ease(Tween.EASE_IN_OUT)
				var side : int = int(tween_node.get_parent().name)
				var scalar : float = 2.0
				if side == 2: scalar *= -1
				tween_Menu[menu].tween_property(tween_node, "scale", Vector2(scalar, abs(scalar)), 0.2)
				#print(menu)
				for m in tween_Menu.keys():
					#print(m)
					if m == menu: continue
					#print("KILL")
					tween_Menu[m].kill()
					var off_node : Area2D = get_menu(m)
					tween_Menu[m] = off_node.create_tween()
					tween_Menu[m].set_trans(Tween.TRANS_QUART)
					tween_Menu[m].set_ease(Tween.EASE_IN_OUT)
					side = int(off_node.get_parent().name)
					scalar = 4.0/3.0
					if side == 2: scalar *= -1
					tween_Menu[m].tween_property(off_node, "scale", Vector2(scalar, abs(scalar)), 0.2)
