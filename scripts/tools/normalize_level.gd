class_name NormalizeLevel
extends RefCounted

## Ferramenta para normalizar cenários 3D importados.
##
## Calcula a escala necessária para que um modelo 3D tenha uma largura padrão
## (ex: 1000 unidades), garantindo consistência entre níveis.
##
## Uso:
##   var normalizer = NormalizeLevel.new()
##   normalizer.normalize("res://assets/models/levels/new_canyon.glb", 1000.0)
##   # Resultado: new_canyon_normalized.tscn

const DEFAULT_TARGET_WIDTH := 1000.0


## Normaliza um cenário 3D para uma largura alvo.
## Salva o resultado como .tscn com a escala calculada.
func normalize(source_path: String, target_width: float = DEFAULT_TARGET_WIDTH) -> String:
	var scene: PackedScene = load(source_path) as PackedScene
	if not scene:
		push_error("NormalizeLevel: não foi possível carregar " + source_path)
		return ""
	
	var instance: Node = scene.instantiate()
	
	# Calcula o AABB do modelo
	var aabb := _calculate_aabb(instance)
	if aabb.size.length_squared() < 0.001:
		push_error("NormalizeLevel: modelo vazio ou inválido")
		instance.free()
		return ""
	
	# Calcula a escala necessária
	var current_width := aabb.size.x
	var scale_factor := target_width / current_width
	
	print("NormalizeLevel: AABB original = ", aabb.size)
	print("NormalizeLevel: largura atual = ", current_width)
	print("NormalizeLevel: escala calculada = ", scale_factor)
	
	# Cria a cena normalizada
	var root := Node3D.new()
	root.name = "NormalizedLevel"
	
	var model_node := Node3D.new()
	model_node.name = "Model"
	model_node.scale = Vector3(scale_factor, scale_factor, scale_factor)
	root.add_child(model_node)
	
	# Move os filhos do instance para model_node
	for child in instance.get_children():
		child.get_parent().remove_child(child)
		model_node.add_child(child)
	
	instance.free()
	
	# Garante que todos os nós sejam serializados na cena (owner correto)
	root.owner = null
	_set_owner_recursive(model_node, root)
	
	# Salva a cena
	var output_path := source_path.get_basename() + "_normalized.tscn"
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("NormalizeLevel: falha ao empacotar cena: ", err)
		root.free()
		return ""
	
	var save_err := ResourceSaver.save(packed, output_path)
	if save_err != OK:
		push_error("NormalizeLevel: falha ao salvar: ", save_err)
		root.free()
		return ""
	
	print("NormalizeLevel: salvo em ", output_path)
	root.free()
	return output_path


## Define o owner recursivamente para que a cena seja serializada corretamente.
func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)


## Calcula o AABB de todos os MeshInstance3D na árvore.
func _calculate_aabb(root: Node) -> AABB:
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var acc: Transform3D = item[1]
		
		if node is Node3D:
			acc = acc * node.transform
		
		if node is MeshInstance3D and node.mesh:
			var mesh_aabb: AABB = acc * node.mesh.get_aabb()
			min_v = min_v.min(mesh_aabb.position)
			max_v = max_v.max(mesh_aabb.position + mesh_aabb.size)
		
		for child in node.get_children():
			stack.append([child, acc])
	
	if min_v.x == INF:
		return AABB()
	
	return AABB(min_v, max_v - min_v)


## Retorna informações sobre o modelo (para debug/inspeção).
func inspect(source_path: String) -> Dictionary:
	var scene: PackedScene = load(source_path) as PackedScene
	if not scene:
		return {"error": "não foi possível carregar " + source_path}
	
	var instance: Node = scene.instantiate()
	var aabb := _calculate_aabb(instance)
	instance.free()
	
	return {
		"path": source_path,
		"aabb_min": aabb.position,
		"aabb_max": aabb.position + aabb.size,
		"aabb_size": aabb.size,
		"width": aabb.size.x,
		"height": aabb.size.y,
		"depth": aabb.size.z,
	}