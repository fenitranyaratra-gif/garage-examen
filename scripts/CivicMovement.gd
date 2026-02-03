extends CharacterBody2D

@export var speed = 300.0
@onready var sprite = $AnimatedSprite2D
var last_direction = Vector2.DOWN 
var is_controlled = false # Par défaut, personne ne la conduit

func _physics_process(_delta):
	# Si on ne contrôle pas la voiture, on ne fait rien (pas d'input)
	if not is_controlled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction.length() > 0.1:
		velocity = direction * speed
		last_direction = direction  # ← IMPORTANT: Mettre à jour la dernière direction
		update_sprite_direction(direction)
		sprite.play("drive")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		# Quand il n'y a pas de direction, on utilise la dernière direction
		update_sprite_direction(last_direction)
		if sprite.is_playing():
			var save_frame = sprite.frame
			sprite.stop()
			sprite.frame = save_frame

	move_and_slide()

func update_sprite_direction(dir: Vector2):
	var anim_name = "drive"
	if not sprite.sprite_frames.has_animation(anim_name):
		return
		
	var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 1: return

	var angle = dir.angle() 
	
	# Si Frame 0 = BAS, et Frame 24 = HAUT sur un total de x frames
	# On ajuste l'angle pour que le calcul tombe pile sur tes images.
	var adjusted_angle = fposmod(angle - PI/2, TAU)
	
	# Utiliser 'round' au lieu de 'floor' permet souvent de corriger le décalage d'une frame
	# car on cherche la frame la plus PROCHE de l'angle, pas celle juste en dessous.
	var frame_index = int(round(adjusted_angle / TAU * frame_count)) % frame_count
	
	sprite.animation = anim_name
	sprite.frame = frame_index
