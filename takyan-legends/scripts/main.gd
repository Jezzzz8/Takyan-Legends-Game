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
	
	# Start the game immediately with takyan moving
	start_game()
	
	# Initialize UI
	update_score(0)
	game_over_panel.visible = false

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
	
	# Optional: Enable camera smoothing
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 3.0

func _process(delta):
	if not is_game_over:
		# Check if takyan falls below death zone as backup
		if takyan.global_position.y > death_zone.global_position.y + 100:
			game_over()
		
		# Update camera to follow both player and takyan
		update_camera()

func update_camera():
	# Calculate center between player and takyan
	var center_position = (player.global_position + takyan.global_position) / 2
	
	# Apply camera limits to the center position
	center_position.x = clamp(center_position.x, camera_limits.left + get_viewport().size.x / 2 / camera.zoom.x, 
							  camera_limits.right - get_viewport().size.x / 2 / camera.zoom.x)
	center_position.y = clamp(center_position.y, camera_limits.top + get_viewport().size.y / 2 / camera.zoom.y, 
							  camera_limits.bottom - get_viewport().size.y / 2 / camera.zoom.y)
	
	# Smooth camera movement
	camera.global_position = camera.global_position.lerp(center_position, 0.1)
	
	# Optional: Zoom out when objects are far apart
	var distance = player.global_position.distance_to(takyan.global_position)
	var target_zoom = clamp(Vector2.ONE * (1.0 + distance / 500.0), Vector2.ONE, Vector2.ONE * 1.5)
	camera.zoom = camera.zoom.lerp(target_zoom, 0.1)

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

func reset_game():
	# Reset game state
	score = 0
	is_game_over = false
	has_game_started = false
	
	# Reset positions to exact coordinates
	player.global_position = initial_player_position
	takyan.global_position = initial_takyan_position
	
	# Start the game again with initial kick
	start_game()
	
	# Reset UI
	update_score(0)
	game_over_panel.visible = false

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
