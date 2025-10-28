# main.gd
extends Node2D

@onready var player: CharacterBody2D = $player
@onready var takyan: RigidBody2D = $takyan
@onready var camera: Camera2D = $Camera2D
@onready var death_zone: Area2D = $DeathZone
@onready var score_label: Label = $UI/ScoreLabel
@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/GameOverLabel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScoreLabel
@onready var restart_button: Button = $UI/GameOverPanel/RestartButton
@onready var button: Control = $UI/Buttons

var score: int = 0
var is_game_over: bool = false
var initial_player_position = Vector2(548.0, 568.0)
var initial_takyan_position = Vector2(576.0, 500.0)
var has_game_started: bool = false

# Camera boundaries
var camera_limits = {
	"left": 0,
	"right": 1280,
	"top": 0,
	"bottom": 720
}

# Camera follow variables
var camera_target_position: Vector2 = Vector2.ZERO
const CAMERA_SMOOTH_SPEED: float = 5.0
const MAX_CAMERA_ZOOM: float = 1.5
const MIN_CAMERA_ZOOM: float = 1.5

func _ready():
	# Set initial positions
	player.global_position = initial_player_position
	takyan.global_position = initial_takyan_position
	
	# Set camera limits
	set_camera_limits()
	
	# Connect death zone signals
	if death_zone:
		death_zone.body_entered.connect(_on_death_zone_body_entered)
		death_zone.area_entered.connect(_on_death_zone_area_entered)
		print("Death zone signals connected")
	else:
		print("ERROR: Death zone not found!")
	
	# Connect restart button
	restart_button.pressed.connect(_on_restart_button_pressed)
	
	game_over_label.visible = false
	restart_button.text = "Start"
	final_score_label.visible = false
	
	game_over()
	# Initialize UI
	update_score(0)
	
	# Initialize camera position
	camera.global_position = (player.global_position + takyan.global_position) / 2

func _physics_process(delta: float) -> void:
	if is_game_over:
		takyan.global_position = initial_takyan_position
		player.visible = false
	else:
		player.visible = true

func start_game():
	has_game_started = true
	# Apply initial kick to takyan
	var initial_kick_direction = Vector2(0, -1.5)  # Upward kick
	var initial_kick_power = 1.0
	takyan.on_kicked(initial_kick_direction, initial_kick_power)
	print("Game started - Takyan kicked initially!")

func set_camera_limits():
	# Set camera boundaries so it doesn't go outside the level
	camera.limit_left = camera_limits.left
	camera.limit_right = camera_limits.right
	camera.limit_top = camera_limits.top
	camera.limit_bottom = camera_limits.bottom
	
	# Enable camera smoothing
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTH_SPEED

func _process(delta):
	if not is_game_over:
		# Check if takyan falls below death zone as backup
		if takyan.global_position.y > death_zone.global_position.y + 100:
			game_over()
		
		# Update camera to follow both player and takyan
		update_camera(delta)

func update_camera(delta: float):
	if is_game_over:
		return
	
	# Calculate center between player and takyan
	var player_pos = player.global_position
	var takyan_pos = takyan.global_position
	
	# Calculate weighted center (you can adjust weights if needed)
	camera_target_position = (player_pos + takyan_pos) / 2
	
	# Apply camera limits to the target position
	var viewport_size = get_viewport_rect().size
	var half_viewport = viewport_size / 2 / camera.zoom
	
	camera_target_position.x = clamp(camera_target_position.x, 
		camera_limits.left + half_viewport.x, 
		camera_limits.right - half_viewport.x)
	
	camera_target_position.y = clamp(camera_target_position.y, 
		camera_limits.top + half_viewport.y, 
		camera_limits.bottom - half_viewport.y)
	
	# Smooth camera movement using lerp
	camera.global_position = camera.global_position.lerp(camera_target_position, CAMERA_SMOOTH_SPEED * delta)
	
	# Dynamic zoom based on distance between player and takyan
	update_camera_zoom()

func update_camera_zoom():
	var distance = player.global_position.distance_to(takyan.global_position)
	
	# Calculate target zoom based on distance
	# When objects are close: zoom in (higher zoom value)
	# When objects are far: zoom out (lower zoom value)
	var normalized_distance = distance / 800.0  # Adjust 800 to change sensitivity
	var target_zoom = clamp(1.0 + normalized_distance * 0.5, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	
	# Smooth zoom transition
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 0.1)

func _on_death_zone_body_entered(body: Node):
	print("Death zone detected body: ", body.name)
	if body == takyan:
		print("Takyan fell into death zone!")
		game_over()

func _on_death_zone_area_entered(area: Area2D):
	print("Death zone detected area: ", area.name)
	# If takyan uses Area2D for collision
	if area.get_parent() == takyan:
		print("Takyan fell into death zone!")
		game_over()

func game_over():
	if is_game_over:
		return
	
	is_game_over = true
	
	print("Game Over! Final Score: ", score)
	
	# Update final score in UI
	final_score_label.text = "Final Score: " + str(score)
	
	# Show game over panel
	game_over_panel.visible = true
	player.buttons.visible = false
	
func reset_game():
	# Reset game state
	score = 0
	is_game_over = false
	has_game_started = false
	
	# Reset positions to exact coordinates
	player.global_position = initial_player_position
	takyan.global_position = initial_takyan_position
	
	# Reset camera
	camera.global_position = (player.global_position + takyan.global_position) / 2
	camera.zoom = Vector2.ONE
	
	# Start the game again with initial kick
	start_game()
	
	# Reset UI
	update_score(0)
	restart_button.text = "Play Again"
	final_score_label.visible = true
	game_over_panel.visible = false
	game_over_label.visible = true
	player.buttons.visible = true

func update_score(points: int):
	score += points
	score_label.text = "Score: " + str(score)

# This function is called when takyan is kicked
func _on_takyan_kicked():
	if not is_game_over:
		update_score(1)

func _input(event):
	if event.is_action_pressed("ui_accept") and is_game_over:
		reset_game()

func _on_restart_button_pressed() -> void:
	reset_game()
