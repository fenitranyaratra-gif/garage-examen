extends Node2D

# ===============================
# Nœuds enfants (Chemins mis à jour)
# ===============================
# On ajoute le nom du parent devant chaque noeud déplacé
@onready var label_statut: Label = $CharacterBody2D/LabelStatut
@onready var label_resume: Label = $CharacterBody2D/LabelResume
@onready var label: Label = $CharacterBody2D/Label

# Si ceux-là sont restés sous Civic, ne change rien :
@onready var repair_button: Button = $RepairButton
@onready var progress_bar: ProgressBar = $CharacterBody2D/ProgressBar
@onready var finish_button: Button = $FinishButton

# N'oublie pas ton sprite pour la logique de rotation
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
# ===============================
# Données
# ===============================
var voiture_data: Dictionary = {}
var pending_pannes: Array[Dictionary] = []
var total_duree_restante: float = 0.0
var total_prix: int = 0

var current_repair_index: int = -1
var current_repair_time: float = 0.0
var repair_duration: float = 0.0
var is_repairing: bool = false

var panne_statuts_to_update: Array[String] = []
var has_reparable_panne: bool = false

# Nouvelle variable pour stocker les pannes réparées
var pannes_reparées: Array[Dictionary] = []

# Variables pour la validation
var validation_en_cours: bool = false
var requetes_validation_en_cours: Array = []

# ===============================
# Initialisation
# ===============================
func _ready() -> void:
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

func setup(data: Dictionary) -> void:
	voiture_data = data.duplicate(true)
	
	var matricule = str(data.get("matricule", "")).strip_edges()
	var modele = str(data.get("modele", "")).strip_edges()
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
	
	var query_pannes = {
		"structuredQuery": {
			"from": [{"collectionId": "pannes"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "idVoiture"},
					"op": "EQUAL",
					"value": {"stringValue": id_voiture}
				}
			},
			"limit": 20
		}
	}
	
	var url = "https://firestore.googleapis.com/v1/projects/garrageapp-05/databases/(default)/documents:runQuery"
	var json_str = JSON.stringify(query_pannes)
	var headers = PackedStringArray(["Content-Type: application/json"])
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_pannes_reponse.bind(id_voiture))
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		_set_statut("⚠️ Erreur réseau", Color.ORANGE)
		http.queue_free()

func _on_pannes_reponse(_result, code: int, _headers, body: PackedByteArray, id_voiture: String):
	if get_node_or_null("HTTPRequest"):
		get_node_or_null("HTTPRequest").queue_free()
	
	if code != 200:
		print("HTTP pannes erreur:", code)
		_set_statut("⚠️ Erreur serveur", Color.ORANGE)
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("JSON pannes invalide")
		return
	
	var response_array = json.data as Array
	var ids_pannes: Array[String] = []
	
	for item in response_array:
		var doc = item.get("document")
		if doc is Dictionary:
			var name_path = str(doc.get("name", ""))
			var id_panne = name_path.split("/")[-1] if "/" in name_path else ""
			if id_panne != "":
				ids_pannes.append(id_panne)
	
	print("Nombre de pannes principales trouvées :", ids_pannes.size())
	
	if ids_pannes.is_empty():
		_set_statut("✅ OK", Color.GREEN)
		_set_resume("Aucune panne")
		update_repair_button_visibility()
		update_finish_button_visibility()
		return
	
	# On initialise sans statut ici
	total_duree_restante = 0.0
	total_prix = 0
	pending_pannes.clear()
	pannes_reparées.clear()  # Réinitialiser
	panne_statuts_to_update.clear()
	has_reparable_panne = false
	validation_en_cours = false
	
	_traiter_pannes_suivantes(ids_pannes, 0)

# ===============================
# Traitement séquentiel des pannes
# ===============================
func _traiter_pannes_suivantes(ids_pannes: Array[String], index: int):
	if index >= ids_pannes.size():
		print("=== FIN TRAITEMENT ===")
		print("has_reparable_panne = ", has_reparable_panne)
		print("total_prix = ", total_prix)
		print("pending_pannes.size() = ", pending_pannes.size())
		print("pannes_reparées.size() = ", pannes_reparées.size())
		
		if not has_reparable_panne:
			_set_statut("Réparé mais non payé", Color.YELLOW)
			_set_resume(str(total_prix) + " Ar à payer")
			repair_button.visible = false
			finish_button.visible = false
			progress_bar.visible = false
		else:
			_set_statut("❌ CASSÉ", Color.RED)
			_set_resume("%ds • %d Ar" % [int(total_duree_restante), total_prix])
			update_repair_button_visibility()
			update_finish_button_visibility()
		return
	
	var id_panne_actuelle = ids_pannes[index]
	
	var query_details = {
		"structuredQuery": {
			"from": [{"collectionId": "panneDetails"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "idPanne"},
					"op": "EQUAL",
					"value": {"stringValue": id_panne_actuelle}
				}
			},
			"limit": 10
		}
	}
	
	var url_details = "https://firestore.googleapis.com/v1/projects/garrageapp-05/databases/(default)/documents:runQuery"
	var json_str_details = JSON.stringify(query_details)
	var headers = PackedStringArray(["Content-Type: application/json"])
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_details_reponse.bind(id_panne_actuelle, ids_pannes, index))
	
	var err = http.request(url_details, headers, HTTPClient.METHOD_POST, json_str_details)
	if err != OK:
		print("Erreur lancement panneDetails pour ", id_panne_actuelle)
		_traiter_pannes_suivantes(ids_pannes, index + 1)

func _on_details_reponse(_result, code: int, _headers, body: PackedByteArray, id_panne: String, ids_pannes: Array[String], index: int):
	if get_node_or_null("HTTPRequest"):
		get_node_or_null("HTTPRequest").queue_free()
	
	if code != 200:
		print("HTTP panneDetails ", code, " pour panne ", id_panne)
		_traiter_pannes_suivantes(ids_pannes, index + 1)
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_traiter_pannes_suivantes(ids_pannes, index + 1)
		return
	
	var response_array = json.data as Array
	print("Nombre de panneDetails pour ", id_panne, " : ", response_array.size())
	
	var local_types: Array[String] = []
	
	for item in response_array:
		var doc = item.get("document")
		if doc is Dictionary:
			var fields = doc.get("fields", {})
			var id_type = str(fields.get("idPanneType", {}).get("stringValue", ""))
			if id_type != "":
				local_types.append(id_type)
	
	if local_types.is_empty():
		print("Aucun type pour panne ", id_panne)
		_traiter_pannes_suivantes(ids_pannes, index + 1)
		return
	
	var local_completed: int = 0
	for id_type in local_types:
		_charger_un_type(id_type, id_panne, func():
			local_completed += 1
			if local_completed == local_types.size():
				_traiter_pannes_suivantes(ids_pannes, index + 1)
		)

func _charger_un_type(id_type: String, id_panne: String, on_complete: Callable):
	var url_type = "https://firestore.googleapis.com/v1/projects/garrageapp-05/databases/(default)/documents/panneTypes/" + id_type
	
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
					
					verifier_si_panne_a_reparer(id_panne, func(peut_reparer: bool, doc_id_statut: String):
						if peut_reparer:
							has_reparable_panne = true
							pending_pannes.append({"id_type": id_type, "duree": duree, "prix": prix, "id_panne": id_panne})
							total_duree_restante += duree
							total_prix += prix
							
							print("Ajout panne type ", id_type, " → durée: ", duree, "s | prix: ", prix, " Ar")
							
							if doc_id_statut != "":
								panne_statuts_to_update.append(doc_id_statut)
						else:
							print("Panne ", id_panne, " déjà réparée → ignorée")
							total_prix += prix  # AJOUTÉ: Accumuler le prix même si déjà réparé
						
						update_repair_button_visibility()
						_set_resume("%ds • %d Ar" % [int(total_duree_restante), total_prix])
						on_complete.call()
					)
		else:
			on_complete.call()
	)
	
	http_type.request(url_type)
	
func verifier_si_panne_a_reparer(id_panne: String, callback: Callable) -> void:
	var query_statut = {
		"structuredQuery": {
			"from": [{"collectionId": "panneStatuts"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "idPanne"},
					"op": "EQUAL",
					"value": {"stringValue": id_panne}
				}
			},
			"limit": 1
		}
	}
	
	var url = "https://firestore.googleapis.com/v1/projects/garrageapp-05/databases/(default)/documents:runQuery"
	var json_str = JSON.stringify(query_statut)
	var headers = PackedStringArray(["Content-Type: application/json"])
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code: int, _headers, body: PackedByteArray):
		http.queue_free()
		
		var peut_reparer = true
		var doc_id_statut = ""
		
		if code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var response_array = json.data as Array
				if not response_array.is_empty():
					var item = response_array[0]
					var doc = item.get("document")
					if doc is Dictionary:
						doc_id_statut = str(doc.get("name", "")).split("/")[-1]
						var fields = doc.get("fields", {})
						var statut = str(fields.get("idStatutForPanne", {}).get("stringValue", "1"))
						
						if statut == "2":
							peut_reparer = false
		
		callback.call(peut_reparer, doc_id_statut)
	)
	
	http.request(url, headers, HTTPClient.METHOD_POST, json_str)

# ===============================
# Gestion boutons et réparation
# ===============================
func update_repair_button_visibility() -> void:
	if repair_button:
		if pending_pannes.is_empty() or is_repairing:
			repair_button.visible = false
		else:
			repair_button.visible = true

func update_finish_button_visibility() -> void:
	if finish_button:
		if pending_pannes.is_empty() and total_duree_restante <= 0 and has_reparable_panne:
			finish_button.visible = true
		else:
			finish_button.visible = false

func _on_repair_button_pressed() -> void:
	if pending_pannes.is_empty() or is_repairing:
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
	
	print("Réparation démarrée : ", panne["id_type"], " - ", repair_duration, " secondes")

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
		
		# Sauvegarder la panne réparée avant de la supprimer
		pannes_reparées.append(panne_reparée.duplicate())
		pending_pannes.remove_at(current_repair_index)
		
		update_repair_button_visibility()
		_set_resume("%ds • %d Ar" % [int(total_duree_restante), total_prix])
		
		if pending_pannes.is_empty():
			update_finish_button_visibility()
			_set_statut("Réparations terminées", Color.GREEN)

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
		
		var new_doc = {
			"fields": {
				"dateHeure": {"timestampValue": timestamp_str},
				"idPanne":   {"stringValue": id_panne},
				"idStatutForPanne": {"stringValue": "2"}
			}
		}
		
		var json_str = JSON.stringify(new_doc)
		var url = "https://firestore.googleapis.com/v1/projects/garrageapp-05/databases/(default)/documents/panneStatuts"
		var headers = PackedStringArray(["Content-Type: application/json"])
		
		var http = HTTPRequest.new()
		add_child(http)
		requetes_validation_en_cours.append(http)
		
		# Utiliser une closure qui capture les variables correctement
		http.request_completed.connect(func(_result, code, _headers, _body, http_node = http, panne_id = id_panne):
			print("Réponse HTTP pour ", panne_id, " code = ", code)
			
			if code >= 200 and code < 300:
				print("→ SUCCÈS pour ", panne_id)
			else:
				print("→ ÉCHEC pour ", panne_id, " → code ", code)
			
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
	
# ===============================
# UI helpers
# ===============================
func _set_statut(text: String, col: Color):
	if label_statut:
		label_statut.text = text
		label_statut.modulate = col
		print("STATUT MIS À JOUR : ", text)

func _set_resume(text: String):
	if label_resume:
		label_resume.text = text
		print("RÉSUMÉ MIS À JOUR : ", text)
	else:
		print("Résumé : ", text)

func afficher_erreur(msg: String):
	_set_statut("⚠️ " + msg, Color.ORANGE)
	print("ERREUR : ", msg)
