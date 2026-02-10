extends AnimatedSprite2D

# Fonction pour lancer l'animation de course
func lancer_course():
	self.play("walk")

# Fonction pour arrêter le perso ou changer d'anim (utile quand il arrive à la boîte)
func prendre_objet():
	self.play("pickup") # Assure-toi que "pickup" existe dans ton SpriteFrames
