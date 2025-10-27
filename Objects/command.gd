@abstract
class_name Command

enum Type{
	NONE,
	AIM,
}

var type : Type

@abstract func execute(beat : int, token : Token, callback : Callable) -> void

static func of_type(_type : Type) -> RefCounted:
	match _type:
		Type.AIM: return Command.Aim
	return Command.None

class Aim:
	extends Command
	
	const TWO_PI : float = 2 * PI
	
	var direction : float
	
	func _init(angle : float) -> void:
		type = Type.AIM
		direction = wrapf(angle, -PI, PI)
	
	static func get_rotate_to(from : float, to : float) -> float:
		from = wrap(from, -PI, PI)
		to = wrapf(to, -PI, PI)
		var secondary : float = to + (sign(-to) * TWO_PI)
		if abs(from - to) > abs(from - secondary):
			return secondary
		else:
			return to
	
	func execute(beat : int, token : Token, callback : Callable) -> void:
		token.tween_to_aim(direction, func():
			token.generate_vision(beat)
			var target_data : Array = token.scan_for_enemy()
			await token.get_tree().create_timer(0.5).timeout
			if len(target_data) > 0:
				token.act_on_enemy(beat, target_data[0], target_data[1])
			await token.get_tree().create_timer(0.5).timeout
			callback.call()
		, 1.0)
	
class None:
	extends Command
	func _init() -> void: type = Type.NONE
	func execute(beat : int, token : Token, callback : Callable) -> void:
		token.focused = false
		
		token.generate_vision(beat)
		var target_data : Array = token.scan_for_enemy()
		await token.get_tree().create_timer(0.5).timeout
		if len(target_data) > 0:
			token.act_on_enemy(beat, target_data[0], target_data[1])
		callback.call()
