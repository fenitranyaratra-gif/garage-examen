extends CharacterBody2D

@export var speed: float = 400.0
@export var acceleration: float = 1200.0     # Accélération
@export var deceleration: float = 800.0      # Freinage quand on relâche
@export var friction: float = 600.0          # Friction au sol

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: Vector2 = Vector2.DOWN
var last_velocity: Vector2 = Vector2.ZERO
var is_controlled = false

func _physics_process(delta: float) -> void:
	# Si on ne contrôle pas la voiture → IMMOBILE COMPLÈTEMENT
	if not is_controlled:
		velocity = Vector2.ZERO  # Force l'arrêt total
		
		# Animation arrêt
		if sprite.is_playing():
			sprite.stop()
			sprite.frame = 0
		
		move_and_slide()  # Pour les collisions seulement
		return
	
	# Si on contrôle la voiture
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Accélération
	if direction.length() > 0.1:
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
		last_direction = direction
		last_velocity = velocity
		sprite.play("drive")
		update_sprite_direction(direction)
	else:
		# Freinage fort quand on relâche
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		
		# Si vitesse très faible → friction supplémentaire
		if velocity.length() < 30:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
		# Animation
		if velocity.length() > 10:
			update_sprite_direction(velocity.normalized())
			sprite.play("drive")
		else:
			# Arrêt complet → garde la dernière frame
			if sprite.is_playing():
				var save_frame = sprite.frame
				sprite.stop()
				sprite.frame = save_frame
	
	move_and_slide()

func update_sprite_direction(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		dir = last_direction if last_direction.length_squared() > 0.01 else Vector2.DOWN
	
	var anim_name = "drive"
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	
	var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 1:
		return
	
	var angle = dir.angle()
	var adjusted_angle = fposmod(angle - PI/2, TAU)
	var frame_index = int(round(adjusted_angle / TAU * frame_count)) % frame_count
	
	sprite.animation = anim_name
	sprite.frame = frame_index
