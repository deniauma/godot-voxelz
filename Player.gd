extends KinematicBody


const GRAVITY = -24.5
const MAX_SPEED = 15
const JUMP_SPEED = 10
const ACCEL= 4.5
const DEACCEL= 16
const MAX_SLOPE_ANGLE = 40
var vel = Vector3()

onready var cam = $camera
var MOVE_SPEED = 0.1
var MOUSE_SENSITIVITY = 0.005

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	self.add_to_group("player")

func _physics_process(delta):
	var dir = Vector3()
	var cam_xform = cam.get_global_transform()
	var input_movement_vector = Vector2()
	
	if Input.is_key_pressed(KEY_P):
		print(str($voxPos.global_transform.origin))
	
	if Input.is_action_pressed("move_forward"):
		input_movement_vector.y += 1
		#self.translate_object_local(-transform.basis.z.normalized() * MOVE_SPEED)
	if Input.is_action_pressed("move_back"):
		input_movement_vector.y -= 1
		#self.translate_object_local(transform.basis.z.normalized() * MOVE_SPEED)
	if Input.is_action_pressed("strafe_left"):
		input_movement_vector.x -= 1
		#self.translate_object_local(-transform.basis.x.normalized() * MOVE_SPEED)
	if Input.is_action_pressed("strafe_right"):
		input_movement_vector.x += 1
		#self.translate_object_local(transform.basis.x.normalized() * MOVE_SPEED)
		
	input_movement_vector = input_movement_vector.normalized()

	dir += -cam_xform.basis.z.normalized() * input_movement_vector.y
	dir += cam_xform.basis.x.normalized() * input_movement_vector.x
	
	# Jumping
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			vel.y = JUMP_SPEED
	
	dir.y = 0
	dir = dir.normalized()

	vel.y += GRAVITY*delta

	var hvel = vel
	hvel.y = 0

	var target = dir
	target *= MAX_SPEED

	var accel
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.linear_interpolate(target, accel*delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel,Vector3(0,1,0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
		
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
func look_updown_rotation(rotation = 0):
	"""
	Get the new rotation for looking up and down
	"""
	var toReturn = cam.get_rotation() + Vector3(rotation, 0, 0)
	toReturn.x = clamp(toReturn.x, PI / -2, PI / 2)

	return toReturn

func look_leftright_rotation(rotation = 0):
	"""
	Get the new rotation for looking left and right
	"""
	return self.get_rotation() + Vector3(0, rotation, 0)

func mouse(event):
	"""
	First person camera controls
	"""
	##
	## We'll use the parent node "Yaw" to set our left-right rotation
	## This prevents us from adding the x-rotation to the y-rotation
	## which would result in a kind of flight-simulator camera
	self.set_rotation(look_leftright_rotation(event.relative.x * -MOUSE_SENSITIVITY))

	##
	## Now we can simply set our y-rotation for the camera, and let godot
	## handle the transformation of both together
	cam.set_rotation(look_updown_rotation(event.relative.y * -MOUSE_SENSITIVITY))

func _input(event):
	##
	## We'll only process mouse motion events
	if event is InputEventMouseMotion:
		return mouse(event)
