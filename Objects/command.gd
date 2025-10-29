@abstract
class_name Command

var type : Type

enum Type{
	UNDEFINED,
	WATCH,
	AIM,
	AIM_TARGET
}

static func of_type(_type : Type) -> RefCounted:
	match _type:
		Type.AIM: return Command.Aim
		Type.AIM_TARGET: return Command.Aim_Target
		Type.WATCH: return Command.Watch
	return Command.Undefined

static func is_overwritable(_type : Type) -> bool:
	return _type in [Type.UNDEFINED, Type.WATCH, Type.AIM, Type.AIM_TARGET]

@abstract func execute(beat : int, token : Token, callback : Callable) -> void

class Aim:
	extends Command
	
	const TWO_PI : float = 2 * PI
	
	var target : Vector3 = Vector3.INF
	
	var direction : float = INF
	
	func _init(angle : float) -> void:
		type = Type.AIM
		direction = angle
	
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
			token.target_tile = target
			token.generate_vision(beat, false)
			var targeted : Vector3 = token.scan_for_enemy()
			if targeted.is_finite():
				token.act_on_enemy(beat, targeted)
			elif token.alert:
				token.alert = false
			callback.call()
		, 1.0)

class Aim_Target:
	extends Aim
	
	func _init(_target : Vector3) -> void:
		type = Type.AIM_TARGET
		target = _target
	
	func execute(beat : int, token : Token, callback : Callable) -> void:
		var token_at : Vector3 = token.backsolve(beat)
		direction = Cubic.get_angle(target - token_at)
		super.execute(beat, token, callback)
	
class Watch:
	extends Command
	func _init() -> void: type = Type.WATCH
	func execute(beat : int, token : Token, callback : Callable) -> void:
		token.focused = false
		token.target_tile = Vector3.INF
		token.generate_vision(beat, false)
		var targeted : Vector3 = token.scan_for_enemy()
		if targeted.is_finite():
			token.act_on_enemy(beat, targeted)
		callback.call()

class Undefined:
	extends Command
	func _init() -> void: type = Type.UNDEFINED
	func execute(_beat : int, _token : Token, callback : Callable) -> void:
		callback.call()
