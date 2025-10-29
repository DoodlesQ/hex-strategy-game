extends Camera2D

var panning : bool = false
var pan_position : Vector2 = Vector2.INF
@export var max_zoom : float = 4.0

func _input(event : InputEvent) -> void:
	if event.is_action_pressed("pan_camera"):
		panning = true
		pan_position = event.position
	if event.is_action_released("pan_camera"): panning = false
	if event is InputEventMouseMotion and panning:
		event = event as InputEventMouseMotion
		position += (pan_position - event.position) / zoom.x
		pan_position = event.position
	if event.is_action("zoom_camera_out") and zoom.x > 1.0:
		zoom -= Vector2.ONE * 0.1
	if event.is_action("zoom_camera_in") and zoom.x < max_zoom:
		zoom += Vector2.ONE * 0.1


func _reset_camera() -> void:
	position = Vector2(800.0, 450.0)
	zoom = Vector2.ONE
