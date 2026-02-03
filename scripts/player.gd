extends CharacterBody2D

const SPEED = 300.0

@onready var animations = $AnimatedSprite2D
@onready var camera = $Camera2D 

var is_active = true    
var nearby_car = null   

func _physics_process(_delta: float) -> void:
	if not is_active and nearby_car:
		print("Position de la voiture : ", nearby_car.global_position)
	if not is_active:
		return # On ne fait rien, la voiture s'occupe de la caméra via RemoteTransform

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()
	update_animations(direction)

func _input(event):
	if event.is_action_pressed("ui_select"): 
		if is_active and nearby_car:
			enter_car()
		elif not is_active:
			exit_car()

func enter_car():
	if nearby_car == null: return
	
	is_active = false
	animations.visible = false
	
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Configuration de la conduite
	nearby_car.is_controlled = true
	
	# --- LOGIQUE CAMÉRA MAGIQUE ---
	camera.top_level = true # On détache la caméra du player
	nearby_car.visible = true # Force la visibilité
	nearby_car.show()         # Force encore plus
	print("La voiture est-elle visible ? ", nearby_car.visible)
	# On dit au RemoteTransform de la voiture de piloter notre caméra
	var remote = nearby_car.get_node("RemoteTransform2D")
	remote.remote_path = camera.get_path()

func exit_car():
	# On récupère la voiture actuelle (celle qui a le contrôle)
	# Si nearby_car est null parce qu'on est sorti de l'area, on cherche le parent
	var car = nearby_car
	if car == null:
		# Sécurité : on cherche la voiture active dans le groupe
		for c in get_tree().get_nodes_in_group("voitures"):
			if c.is_controlled: car = c
	
	if car:
		car.is_controlled = false
		# On coupe le lien entre la voiture et la caméra
		car.get_node("RemoteTransform2D").remote_path = ""
		global_position = car.global_position + Vector2(60, 0)
	
	is_active = true
	animations.visible = true
	$CollisionShape2D.set_deferred("disabled", false)
	
	# On rattache la caméra au joueur proprement
	camera.top_level = false
	camera.position = Vector2.ZERO

# --- DÉTECTION ---
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("voitures"):
		nearby_car = body

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body == nearby_car:
		nearby_car = null
func update_animations(direction: Vector2):
	if direction == Vector2.ZERO:
		animations.play("idle")
	else:
		if abs(direction.x) > abs(direction.y):
			animations.play("side_left") 
			animations.flip_h = (direction.x < 0) 
		else:
			animations.flip_h = false 
			if direction.y > 0:
				animations.play("front_idle")
			else:
				animations.play("back_idle")
