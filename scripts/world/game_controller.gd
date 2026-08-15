class_name GameController
extends Node3D

## Controlador central do jogo.
## Gerencia HUD, pontuação e referências aos componentes principais.
## O movimento ao longo do Path3D é controlado por PathFollower.

# ---------------------------------------------------------------------------
# Exportações e Configurações
# ---------------------------------------------------------------------------

@export_category("Componentes")
@export var path_follower: PathFollower = null
@export var player: Node3D = null
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

# ---------------------------------------------------------------------------
# Estado Interno
# ---------------------------------------------------------------------------

var _score: float = 0.0

@onready var score_label: Label = $HUD/MarginContainer/ScoreLabel

# ---------------------------------------------------------------------------
# Ciclo de Vida
# ---------------------------------------------------------------------------

func _ready() -> void:
	if not path_follower:
		path_follower = get_node_or_null("FlightPath/PathFollower") as PathFollower
	
	if not player:
		player = get_node_or_null("FlightPath/PathFollower/Player")
		if not player and path_follower:
			var p_instance := player_scene.instantiate() as Node3D
			path_follower.add_child(p_instance)
			p_instance.name = "Player"
			p_instance.position = Vector3(0.0, 0.0, -40.0)
			player = p_instance


func _physics_process(_delta: float) -> void:
	if not path_follower:
		return

	# Pontuação baseada na distância percorrida ao longo do Path
	_score = path_follower.progress * 0.1
	_update_hud()


func _update_hud() -> void:
	if score_label:
		score_label.text = "PONTUAÇÃO: %06d" % int(_score)
