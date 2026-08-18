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

@export_category("Cenario")
@export var terrain_detail_material: Material = preload("res://assets/materials/terrain_detailed.tres")

# ---------------------------------------------------------------------------
# Estado Interno
# ---------------------------------------------------------------------------

var _collision_generated: bool = false

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

	_apply_terrain_detail_material()
	_generate_world_collision()


func _apply_terrain_detail_material() -> void:
	if terrain_detail_material == null:
		return
	# O terreno é uma instância GLTF; aplica o material de detalhe em runtime
	# em todos os MeshInstance3D aninhados, pois o override não persiste no .tscn.
	var mountains := get_node_or_null("Mountains1")
	if not mountains:
		return
	var stack: Array = [mountains]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			(node as MeshInstance3D).material_override = terrain_detail_material
		for child in node.get_children():
			stack.append(child)


func _generate_world_collision() -> void:
	## Gera colisão física (trimesh) para o terreno para que os tiros possam
	## detectar acertos via raycast. O terreno GLTF vem apenas com malha visual
	## e sem colisor, então criamos StaticBody3D + CollisionShape3D em modo
	## "concave" (trimesh) automaticamente, uma única vez, no primeiro _ready.
	if _collision_generated:
		return

	var mountains := get_node_or_null("Mountains1")
	if not mountains:
		return

	for child in mountains.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue

		# Trimesh collision gera um ConcavePolygonShape3D a partir da malha.
		mesh_instance.create_trimesh_collision()

		# O colisor recém-criado vira filho do MeshInstance3D. Corrige a camada
		# para "world" (layer 4) para o raycast do projétil poder filtrar.
		var body := mesh_instance.get_node_or_null("StaticBody3D") as StaticBody3D
		if not body:
			# Godot nomeia o corpo gerado de "StaticBody3D" (ou auto-nome).
			for c in mesh_instance.get_children():
				if c is StaticBody3D:
					body = c as StaticBody3D
					break
		if body:
			body.collision_layer = 1 << 3  # layer 4 ("world")
			body.collision_mask = 0
			# A malha do terreno é double-sided (doubleSided no GLTF), mas o
			# trimesh só colide com faces "da frente" por padrão. Habilitar
			# backface_collision faz o tiro reconhecer a superfície dos DOIS
			# lados, resolvendo as regiões onde o tiro atravessava sem explodir.
			for col in body.find_children("*", "CollisionShape3D", false, false):
				var cs := col as CollisionShape3D
				if cs and cs.shape is ConcavePolygonShape3D:
					(cs.shape as ConcavePolygonShape3D).backface_collision = true

	_collision_generated = true
