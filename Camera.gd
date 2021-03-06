extends Camera

onready var Yaw = get_parent()
var MOVE_SPEED = 0.1
var MOUSE_SENSITIVITY = 0.005

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if Input.is_action_pressed("ui_up"):
		Yaw.translate_object_local(-transform.basis.z.normalized() * MOVE_SPEED)
	if Input.is_action_pressed("ui_down"):
		Yaw.translate_object_local(transform.basis.z.normalized() * MOVE_SPEED)
	if Input.is_action_pressed("ui_left"):
		Yaw.translate_object_local(-transform.basis.x.normalized() * MOVE_SPEED)
	if Input.is_action_pressed("ui_right"):
		Yaw.translate_object_local(transform.basis.x.normalized() * MOVE_SPEED)
		
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
func look_updown_rotation(rotation = 0):
	"""
	Get the new rotation for looking up and down
	"""
	var toReturn = self.get_rotation() + Vector3(rotation, 0, 0)

	##
	## We don't want the player to be able to bend over backwards
	## neither to be able to look under their arse.
	## Here we'll clamp the vertical look to 90° up and down
	toReturn.x = clamp(toReturn.x, PI / -2, PI / 2)

	return toReturn

func look_leftright_rotation(rotation = 0):
	"""
	Get the new rotation for looking left and right
	"""
	return Yaw.get_rotation() + Vector3(0, rotation, 0)

func mouse(event):
	"""
	First person camera controls
	"""
	##
	## We'll use the parent node "Yaw" to set our left-right rotation
	## This prevents us from adding the x-rotation to the y-rotation
	## which would result in a kind of flight-simulator camera
	Yaw.set_rotation(look_leftright_rotation(event.relative.x * -MOUSE_SENSITIVITY))

	##
	## Now we can simply set our y-rotation for the camera, and let godot
	## handle the transformation of both together
	self.set_rotation(look_updown_rotation(event.relative.y * -MOUSE_SENSITIVITY))

func _input(event):
	##
	## We'll only process mouse motion events
	if event is InputEventMouseMotion:
		return mouse(event)
