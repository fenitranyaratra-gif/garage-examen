extends Node2D

# ===============================
# Nœuds enfants
# ===============================
@onready var label_statut: Label = $CharacterBody2D/LabelStatut
@onready var label_resume: Label = $CharacterBody2D/LabelResume
@onready var label: Label = $CharacterBody2D/Label
var is_in_finish_zone: bool = false
@onready var repair_button: Button = $CharacterBody2D/RepairButton
@onready var progress_bar: ProgressBar = $CharacterBody2D/ProgressBar
@onready var finish_button: Button = $CharacterBody2D/FinishButton

@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D

# Variables
var voiture_data: Dictionary = {}
var pending_pannes: Array[Dictionary] = []
var total_duree_restante: float = 0.0
var total_prix: int = 0
# Variables pour la validation
var validation_en_cours: bool = false
var requetes_validation_en_cours: Array = []
var current_repair_index: int = -1
var current_repair_time: float = 0.0
var repair_duration: float = 0.0
var is_repairing: bool = false

var has_reparable_panne: bool = false
var pannes_reparées: Array[Dictionary] = []
var panne_deja_payee: bool = false

# ===============================
# Initialisation
# ===============================
func _ready() -> void:
	add_to_group("voiture_principale")
	if repair_button:
		repair_button.visible = false
		repair_button.text = "Réparer"
		repair_button.connect("pressed", _on_repair_button_pressed)
	if finish_button:
		finish_button.visible = false
		finish_button.text = "Finir"
		finish_button.connect("pressed", _on_finish_button_pressed)
	if progress_bar:
		progress_bar.visible = false
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 0
	
	if sprite:
		sprite.modulate = Color.WHITE

func setup(data: Dictionary) -> void:
	voiture_data = data.duplicate(true)
	
	var matricule = str(data.get("matricule", "")).strip_edges()
	if label:
		label.text = "%s" % [matricule]
	
	charger_pannes()

# ===============================
# Chargement des pannes
# ===============================
func charger_pannes() -> void:
	var id_voiture = str(voiture_data.get("id", "")).strip_edges()
	if id_voiture.is_empty():
		_set_statut("❓ ID manquant", Color.YELLOW)
		return
	
	var url = "https://garage-api-2-t50x.onrender.com/voitures/" + id_voiture + "/pannes"
	var headers = PackedStringArray([
		"Accept: application/json",
		"Accept-Encoding: identity"
	])
	
	print("Chargement pannes pour voiture ID:", id_voiture)
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_pannes_reponse.bind(id_voiture))
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_set_statut("⚠️ Erreur réseau", Color.ORANGE)
		http.queue_free()

func _on_pannes_reponse(_result, code: int, _headers, body: PackedByteArray, id_voiture: String):
	if get_node_or_null("HTTPRequest"):
		get_node_or_null("HTTPRequest").queue_free()
	
	print("=== RÉPONSE PANNES ===")
	print("Code:", code)
	
	if code != 200:
		print("HTTP pannes erreur:", code)
		_set_statut("⚠️ Erreur API " + str(code), Color.ORANGE)
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("JSON pannes invalide")
		_set_statut("⚠️ Format JSON invalide", Color.ORANGE)
		return
	
	var response = json.data
	var ids_pannes: Array[String] = []
	
	if response is Array:
		print("Nombre de pannes trouvées:", response.size())
		
		for item in response:
			if item is Dictionary and item.has("document"):
				var doc = item["document"]
				if doc is Dictionary:
					var name_path = str(doc.get("name", ""))
					var id_panne = name_path.split("/")[-1] if "/" in name_path else ""
					if id_panne != "":
						ids_pannes.append(id_panne)
	
	print("Pannes à traiter:", ids_pannes)
	
	if ids_pannes.is_empty():
		_set_statut("✅ OK", Color.GREEN)
		_set_resume("Aucune panne")
		update_repair_button_visibility()
		update_finish_button_visibility()
		return
	
	# Réinitialiser
	total_duree_restante = 0.0
	total_prix = 0
	pending_pannes.clear()
	pannes_reparées.clear()
	has_reparable_panne = false
	validation_en_cours = false
	panne_deja_payee = false
	
	_traiter_pannes_suivantes(ids_pannes, 0)

# ===============================
# Traitement séquentiel - CORRIGÉ
# ===============================
func _traiter_pannes_suivantes(ids_pannes: Array[String], index: int):
	if index >= ids_pannes.size():
		print("=== FIN TRAITEMENT ===")
		print("panne_deja_payee = ", panne_deja_payee)
		print("has_reparable_panne = ", has_reparable_panne)
		print("total_prix = ", total_prix)
		print("pending_pannes.size() = ", pending_pannes.size())
		
		# LOGIQUE CORRIGÉE :
		if panne_deja_payee:
			# Une ou plusieurs pannes sont déjà payées
			if total_prix > 0:
				_set_statut("✅ OK (déjà payé)", Color.GREEN)
				_set_resume("Payé • " + str(total_prix) + " Ar")
			else:
				_set_statut("✅ OK (déjà payé)", Color.GREEN)
				_set_resume("Déjà payé")
		elif not has_reparable_panne and total_prix > 0:
			# Toutes réparées mais pas payées
			_set_statut("Réparé mais non payé", Color.YELLOW)
			_set_resume(str(total_prix) + " Ar à payer")
		elif not has_reparable_panne:
			# Aucune panne à réparer
			_set_statut("✅ OK", Color.GREEN)
			_set_resume("Aucune panne")
		else:
			# Pannes à réparer
			_set_statut("❌ CASSÉ", Color.RED)
			_set_resume("%ds • %d Ar" % [int(total_duree_restante), total_prix])
		
		# Boutons
		repair_button.visible = (not pending_pannes.is_empty() and not panne_deja_payee and has_reparable_panne)
		finish_button.visible = false
		progress_bar.visible = false
		
		return
	
	var id_panne_actuelle = ids_pannes[index]
	print("Traitement panne", index + 1, "/", ids_pannes.size(), ":", id_panne_actuelle)
	
	# Vérifier paiement
	verifier_paiement_panne(id_panne_actuelle, func(est_payee: bool):
		if est_payee:
			panne_deja_payee = true
			print("Panne", id_panne_actuelle, "déjà payée")
			# Même si payée, on doit charger son prix pour l'afficher
			_charger_prix_panne_payee(id_panne_actuelle, ids_pannes, index)
		else:
			_charger_details_panne(id_panne_actuelle, ids_pannes, index)
	)

# Nouvelle fonction pour charger le prix d'une panne déjà payée
func _charger_prix_panne_payee(id_panne: String, ids_pannes: Array[String], index: int):
	# Charger les détails pour connaître le prix
	var query_details = {
		"idPanne": id_panne
	}
	
	var url = "https://garage-api-2-t50x.onrender.com/panneDetails"
	var json_str = JSON.stringify(query_details)
	var headers = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Accept-Encoding: identity"
	])
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code: int, _headers, body: PackedByteArray):
		http.queue_free()
		
		if code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var response_array = json.data as Array
				for item in response_array:
					if item is Dictionary and item.has("document"):
						var doc = item["document"]
						if doc is Dictionary:
							var fields = doc.get("fields", {})
							var id_type = str(fields.get("idPanneType", {}).get("stringValue", ""))
							if id_type != "":
								_charger_prix_type(id_type, id_panne, ids_pannes, index)
								return
		
		# Si erreur, passer à la suivante
		_traiter_pannes_suivantes(ids_pannes, index + 1)
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		_traiter_pannes_suivantes(ids_pannes, index + 1)

func _charger_prix_type(id_type: String, id_panne: String, ids_pannes: Array[String], index: int):
	var url = "https://garage-api-2-t50x.onrender.com/panneTypes/" + id_type
	var headers = PackedStringArray([
		"Accept: application/json",
		"Accept-Encoding: identity"
	])
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code: int, _headers, body: PackedByteArray):
		http.queue_free()
		
		if code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var doc_type = json.data
				if doc_type is Dictionary:
					var fields = doc_type.get("fields", {})
					var prix_raw = fields.get("prix", {})
					var prix = 0
					
					if prix_raw.has("doubleValue"):
						prix = int(prix_raw["doubleValue"])
					elif prix_raw.has("integerValue"):
						prix = int(prix_raw["integerValue"])
					elif prix_raw.has("stringValue"):
						var p_str = str(prix_raw["stringValue"])
						if p_str.is_valid_int():
							prix = int(p_str)
					
					total_prix += prix
					print("Panne payée", id_panne, "→ prix:", prix, " Ar (total:", total_prix, ")")
		
		_traiter_pannes_suivantes(ids_pannes, index + 1)
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_traiter_pannes_suivantes(ids_pannes, index + 1)

func _charger_details_panne(id_panne: String, ids_pannes: Array[String], index: int):
	var query_details = {
		"idPanne": id_panne
	}
	
	var url = "https://garage-api-2-t50x.onrender.com/panneDetails"
	var json_str = JSON.stringify(query_details)
	var headers = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Accept-Encoding: identity"
	])
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code: int, _headers, body: PackedByteArray):
		http.queue_free()
		
		if code != 200:
			_traiter_pannes_suivantes(ids_pannes, index + 1)
			return
		
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK:
			_traiter_pannes_suivantes(ids_pannes, index + 1)
			return
		
		var response_array = json.data as Array
		var local_types: Array[String] = []
		
		for item in response_array:
			if item is Dictionary and item.has("document"):
				var doc = item["document"]
				if doc is Dictionary:
					var fields = doc.get("fields", {})
					var id_type = str(fields.get("idPanneType", {}).get("stringValue", ""))
					if id_type != "":
						local_types.append(id_type)
		
		if local_types.is_empty():
			_traiter_pannes_suivantes(ids_pannes, index + 1)
			return
		
		var local_completed: int = 0
		for id_type in local_types:
			_charger_un_type(id_type, id_panne, func():
				local_completed += 1
				if local_completed == local_types.size():
					_traiter_pannes_suivantes(ids_pannes, index + 1)
			)
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		_traiter_pannes_suivantes(ids_pannes, index + 1)

func _charger_un_type(id_type: String, id_panne: String, on_complete: Callable):
	var url = "https://garage-api-2-t50x.onrender.com/panneTypes/" + id_type
	var headers = PackedStringArray([
		"Accept: application/json",
		"Accept-Encoding: identity"
	])
	
	var http_type = HTTPRequest.new()
	add_child(http_type)
	http_type.request_completed.connect(func(_result, code: int, _headers, body: PackedByteArray):
		http_type.queue_free()
		
		if code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var doc_type = json.data
				if doc_type is Dictionary:
					var fields = doc_type.get("fields", {})
					
					var duree = float(fields.get("duree", {}).get("integerValue", 0))
					var prix_raw = fields.get("prix", {})
					var prix = 0
					
					if prix_raw.has("doubleValue"):
						prix = int(prix_raw["doubleValue"])
					elif prix_raw.has("integerValue"):
						prix = int(prix_raw["integerValue"])
					elif prix_raw.has("stringValue"):
						var p_str = str(prix_raw["stringValue"])
						if p_str.is_valid_int():
							prix = int(p_str)
					
					verifier_si_panne_a_reparer(id_panne, func(peut_reparer: bool):
						if peut_reparer:
							has_reparable_panne = true
							pending_pannes.append({"id_type": id_type, "duree": duree, "prix": prix, "id_panne": id_panne})
							total_duree_restante += duree
							total_prix += prix
							
							print("Panne à réparer", id_panne, "→ durée:", duree, "s | prix:", prix, " Ar")
						else:
							print("Panne déjà réparée", id_panne, "→ prix:", prix, " Ar (sans durée)")
							total_prix += prix
						
						on_complete.call()
					)
		else:
			on_complete.call()
	)
	
	var err = http_type.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		on_complete.call()
func verifier_si_panne_a_reparer(id_panne: String, callback: Callable) -> void:
	# Utiliser votre API au lieu de Firestore directement
	var url = "https://garage-api-2-t50x.onrender.com/pannes/" + id_panne + "/est-reparee"
	var headers = PackedStringArray([
		"Accept: application/json",
		"Accept-Encoding: identity"
	])
	
	print("Vérification si panne est déjà réparée via API:", id_panne)
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code: int, _headers, body: PackedByteArray):
		http.queue_free()
		
		var peut_reparer = true  # Par défaut, on peut réparer
		
		print("Réponse API est-reparée - Code:", code, " pour panne:", id_panne)
		
		if code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var response = json.data
				if response is Dictionary and response.get("est_reparée", false):
					peut_reparer = false
					var raison = response.get("raison", "inconnue")
					print("→ Panne", id_panne, "DÉJÀ", raison.uppercase(), " !")
				else:
					print("→ Panne", id_panne, "PAS ENCORE RÉPARÉE")
			else:
				print("Erreur parsing JSON, continuer comme si on pouvait réparer")
		else:
			print("Erreur HTTP", code, " - continuer comme si on pouvait réparer")
			if body.size() > 0:
				print("Message d'erreur:", body.get_string_from_utf8())
		
		callback.call(peut_reparer)
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("Erreur lors de l'envoi de la requête, continuer comme si on pouvait réparer")
		callback.call(true)
func verifier_paiement_panne(id_panne: String, callback: Callable):
	var url = "https://garage-api-2-t50x.onrender.com/pannes/" + id_panne + "/paiement"
	var headers = PackedStringArray([
		"Accept: application/json",
		"Accept-Encoding: identity"
	])
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code: int, _headers, body: PackedByteArray):
		http.queue_free()
		
		var est_payee = false
		
		if code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var response = json.data
				if response is Dictionary and response.get("paid", false):
					est_payee = true
		
		callback.call(est_payee)
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		callback.call(false)

# ===============================
# Reste du code (inchangé)
# ===============================
func _on_repair_button_pressed() -> void:
	if pending_pannes.is_empty() or is_repairing or panne_deja_payee:
		return
	
	repair_button.visible = false
	progress_bar.visible = true
	progress_bar.value = 0
	
	current_repair_index = 0
	_start_next_repair()

func _start_next_repair() -> void:
	if current_repair_index >= pending_pannes.size():
		is_repairing = false
		progress_bar.visible = false
		_set_statut("Réparations terminées", Color.GREEN)
		update_repair_button_visibility()
		update_finish_button_visibility()
		return
	
	var panne = pending_pannes[current_repair_index]
	repair_duration = panne["duree"]
	current_repair_time = 0.0
	is_repairing = true
	print("Réparation démarrée : ", repair_duration, " secondes")
func _process(delta: float) -> void:
	if not is_repairing:
		return
	
	current_repair_time += delta
	progress_bar.value = (current_repair_time / repair_duration) * 100
	
	if current_repair_time >= repair_duration:
		is_repairing = false
		progress_bar.visible = false
		
		total_duree_restante -= repair_duration
		var panne_reparée = pending_pannes[current_repair_index]
		pannes_reparées.append(panne_reparée.duplicate())
		pending_pannes.remove_at(current_repair_index)
		
		update_repair_button_visibility()
		_set_resume("%ds • %d Ar" % [int(total_duree_restante), total_prix])
		
		# CORRECTION : Vérifier si TOUTES les réparations sont terminées
		if pending_pannes.is_empty():
			_set_statut("Réparations terminées", Color.GREEN)
			print("=== TOUTES LES RÉPARATIONS TERMINÉES ===")
			print("pannes_reparées:", pannes_reparées.size())
			print("is_in_finish_zone:", is_in_finish_zone)
			
			# Toujours mettre à jour la visibilité du bouton
			update_finish_button_visibility()
		else:
			# Il reste encore des réparations
			print("=== RÉPARATION PARTIELLE TERMINÉE ===")
			print("Reste", pending_pannes.size(), "pannes à réparer")
			print("Temps restant:", total_duree_restante, "s")
			
			# Passer à la panne suivante
			current_repair_index += 1
			if current_repair_index < pending_pannes.size():
				_start_next_repair()			
func _on_finish_button_pressed() -> void:
	if pannes_reparées.is_empty() or validation_en_cours:
		print("Aucune panne réparée à valider ou validation déjà en cours")
		_set_statut("Rien à valider", Color.GRAY)
		finish_button.visible = false
		return
	
	print("=== DÉBUT VALIDATION ===")
	print("Nombre de pannes réparées à valider : ", pannes_reparées.size())
	
	# Éviter les doublons
	var pannes_uniques = []
	var ids_deja_traites = {}
	
	for panne in pannes_reparées:
		var id_panne = panne["id_panne"]
		if not ids_deja_traites.has(id_panne):
			ids_deja_traites[id_panne] = true
			pannes_uniques.append(panne)
	
	print("Pannes uniques après dédoublonnage : ", pannes_uniques.size())
	
	if pannes_uniques.is_empty():
		_finaliser_validation()
		return
	
	validation_en_cours = true
	requetes_validation_en_cours.clear()
	
	for panne in pannes_uniques:
		var id_panne = panne["id_panne"]
		print("→ Tentative création pour panne réparée : ", id_panne)
		
		var now = Time.get_datetime_dict_from_system(true)
		var timestamp_str = "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
			now.year, now.month, now.day,
			now.hour, now.minute, now.second
		]
		
		# MODIFICATION : Préparer le document au format que votre API attend
		var new_doc = {
			"fields": {
				"dateHeure": {"timestampValue": timestamp_str},
				"idPanne":   {"stringValue": id_panne},
				"idStatutForPanne": {"stringValue": "2"}
			}
		}
		
		var json_str = JSON.stringify(new_doc)
		
		# MODIFICATION : Utiliser votre API Flask au lieu de Firestore direct
		var url = "https://garage-api-2-t50x.onrender.com/panneStatuts"
		var headers = PackedStringArray(["Content-Type: application/json"])
		
		var http = HTTPRequest.new()
		add_child(http)
		requetes_validation_en_cours.append(http)
		
		# Utiliser une closure qui capture les variables correctement
		http.request_completed.connect(func(_result, code, _headers, body, http_node = http, panne_id = id_panne):
			print("Réponse HTTP pour ", panne_id, " code = ", code)
			
			if code >= 200 and code < 300:
				print("→ SUCCÈS pour ", panne_id)
			else:
				print("→ ÉCHEC pour ", panne_id, " → code ", code)
				if body.size() > 0:
					print("Message d'erreur:", body.get_string_from_utf8())
			
			# Retirer la requête de la liste
			if http_node in requetes_validation_en_cours:
				requetes_validation_en_cours.erase(http_node)
			http_node.queue_free()
			
			# Si plus de requêtes en cours, finaliser
			if requetes_validation_en_cours.is_empty():
				print("Toutes les requêtes de validation sont terminées")
				validation_en_cours = false
				_finaliser_validation()
		)
		
		var err = http.request(url, headers, HTTPClient.METHOD_POST, json_str)
		if err != OK:
			print("Erreur Godot HTTPRequest : ", err)
			if http in requetes_validation_en_cours:
				requetes_validation_en_cours.erase(http)
			http.queue_free()
			
			if requetes_validation_en_cours.is_empty():
				validation_en_cours = false
				_finaliser_validation()
	
	finish_button.visible = false
	_set_statut("Validation en cours...", Color.YELLOW)

func _finaliser_validation():
	print("=== FINALISATION VALIDATION ===")
	_set_statut("✅ Réparé et validé", Color.GREEN)
	
	# Réinitialiser pour éviter de re-valider les mêmes pannes
	pannes_reparées.clear()
	pending_pannes.clear()
	total_duree_restante = 0.0
	total_prix = 0
	has_reparable_panne = false
	validation_en_cours = false
	requetes_validation_en_cours.clear()
	update_repair_button_visibility()
	update_finish_button_visibility()

func update_repair_button_visibility() -> void:
	if repair_button:
		repair_button.visible = (not pending_pannes.is_empty() and not panne_deja_payee and has_reparable_panne)

func update_finish_button_visibility() -> void:
	if not is_instance_valid(finish_button):
		print("❌ finish_button n'est pas valide!")
		return
	
	print("=== update_finish_button_visibility() ===")
	print("is_in_finish_zone =", is_in_finish_zone)
	print("pending_pannes.size() =", pending_pannes.size())
	print("total_duree_restante =", total_duree_restante)
	print("pannes_reparées.size() =", pannes_reparées.size())
	print("panne_deja_payee =", panne_deja_payee)
	
	# LOGIQUE CORRIGÉE :
	# Le bouton Finir apparaît quand :
	# 1. La voiture est dans la zone de finition
	# 2. Toutes les réparations sont terminées (plus de pannes en attente)
	# 3. Plus de temps de réparation restant
	# 4. Il y a des pannes réparées à valider
	# 5. La voiture n'est pas déjà payée
	
	var should_show = false
	
	if is_in_finish_zone:
		print("✓ Dans la zone de finition")
		
		if pending_pannes.is_empty():
			print("✓ Aucune panne en attente")
			
			if total_duree_restante <= 0:
				print("✓ Pas de temps de réparation restant")
				
				if pannes_reparées.size() > 0:
					print("✓ Il y a", pannes_reparées.size(), "pannes réparées à valider")
					
					if not panne_deja_payee:
						print("✓ Pas déjà payé")
						should_show = true
						print("→ TOUTES LES CONDITIONS SONT REMPLIES !")
					else:
						print("✗ Déjà payé, pas besoin de bouton")
				else:
					print("✗ Aucune panne réparée à valider")
			else:
				print("✗ Temps de réparation restant:", total_duree_restante)
		else:
			print("✗ Pannes en attente:", pending_pannes.size())
	else:
		print("✗ Pas dans la zone de finition")
	
	print("  should_show =", should_show)
	print("================================")
	
	finish_button.visible = should_show
	finish_button.disabled = !should_show
	
	# Debug supplémentaire
	if should_show:
		print("🎯 BOUTON FINIR DOIT ÊTRE VISIBLE !")
		print("Position du bouton:", finish_button.global_position)
		print("Taille du bouton:", finish_button.size)

func _set_statut(text: String, col: Color):
	if label_statut:
		label_statut.text = text
		label_statut.modulate = col
		print("STATUT MIS À JOUR : ", text)
	
	if sprite:
		sprite.modulate = Color.WHITE

func _set_resume(text: String):
	if label_resume:
		label_resume.text = text
		print("RÉSUMÉ MIS À JOUR : ", text)

func afficher_erreur(msg: String):
	_set_statut("⚠️ " + msg, Color.ORANGE)
	print("ERREUR : ", msg)

func montrer_bouton_finir():
	print("🎯 MONTRE BOUTON FINIR APPELÉ !")
	print("  Nom de cette voiture:", name)
	print("  Chemin:", get_path())
	
	is_in_finish_zone = true
	print("  is_in_finish_zone =", is_in_finish_zone)
	
	# Forcer l'update IMMÉDIATEMENT
	update_finish_button_visibility()

func cacher_bouton_finir():
	print("🎯 CACHE BOUTON FINIR APPELÉ !")
	
	is_in_finish_zone = false
	print("  is_in_finish_zone =", is_in_finish_zone)
	
	# Forcer l'update IMMÉDIATEMENT
	update_finish_button_visibility()
