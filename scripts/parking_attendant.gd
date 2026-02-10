extends CharacterBody2D

class_name ParkingAttendant

# Utiliser get_node_or_null pour éviter les erreurs
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var speech_bubble: Sprite2D = get_node_or_null("SpeechBubble")
@onready var speech_text: Label = get_node_or_null("SpeechBubble/Label")

var is_active: bool = true
var has_animations: bool = false

func _ready():
	print("🔧 Initialisation du ParkingAttendant...")
	
	# Vérifier si le sprite existe
	if animated_sprite:
		print("✅ AnimatedSprite2D trouvé")
		
		# Vérifier s'il a des animations configurées
		if animated_sprite.sprite_frames:
			has_animations = true
			print("✅ Animations disponibles")
			
			# Vérifier les animations spécifiques
			var animations = animated_sprite.sprite_frames.get_animation_names()
			print("Animations trouvées: ", animations)
			
			# Jouer l'animation idle si elle existe
			if "idle" in animations:
				animated_sprite.play("idle")
			elif animations.size() > 0:
				animated_sprite.play(animations[0])  # Jouer la première animation
		else:
			print("⚠️ Aucun SpriteFrames configuré")
			# Créer des animations par défaut
			create_default_animations()
	else:
		print("⚠️ AnimatedSprite2D non trouvé - création d'un sprite simple")
		create_simple_sprite()
	
	# Configurer la bulle
	if speech_bubble and speech_text:
		speech_bubble.visible = false
		print("✅ Bulle de dialogue trouvée")
	else:
		print("⚠️ Bulle non trouvée - création d'une bulle simple")
		create_simple_bubble()
	
	print("✅ ParkingAttendant prêt")

func create_default_animations():
	# Créer des animations par défaut si aucune n'existe
	if not animated_sprite.sprite_frames:
		var sprite_frames = SpriteFrames.new()
		animated_sprite.sprite_frames = sprite_frames
	
	# Créer une animation idle simple (1 frame)
	animated_sprite.sprite_frames.add_animation("idle")
	animated_sprite.sprite_frames.add_frame("idle", preload("res://icon.svg"))
	
	# Animation de parole
	animated_sprite.sprite_frames.add_animation("talk")
	animated_sprite.sprite_frames.add_frame("talk", preload("res://icon.svg"))
	
	# Animation de vague
	animated_sprite.sprite_frames.add_animation("wave")
	animated_sprite.sprite_frames.add_frame("wave", preload("res://icon.svg"))
	
	has_animations = true
	print("✅ Animations par défaut créées")

func create_simple_sprite():
	# Créer un sprite simple si AnimatedSprite2D n'existe pas
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	
	# Texture par défaut (icône Godot)
	var texture = preload("res://icon.svg")
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(0.3, 0.3)
	
	# Remplacer par un Sprite2D simple
	animated_sprite.queue_free()
	animated_sprite = null
	
	add_child(sprite)
	print("✅ Sprite simple créé")

func create_simple_bubble():
	# Créer une bulle simple
	speech_bubble = Sprite2D.new()
	speech_bubble.name = "SpeechBubble"
	speech_bubble.position = Vector2(0, -60)
	
	# Créer une texture blanche simple
	var image = Image.create(100, 50, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	speech_bubble.texture = texture
	
	# Ajouter un contour noir
	speech_bubble.modulate = Color.BLACK
	speech_bubble.scale = Vector2(1.1, 1.1)
	
	# Sprite blanc pour l'intérieur
	var inner_bubble = Sprite2D.new()
	inner_bubble.texture = texture
	inner_bubble.modulate = Color.WHITE
	inner_bubble.scale = Vector2(0.9, 0.9)
	speech_bubble.add_child(inner_bubble)
	
	# Texte
	speech_text = Label.new()
	speech_text.name = "Label"
	speech_text.text = ""
	speech_text.position = Vector2(50, 25)
	speech_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner_bubble.add_child(speech_text)
	
	add_child(speech_bubble)
	speech_bubble.visible = false
	
	print("✅ Bulle simple créée")

func show_message(message: String, animation_name: String = "talk"):
	print("💬 ParkingAttendant dit: ", message)
	
	# Afficher dans la console
	print("[", name, "] ", message)
	
	# Afficher la bulle
	if speech_bubble and speech_text:
		speech_text.text = message
		speech_bubble.visible = true
		
		# Animation simple d'apparition
		var tween = create_tween()
		tween.tween_property(speech_bubble, "scale", Vector2(1.0, 1.0), 0.2).from(Vector2(0, 0))
		tween.tween_property(speech_bubble, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(speech_bubble, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Animation du personnage
	if animated_sprite and has_animations:
		# Vérifier si l'animation existe
		var animations = animated_sprite.sprite_frames.get_animation_names()
		if animation_name in animations:
			animated_sprite.play(animation_name)
		elif "talk" in animations:
			animated_sprite.play("talk")
		elif animations.size() > 0:
			animated_sprite.play(animations[0])
	
	# Durée d'affichage
	var duration = 2.0 if message == "Alefa !" else 3.0
	await get_tree().create_timer(duration).timeout
	
	# Cacher la bulle
	if speech_bubble and is_instance_valid(speech_bubble):
		var tween_out = create_tween()
		tween_out.tween_property(speech_bubble, "scale", Vector2(0, 0), 0.2)
		await tween_out.finished
		speech_bubble.visible = false
	
	# Retour à l'animation idle
	if is_active and animated_sprite and has_animations:
		var animations = animated_sprite.sprite_frames.get_animation_names()
		if "idle" in animations:
			animated_sprite.play("idle")

func set_active(active: bool):
	is_active = active
	print("🔧 ParkingAttendant actif: ", active)
	
	if not active:
		# Arrêter les animations
		if animated_sprite:
			animated_sprite.stop()

func trigger_encouragement():
	if is_active:
		show_message("Alefa !", "wave")

func trigger_success():
	show_message("C'est bon !", "celebrate")
	set_active(false)
