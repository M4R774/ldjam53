extends CharacterBody3D

signal player_died
signal player_ammo_updated
signal player_health_updated

@export var speed = 10
@export var jump_velocity = 4.5
@export var camera: Camera3D
@export var shotgunSound: AudioStreamPlayer3D
@export var meleeSound: AudioStreamPlayer3D
@export var movementSound: AudioStreamPlayer3D
@export var damageSound: AudioStreamPlayer3D
@export var friction = 0.2

var direction = Vector3.ZERO
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var velocity_y = 0
var acceleration = 1

# gamepad controls
var is_using_gamepad = true
var left_stick_turn = Vector2(0,0)
var right_stick_look = Vector2(0,0)

# shooting
@onready var raycast = $RayCast3D
var shotgunRaycastPos = Vector3(0.14, 0.622, -1.401)
var shotgun_range = 10
var meleeRaycastPos = Vector3(0.14, 0.622, -0.38)
var melee_range = 1.5
var ammo: int = 10

# rolling
var is_rolling = false
var roll_factor = 1

var health_percentage = 100

func _ready():
	init_mac()
	if camera == null:
		camera = get_viewport().get_camera_3d()


func _physics_process(delta):
	if out_of_bounds():
		die()

	# player movement and rotation
	update_position(delta)
	if is_using_gamepad:
		update_gamepad_rotation(delta)
	else:
		update_rotation()
	# player actions
	update_shooting()


func out_of_bounds():
	return self.position.y < -10


func die():
	if !damageSound.is_playing():
		damageSound.play()
	emit_signal("player_died")


# checking if player is using kb and mouse or gamepad
# this should only be run for player 1, as player 2 is always on gamepad
# player 1 might be on kb and player 2 on gamepad on the same device
# this needs to be resolved, perhaps with a is_multiplayer boolean or smt
func _input(event):
	if (event is InputEventJoypadButton) or (event is InputEventJoypadMotion):
		is_using_gamepad = true
	else:
		is_using_gamepad = false


func update_position(delta):
	direction.x = (Input.get_action_strength("move_right") - Input.get_action_strength("move_left")) * speed * roll_factor
	direction.z = (Input.get_action_strength("move_down") - Input.get_action_strength("move_up")) * speed * roll_factor

	
	if is_on_floor():
		# jump
		if Input.is_action_just_pressed("jump"):
			velocity_y = jump_velocity 
		else: 
			velocity_y = 0
		# roll
		if Input.is_action_just_pressed("roll") and !is_rolling and $Roll_cooldown.time_left == 0:
			is_rolling = true
			roll_factor = 2
			var tween = create_tween()
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(self, "rotation_degrees", Vector3(-360, rotation_degrees.y, 0), 1)
			tween.tween_callback(reset_rolling)
		
		# slipperiness
		# acceleration variable is meaningless when we are already using speed
		if direction.length() > 0:
			velocity = Vector3((velocity.x + (direction.x - velocity.x) * acceleration), velocity.y, (velocity.z + (direction.z - velocity.z) * acceleration))
		else:
			velocity = Vector3((velocity.x + (0 - velocity.x) * friction), velocity.y, (velocity.z + (0 - velocity.z) * friction))
	else:
		velocity_y -= gravity * delta
		velocity.x = velocity.x + (direction.x - velocity.x) * acceleration
		velocity.z = velocity.z + (direction.z - velocity.z) * acceleration

	velocity.y = velocity_y
	play_sound_if_moving()
	move_and_slide()
	

func reset_rolling():
	is_rolling = false
	roll_factor = 1                                               
	$Roll_cooldown.start()


func play_sound_if_moving():
	if velocity.length() > 1:
		if !movementSound.is_playing():
			movementSound.play()
	else:
		movementSound.stop()


func update_rotation():
	var player_pos = global_transform.origin
	var dropPlane = Plane(Vector3(0,1,0), player_pos.y)
	var ray_length = 1000
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length
	var cursor_pos = dropPlane.intersects_ray(from, to)
	if (cursor_pos != null):
		look_at(cursor_pos, Vector3.UP)


func update_gamepad_rotation(_delta):
	left_stick_turn.x = Input.get_axis("move_down", "move_up")
	left_stick_turn.y = Input.get_axis("move_right", "move_left")
	right_stick_look.x = Input.get_axis("look_down", "look_up")
	right_stick_look.y = Input.get_axis("look_right", "look_left")
	
	if left_stick_turn.length() >= 0.1:
		rotation.y = atan2(left_stick_turn.y, left_stick_turn.x)
	if right_stick_look.length() >= 0.1:
		rotation.y = atan2(right_stick_look.y, right_stick_look.x)
		


func update_shooting():
	# add melee with raycast range 0.1?
	if Input.is_action_just_pressed("shoot") and $Shoot_cooldown.time_left == 0 and ammo > 0:
		ammo -= 1
		emit_signal("player_ammo_updated", ammo)
		#raycast.position = shotgunRaycastPos
		shotgunSound.play()
		$Shoot_cooldown.start()
		# uses a combination of three different raycasts
		var collided_bodies = raycast.get_colliding_bodies()
		if collided_bodies.size() > 0:
			for body in collided_bodies:
				if global_position.distance_to(body.position) <= shotgun_range:
					body.die()
					add_score(10)
	if Input.is_action_just_pressed("melee") and $Melee_cooldown.time_left == 0:
		#raycast.position = meleeRaycastPos
		meleeSound.play()
		$Melee_cooldown.start()
		var collided_bodies = raycast.get_colliding_bodies()
		if collided_bodies.size() > 0:
			for body in collided_bodies:
				if global_position.distance_to(body.position) <= melee_range:
					body.die()
					add_score(10)


func add_score(score: int):
	if HIGHSCORE_SINGLETON.SCORE == null:
		HIGHSCORE_SINGLETON.SCORE = 0
	HIGHSCORE_SINGLETON.SCORE += score


func add_ammo(ammo_to_add: int):
	ammo += ammo_to_add
	emit_signal("player_ammo_updated", ammo)
	$ReloadSound.play()


func add_health(health_to_add: int):
	health_percentage += health_to_add
	if health_percentage < 0:
		die()
		queue_free()
	elif health_percentage > 100:
		health_percentage = 100
	emit_signal("player_health_updated", health_percentage)


func got_shot():
	# player has "i-frames"
	if is_rolling:
		return
	add_health(-10)
	damageSound.play()


func init_mac():
	# GuliKit Controller map for mac
	Input.add_joy_mapping("03000000790000001c18000000010000,
		GuliKit Controller A,a:b0,b:b1,y:b4,x:b3,start:b11,back:b10,
		leftstick:b13,rightstick:b14,leftshoulder:b6,rightshoulder:b7,
		dpup:b12,dpleft:b14,dpdown:b13,dpright:b15,leftx:a0,lefty:a1,rightx:a2
		,righty:a3,lefttrigger:a5,righttrigger:a4,platform:Mac OS X", true)

