# takyan.gd
extends RigidBody2D

@export var base_kick_force: float = 500.0  # Increased base force
@export var max_vertical_force: float = 800.0  # Increased max vertical
@export var horizontal_influence: float = 0.2  # Reduced horizontal influence
@export var spin_influence: float = 30.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var kick_detection_area: Area2D = $KickDetection
@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: GPUParticles2D = $GPUParticles2D

var last_kick_time: float = 0.0
var kick_cooldown: float = 0.2
var is_active: bool = true
var original_scale: Vector2
var consecutive_kicks: int = 0
var last_kick_height: float = 0.0

func _ready():
	original_scale = sprite.scale if sprite else Vector2.ONE
	
	# Start with gravity enabled and ready to move
	gravity_scale = 1.0
	linear_damp = 0.1
	angular_damp = 0.3
	
	if kick_detection_area:
		kick_detection_area.area_entered.connect(_on_kick_detected)
		kick_detection_area.body_entered.connect(_on_body_entered_kick_detection)
		print("Takyan detection area ready")
	else:
		print("ERROR: Takyan detection area not found!")

func _physics_process(delta):
	check_boundaries()
	update_visual_feedback()

func on_kicked(kick_direction: Vector2, kick_power: float):
	print("💥 TAKYAN KICKED! Direction: ", kick_direction, " Power: ", kick_power)
	
	if not is_active:
		return
	
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_kick_time < kick_cooldown:
		return
	
	last_kick_time = current_time
	
	# Calculate score
	calculate_score()
	
	# Apply force - emphasize vertical movement
	var force = kick_direction * base_kick_force * kick_power
	
	# Make it even more vertical by reducing horizontal component
	force.x *= 0.7  # Reduce horizontal force further
	force.y = clamp(force.y, -max_vertical_force, -max_vertical_force * 0.3)
	
	print("Applying force: ", force)
	
	# Clear any existing velocity and apply new force
	linear_velocity = Vector2.ZERO
	apply_impulse(force)
	
	# Add some spin
	apply_torque_impulse(kick_direction.x * spin_influence * kick_power)
	animate_kick_effect()

func calculate_score():
	consecutive_kicks += 1
	last_kick_height = global_position.y
	
	# Notify main scene about the kick
	if get_parent().has_method("_on_takyan_kicked"):
		get_parent()._on_takyan_kicked()
	
	if consecutive_kicks > 1:
		print("Combo! x", consecutive_kicks)

func _on_kick_detected(area: Area2D):
	print("Takyan detected area: ", area.name)

func _on_body_entered_kick_detection(body: Node):
	print("Takyan detected body: ", body.name)

func check_boundaries():
	var viewport_size = get_viewport().get_visible_rect().size
	
	if global_position.x < 10:
		global_position.x = 10
		linear_velocity.x = abs(linear_velocity.x) * 0.7
	
	if global_position.x > viewport_size.x - 10:
		global_position.x = viewport_size.x - 10
		linear_velocity.x = -abs(linear_velocity.x) * 0.7

func update_visual_feedback():
	if not sprite:
		return
		
	var speed = linear_velocity.length()
	var target_scale = original_scale
	
	if speed > 100:
		var move_direction = linear_velocity.normalized()
		var squash_amount = clamp(speed / 500.0, 0.0, 0.3)
		target_scale.x = original_scale.x * (1.0 + squash_amount * abs(move_direction.x))
		target_scale.y = original_scale.y * (1.0 - squash_amount * 0.5)
	
	sprite.scale = sprite.scale.lerp(target_scale, 0.3)
	
	if speed > 200 and particles:
		particles.emitting = true
	elif particles:
		particles.emitting = false

func animate_kick_effect():
	if not sprite:
		return
		
	var tween = create_tween()
	sprite.modulate = Color.YELLOW
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(sprite, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.1)

func reset_ball(position: Vector2):
	global_position = position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	consecutive_kicks = 0
