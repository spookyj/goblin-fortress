extends CharacterBody2D

const SPEED := 110.0
const RUN_MULTIPLIER := 2.0

var input: Vector2
var last_direction: Vector2 = Vector2.DOWN  # Default facing down
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func get_input() -> Vector2:
	input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return input.normalized()

func _physics_process(delta):
	var player_input := get_input()
	var current_speed := SPEED

	if Input.is_action_pressed("run"):  # "run" should be mapped to Shift in Input Map
		current_speed *= RUN_MULTIPLIER

	velocity = player_input * current_speed
	move_and_slide()

	update_animation(player_input)

func update_animation(direction: Vector2):
	if direction != Vector2.ZERO:
		last_direction = direction  # Save last movement direction

		if abs(direction.x) > abs(direction.y):
			animated_sprite.play("walk_left")
			animated_sprite.flip_h = direction.x > 0
		else:
			animated_sprite.flip_h = false
			if direction.y > 0:
				animated_sprite.play("walk_down")
			else:
				animated_sprite.play("walk_up")
	else:
		# Idle animation based on last movement direction
		if abs(last_direction.x) > abs(last_direction.y):
			animated_sprite.play("idle_side")
			animated_sprite.flip_h = last_direction.x > 0
		else:
			animated_sprite.flip_h = false
			if last_direction.y > 0:
				animated_sprite.play("idle_down")
			else:
				animated_sprite.play("idle_up")
