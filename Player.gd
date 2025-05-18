# This script works well for first person and third person 3D games
# Modified to be based off the Quake/Source engine
extends CharacterBody3D

# Sprinting & Speed
@export var WALK_SPEED = 5.0
@export var SPRINT_SPEED = 8.0
var speed

@export var JUMP_VELOCITY = 3.5
@export var SENSITIVITY = 0.005

# Head bobbing variables
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

# Field of View
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# 1 Frame Window For Frictionless Bhopping
var time_spent_on_floor = 0.0

# Movement action names
@export var move_fwd : String
@export var move_back : String
@export var move_left : String
@export var move_right : String
@export var jump : String

# Can change values of vars
# Get the gravity from the project settings to be synced withj RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle Jump. - Allows for Bhopping
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle Sprint.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions!
	# AKA, replace ui_left with strafe_left for example
	var input_dir = Input.get_vector(move_left, move_right, move_fwd, move_back)
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		time_spent_on_floor += 1.0 # If gets to 2.0, then begin to apply friction
		clamp(time_spent_on_floor, 0.0, 2.0) # Prevents overflow if player stays on ground for a long time
	else:
		time_spent_on_floor = 0.0
	
	if (time_spent_on_floor > 1.0):
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else: 
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		# Interpolate, aka change speed incrementally
		# Takes 3 variables: Initial velocity, target velocity, then the decimal percentage
		# of distance between init and target velocities we want to cover on each step
		# Percentage amt changes how much control the player has in the air, essentially
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
		
	# Head bob effect
	# Increment t_bob every physics process / tick
	# Delta is how much time has elapsed since last tick
	# Multiplied by the speed of our character, aka head bob more often the faster they go
	# Lastly, make sure only head bobbing when the character is on the ground/floor
	# Will also set local position of camera to result of the head bob function (changes only y val)
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	# Clamps the velocity
	# Min of 0.5, maximum is SPRINT_SPEED times 2
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	# Instead of going -1 to 1 like normal sine, now goes from -BOB_AMP to BOB_AMP
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ/2) * BOB_AMP
	return pos
