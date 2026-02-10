extends Sprite2D

func _process(delta):
	# Fait tourner le sprite de 300 degrés par seconde
	rotation_degrees += 300 * delta
