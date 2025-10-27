extends CharacterBody2D

const SPEED = 150.0
const RUN_SPEED = 300.0
const JUMP_VELOCITY = -300.0

@onready var kick_area: Area2D = $Kick_Area
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_kicking = false
var kick_timer = 0.0
const KICK_DURATION = 0.1
var current_speed = SPEED
var air_kick_momentum = Vector2.ZERO

# Anti-spam variables
var can_kick = true
var kick_cooldown_timer = 0.0
const KICK_COOLDOWN = 0.3

# Kick analyzer variables
var kick_quality = "missed"
var kick_hit_detected = false

# Quality thresholds (relative to kick area center)
const PERFECT_DISTANCE = 75.0   # Pixels from center
const GREAT_DISTANCE = 50.0     # Pixels from center  
const GOOD_DISTANCE = 100.0      # Pixels from center

func _ready():
	if kick_area:
		kick_area.area_entered.connect(_on_kick_area_area_entered)
		kick_area.body_entered.connect(_on_kick_area_body_entered)
		print("Kick area signals connected")
	else:
		print("ERROR: Kick area not found!")

func _process(delta: float) -> void:
	apply_kick_rewards(kick_quality)

func _physics_process(delta: float) -> void:
	# Handle kick timer
	if is_kicking:
		kick_timer -= delta
		if kick_timer <= 0:
			is_kicking = false
			air_kick_momentum = Vector2.ZERO
			if not kick_hit_detected:
				kick_quality = "missed"
				analyze_kick_quality()
	
	# Handle kick cooldown
	if not can_kick:
		kick_cooldown_timer -= delta
		if kick_cooldown_timer <= 0:
			can_kick = true
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_kicking:
		velocity.y = JUMP_VELOCITY
	
	var direction := Input.get_axis("move_left", "move_right")
	
	# Handle kick input
	if Input.is_action_just_pressed("kick") and can_kick and not is_kicking:
		start_kick()
	
	# Handle run input
	if Input.is_action_pressed("run") and not is_kicking:
		current_speed = RUN_SPEED
	else:
		current_speed = SPEED
	
	# Flip sprite based on direction
	if direction > 0:
		animated_sprite.flip_h = false
		if kick_area:
			kick_area.position.x = abs(kick_area.position.x)
	elif direction < 0:
		animated_sprite.flip_h = true
		if kick_area:
			kick_area.position.x = -abs(kick_area.position.x)
	
	# Animation states
	if is_kicking:
		if is_on_floor():
			animated_sprite.play("kick")
		else:
			animated_sprite.play("fly_kick")
	elif is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			if current_speed == RUN_SPEED:
				animated_sprite.play("run")
			else:
				animated_sprite.play("walk")
	else:
		animated_sprite.play("jump")
	
	# Movement logic
	if not is_kicking:
		if direction:
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
	else:
		if not is_on_floor():
			if air_kick_momentum != Vector2.ZERO:
				velocity.x = air_kick_momentum.x
			if direction:
				velocity.x = move_toward(velocity.x, direction * current_speed * 0.7, current_speed * delta * 2)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 3)

	move_and_slide()

func start_kick():
	is_kicking = true
	kick_timer = KICK_DURATION
	can_kick = false
	kick_cooldown_timer = KICK_COOLDOWN
	
	# Reset kick analyzer
	kick_quality = "missed"
	kick_hit_detected = false
	
	# Play appropriate kick animation
	if is_on_floor():
		animated_sprite.play("kick")
	else:
		animated_sprite.play("fly_kick")
	
	if not is_on_floor():
		air_kick_momentum = velocity
	
	if kick_area:
		kick_area.monitoring = true
	
	await get_tree().create_timer(0.1).timeout
	if kick_area:
		kick_area.monitoring = false

func calculate_kick_quality(hit_position: Vector2) -> String:
	# Calculate distance from kick area center
	var kick_center = kick_area.global_position
	var distance = hit_position.distance_to(kick_center)
	
	if distance <= GREAT_DISTANCE:
		return "great"
	elif distance <= PERFECT_DISTANCE:
		return "perfect"
	elif distance <= GOOD_DISTANCE:
		return "good"
	else:
		return "missed"

func analyze_kick_quality():
	print("Final kick quality: ", kick_quality)
	apply_kick_rewards(kick_quality)

func apply_kick_rewards(quality: String):
	match quality:
		"perfect":
			$Label.text = "Perfect"
			print("🎯 PERFECT KICK! +15 points")
		"great":
			$Label.text = "Great"
			print("⭐ GREAT KICK! +10 points")
		"good":
			$Label.text = "Good"
			print("👍 GOOD KICK! +5 points")
		"missed":
			$Label.text = "Missed"
			print("❌ MISSED KICK! No points")

func _on_kick_area_area_entered(area: Area2D) -> void:
	var hit_position = area.global_position
	kick_quality = calculate_kick_quality(hit_position)
	kick_hit_detected = true
	
	print("🎯 KICK HIT AREA: ", area.name, " - Quality: ", kick_quality)
	
	if area.get_parent().has_method("on_kicked"):
		var kick_direction = Vector2(0, -1.5)
		if animated_sprite.flip_h:
			kick_direction.x = -0.2
		else:
			kick_direction.x = 0.2
		
		var kick_power = 1.5 if current_speed == RUN_SPEED else 1.0
		
		# Apply quality multiplier
		if kick_quality == "perfect":
			kick_power *= 1.5
		elif kick_quality == "great":
			kick_power *= 1.3
		elif kick_quality == "good":
			kick_power *= 1.1
		
		area.get_parent().on_kicked(kick_direction, kick_power)

func _on_kick_area_body_entered(body: Node2D) -> void:
	var hit_position = body.global_position
	kick_quality = calculate_kick_quality(hit_position)
	kick_hit_detected = true
	
	print("🎯 KICK HIT BODY: ", body.name, " - Quality: ", kick_quality)
	
	if body.has_method("on_kicked"):
		var kick_direction = Vector2(0, -1.5)
		if animated_sprite.flip_h:
			kick_direction.x = -0.2
		else:
			kick_direction.x = 0.2
		
		var kick_power = 1.5 if current_speed == RUN_SPEED else 1.0
		
		# Apply quality multiplier
		if kick_quality == "perfect":
			kick_power *= 1.5
		elif kick_quality == "great":
			kick_power *= 1.3
		elif kick_quality == "good":
			kick_power *= 1.1
		
		body.on_kicked(kick_direction, kick_power)
