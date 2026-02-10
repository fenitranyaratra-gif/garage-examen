extends Area2D

class_name ParkingPlace

@export var place_name: String = "Place A"

var is_parked: bool = false
var parked_car: Node2D = null

# Références aux nœuds du personnage
@onready var animated_sprite = $ParkingAttendant/AnimatedSprite2D
@onready var speech_bubble = $ParkingAttendant/SpeechBubble
@onready var bubble_label = $ParkingAttendant/SpeechBubble/Label

# Référence à la barrière visuelle
@onready var barrier_sprite = $BarrierSprite  # À créer dans l'éditeur

@export var can_repair: bool = false  # Exposé dans l'éditeur si besoin

# Variables pour la position de la barrière
var barrier_target_position = Vector2(232.0, 115.0)  # Position finale
var barrier_hidden_position = Vector2(232.0, 15.0)   # Position cachée (plus haut)

# À ajouter dans les méthodes existantes
func get_can_repair() -> bool:
	return can_repair

func get_parked_car() -> Node2D:
	return parked_car

func _ready():
	if not is_in_group("parking_slots"):
		add_to_group("parking_slots")
	
	# Initialiser le personnage
	init_attendant()
	
	# Initialiser la barrière
	init_barrier()
	
	# Connecter le signal d'entrée de zone
	body_entered.connect(_on_body_entered)
	
	# Timer pour vérifier l'état de la voiture
	var state_timer = Timer.new()
	state_timer.wait_time = 0.3
	state_timer.timeout.connect(_check_car_state)
	add_child(state_timer)
	state_timer.start()

func init_attendant():
	# Cacher la bulle au départ
	if speech_bubble:
		speech_bubble.visible = false
		speech_bubble.scale = Vector2.ZERO
	
	# Configurer l'AnimatedSprite2D
	if animated_sprite:
		animated_sprite.stop()
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			var frame_count = animated_sprite.sprite_frames.get_frame_count("idle")
			if frame_count == 1:
				animated_sprite.play("idle")

# Modifiez init_barrier() pour configurer automatiquement :
func init_barrier():
	# Initialiser la barrière visuelle si elle existe
	if barrier_sprite:
		# Configurer selon le nom du parking
		if place_name == "Place A":
			barrier_target_position = Vector2(232.0, 115.0)
			barrier_hidden_position = Vector2(232.0, 15.0)
		elif place_name == "Place B":
			barrier_target_position = Vector2(260.0, 96.0)
			barrier_hidden_position = Vector2(260.0, -4.0)  # 100 pixels au-dessus
		elif place_name == "Place C":  # Si vous avez d'autres parkings
			barrier_target_position = Vector2(300.0, 110.0)
			barrier_hidden_position = Vector2(300.0, 10.0)
		
		# Positionner la barrière à sa position cachée
		barrier_sprite.position = barrier_hidden_position
		barrier_sprite.visible = false
		print("Barrière initialisée pour", place_name, "- position:", barrier_sprite.position)
func _on_body_entered(body: Node2D):
	# Quand une voiture entre dans la zone
	if body.is_in_group("voitures") and not is_parked:
		# Vérifier si c'est une voiture contrôlée (joueur dedans)
		if body.get("is_controlled") != null and body.is_controlled:
			# Afficher le message d'encouragement
			show_attendant_message("Alefa !", 1.5)
			
			# Attendre un peu puis garer
			await get_tree().create_timer(1.5).timeout
			
			# Garer la voiture
			try_park(body)

func try_park(car: Node2D) -> bool:
	if is_parked:
		return false
	
	# Positionner la voiture
	car.global_position = global_position
	car.global_rotation = 0
	
	# Arrêter la voiture
	if car.has_method("get_velocity"):
		car.velocity = Vector2.ZERO
	elif "velocity" in car:
		car.velocity = Vector2.ZERO
	
	# Mettre à jour l'état
	is_parked = true
	parked_car = car
	
	# Si le joueur était dans la voiture, le marquer comme non contrôlé
	if car.get("is_controlled") != null:
		car.is_controlled = false
	
	# Afficher le message de réussite
	show_attendant_message("C'est bon !", 3.0)
	
	# Arrêter l'animation si elle joue
	if animated_sprite:
		animated_sprite.stop()
	
	# Activer la barrière avec animation
	activate_barrier()
	can_repair = true
	
	return true

func show_attendant_message(text: String, duration: float = 2.0):
	# Afficher la bulle visuelle
	if speech_bubble and bubble_label:
		bubble_label.text = text
		
		# Animation d'apparition de la bulle
		speech_bubble.visible = true
		var tween = create_tween()
		tween.tween_property(speech_bubble, "scale", Vector2(1, 1), 0.2).from(Vector2.ZERO)
	
	# Jouer une animation rapide si disponible
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("talk"):
			animated_sprite.play("talk")
			await animated_sprite.animation_finished
			animated_sprite.stop()
		elif animated_sprite.sprite_frames.has_animation("wave"):
			animated_sprite.play("wave")
			await animated_sprite.animation_finished
			animated_sprite.stop()
	
	# Attendre la durée du message
	await get_tree().create_timer(duration).timeout
	
	# Cacher la bulle
	if speech_bubble and is_instance_valid(speech_bubble) and speech_bubble.visible:
		var tween_out = create_tween()
		tween_out.tween_property(speech_bubble, "scale", Vector2.ZERO, 0.2)
		await tween_out.finished
		speech_bubble.visible = false

func _check_car_state():
	if is_parked and parked_car and is_instance_valid(parked_car):
		# Vérifier si la voiture est maintenant contrôlée
		if parked_car.get("is_controlled") != null and parked_car.is_controlled:
			release_car()

func release_car():
	if is_parked and parked_car:
		is_parked = false
		parked_car = null
		
		# Ne pas réactiver l'animation idle si elle cause une rotation
		if animated_sprite:
			animated_sprite.stop()
			animated_sprite.frame = 0
		
		# Désactiver la barrière avec animation
		deactivate_barrier()
		can_repair = false
		return true
	return false

func activate_barrier():
	var barrier = get_node_or_null("Barrier")
	if barrier:
		# Activer la collision
		if barrier is CollisionShape2D:
			barrier.disabled = false
		elif barrier is StaticBody2D or barrier is Area2D:
			var collision = barrier.get_node("CollisionShape2D")
			if collision:
				collision.disabled = false
	
	# Animation de la barrière visuelle qui descend
	if barrier_sprite:
		print("Animation barrière - DESCENTE vers", barrier_target_position)
		barrier_sprite.visible = true
		
		# Position de départ (plus haut)
		barrier_sprite.position = barrier_hidden_position
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		
		# Animation vers la position cible
		tween.tween_property(barrier_sprite, "position", barrier_target_position, 0.5)
		
		# Option: ajouter un effet de son
		# AudioManager.play_sound("barrier_down")

func deactivate_barrier():
	var barrier = get_node_or_null("Barrier")
	if barrier:
		# Désactiver la collision
		if barrier is CollisionShape2D:
			barrier.disabled = true
		elif barrier is StaticBody2D or barrier is Area2D:
			var collision = barrier.get_node("CollisionShape2D")
			if collision:
				collision.disabled = true
	
	# Animation de la barrière visuelle qui remonte
	if barrier_sprite:
		print("Animation barrière - MONTÉE vers", barrier_hidden_position)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		
		# Animation vers la position cachée
		tween.tween_property(barrier_sprite, "position", barrier_hidden_position, 0.5)
		
		await tween.finished
		barrier_sprite.visible = false
		
		# Option: ajouter un effet de son
		# AudioManager.play_sound("barrier_up")
