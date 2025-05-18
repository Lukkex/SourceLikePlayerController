# This script works well for first person and third person 3D games
# Modified to be based off the Quake/Source engine
extends CharacterBody3D

# Sprinting & Speed
@export var move_enabled = true
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
@export var bhop_frames = 1.0

# Whether bunnyhopping should be 'additive' - whether it should converge to the player's wishdir
@export var additive_bhop : bool = true

# Friction
@export var friction : float = 6
# Acceleration when grounded
@export var grounded_acceleration : float = 250
# Acceleration when in the air
@export var air_acceleration : float = 85
# Max velocity on the ground
@export var max_grounded_velocity : float = 10
# Max velocity in the air
@export var max_air_velocity : float = 1.5

# Movement action names
@export var move_fwd : String
@export var move_back : String
@export var move_left : String
@export var move_right : String
@export var jump : String

# Can change values of vars
# Get the gravity from the project settings to be synced withj RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")  #9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D

## Called when program is first ran
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Called anytime the player does any sort of input
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))


## Main physics function - called after _ready()
func _physics_process(delta):
	# Update the frame counter - allows for frame-perfect bhop to bypass friction
	if is_on_floor():
		time_spent_on_floor += 1.0 # If gets to 2.0, then begin to apply friction
		clamp(time_spent_on_floor, 0.0, bhop_frames * 2) # Prevents overflow if player stays on ground for a long time
	else:
		time_spent_on_floor = 0.0
	
	# Calculate the new velocity for the move_and_slide() function to use
	velocity = calc_new_velocity(velocity, delta)
		# Head bob effect
	# Increment t_bob every physics process / tick
	# Delta is how much time has elapsed since last tick
	# Multiplied by the speed of our character, aka head bob more often the faster they go
	# Lastly, make sure only head bobbing when the character is on the ground/floor
	# Will also set local position of camera to result of the head bob function (changes only y val)
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = head_bob(t_bob)
	
	# FOV
	# Clamps the velocity
	# Min of 0.5, maximum is SPRINT_SPEED times 2
	#var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	#var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	var target_fov = BASE_FOV + FOV_CHANGE * velocity.length()
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()

## Head bobbing function - used for moving camera up and down
func head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	# Instead of going -1 to 1 like normal sine, now goes from -BOB_AMP to BOB_AMP
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ/2) * BOB_AMP
	return pos
	
func calc_new_velocity(prev_velocity, delta):
	var is_grounded = is_on_floor()
	
	# Handle Sprint.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions!
	# AKA, replace ui_left with strafe_left for example
	var input_dir = Input.get_vector(move_left, move_right, move_fwd, move_back)
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() # Essentially, acts as "wish" direction
	
	if (time_spent_on_floor > bhop_frames):
		if direction:
			var drop = direction.length() * speed * friction * delta
			prev_velocity *= max((direction.length() * speed) - drop, 0) / (direction.length() * speed)
		else:
			# If grounded and not inputting a direction, slow down to 0
			prev_velocity.x = lerp(prev_velocity.x, direction.x * speed, delta * friction)
			prev_velocity.z = lerp(prev_velocity.z, direction.z * speed, delta * friction)
	else:
		# If bunnyhopping is additive, we should use the air velocity and accelerate values for all frames
		# that the bunnyhop is possible
		if not additive_bhop:
			is_grounded = false
	
	var max_vel = max_grounded_velocity if is_grounded else max_air_velocity
	var acceleration = grounded_acceleration if is_grounded else air_acceleration
	
	var new_velocity = accelerate(direction, prev_velocity, acceleration, max_vel, delta)
	
	# Add the gravity.
	if not is_on_floor():
		new_velocity.y -= gravity * delta
	
	# Handle Jump. - Allows for Bhopping
	if Input.is_action_pressed("jump") and is_on_floor():
		new_velocity.y = JUMP_VELOCITY
	
	return new_velocity

## Acceleration function based off Quake engine's implementation
func accelerate(aDir, prevVelocity, acceleration, max_vel, delta):
	var projectedVel = prevVelocity.dot(aDir) # Calculate the projected velocity for next frame given the acceleration direction and previous velocity
	var aVel = clamp(max_vel - projectedVel, 0, acceleration * delta) # Calculate accelerated velocity given the max velocity, proj velocity, & curr acceleration
	return prevVelocity + aDir * aVel # Return prev velocity in addition to new velocity (after acceleration)
