class_name Player
extends CharacterBody3D

## Nave do jogador — estilo Novastorm (1994).
## A nave é FILHA do PathFollower (que percorre o Path3D), então herda
## automaticamente o movimento e a rotação do caminho.
##
## Controle:
##   - Mouse / Toque (dedo): a nave segue a posição do ponteiro na tela.
##   - Teclado (WASD / Setas): alternativa para movimentação lateral/vertical.
##
## Os limites de movimento são calculados DINAMICAMENTE a partir do frustum
## da câmera, para que a nave percorra quase toda a área visível da tela.

# ---------------------------------------------------------------------------
# Exportações e Configurações
# ---------------------------------------------------------------------------

@export_category("Movimento")
@export var speed: float = 40.0
@export var forward_offset: float = -40.0  # Distância à frente da câmera (Z local)

@export_category("Area de Movimento (fração da tela)")
@export_range(0.0, 1.0) var screen_margin: float = 0.88  # 0.88 = nave percorre 88% da área visível
@export_range(0.0, 1.0) var up_screen_fraction: float = 0.85  # Limite superior: nave sobe até 85% da área superior

@export_category("Mouse / Toque")
@export var pointer_follow_speed: float = 12.0  # Suavidade de seguir o ponteiro

@export_category("Inclinacao (Juice)")
@export var roll_amount: float = 0.6
@export var pitch_amount: float = 0.3
@export var rotation_speed: float = 8.0

@export_category("Combate")
@export var fire_rate: float = 0.12
@export var bullet_scene: PackedScene = null

# ---------------------------------------------------------------------------
# Estado Interno
# ---------------------------------------------------------------------------

var _is_firing: bool = false
var _fire_timer: float = 0.0

var _pointer_active: bool = false
var _pointer_pos: Vector2 = Vector2.ZERO

# Extensões visíveis (half width, half height) no plano da nave
var _half_w: float = 30.0
var _half_h: float = 30.0
var _max_up: float = 30.0  # Limite vertical superior (para cima)
var _recent_move_local: Vector3 = Vector3.ZERO
var _target_local_pos: Vector3 = Vector3.ZERO

@onready var ship_model: Node3D = $ShipModel

# ---------------------------------------------------------------------------
# Ciclo de Vida
# ---------------------------------------------------------------------------

func _ready() -> void:
	var col_shape := $CollisionShape3D as CollisionShape3D
	if col_shape and col_shape.shape is BoxShape3D:
		col_shape.shape.size = Vector3(5, 2.5, 9)

	position = Vector3(0.0, 0.0, forward_offset)
	_target_local_pos = position


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer_pos = event.position
		_pointer_active = true
	elif event is InputEventScreenTouch:
		_pointer_pos = event.position
		_pointer_active = event.pressed
	elif event is InputEventScreenDrag:
		_pointer_pos = event.position
		_pointer_active = true

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_firing = event.pressed
	elif event is InputEventScreenTouch:
		_is_firing = event.pressed


# ---------------------------------------------------------------------------
# Processamento por Frame
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_screen_extents()

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length_squared() > 0.001:
		_pointer_active = false

	if _pointer_active:
		_update_pointer_target()
	else:
		_update_keyboard_target(input_dir, delta)

	# Limita o alvo para os limites da tela
	_target_local_pos.x = clampf(_target_local_pos.x, -_half_w, _half_w)
	_target_local_pos.y = clampf(_target_local_pos.y, -_half_h, _max_up)
	_target_local_pos.z = forward_offset

	# Interpolação suave para a posição atual (suaviza teclado e ponteiro)
	var follow := clampf(pointer_follow_speed * delta, 0.0, 1.0)
	var old_pos := position
	position = position.lerp(_target_local_pos, follow)
	_recent_move_local = position - old_pos

	_handle_ship_rotation(delta)

	if _is_firing or Input.is_action_pressed("ui_select"):
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = fire_rate
			_spawn_bullet()
	else:
		_fire_timer = maxf(0.0, _fire_timer - delta)


# ---------------------------------------------------------------------------
# Calcula a área visível no plano da nave a partir do frustum da câmera
# ---------------------------------------------------------------------------

func _update_screen_extents() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	# A câmera e a nave são ambas filhas do PathFollower; a distância ao longo
	# do eixo Z local entre elas define a profundidade do plano da nave.
	var cam_z: float = cam.position.z
	var distance := absf(cam_z - forward_offset)
	if distance < 0.001:
		return

	var half_height := tan(deg_to_rad(cam.fov) * 0.5) * distance
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 0.001)
	var half_width := half_height * aspect

	# Aplica a margem (fração da área visível)
	_half_w = half_width * screen_margin
	_half_h = half_height * screen_margin

	# Limite superior: a nave sobe até uma fração da metade superior
	_max_up = _half_h * up_screen_fraction


# ---------------------------------------------------------------------------
# Atualização da posição alvo pelo ponteiro (mouse/toque)
# ---------------------------------------------------------------------------

func _update_pointer_target() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x < 0.001 or vp_size.y < 0.001:
		return

	var normalized := Vector2(
		(_pointer_pos.x / vp_size.x) * 2.0 - 1.0,
		(_pointer_pos.y / vp_size.y) * 2.0 - 1.0
	)

	# Mapeia o ponteiro normalizado para os limites visíveis.
	# Lateral: simétrico (-_half_w .. +_half_w).
	# Vertical: base (pointer.y=+1) desce até -_half_h;
	#           topo (pointer.y=-1) sobe até +_max_up (85% da área superior).
	var up_limit := _max_up
	var down_limit := -_half_h
	var y_range := (up_limit - down_limit) * 0.5
	var y_center := (up_limit + down_limit) * 0.5
	
	_target_local_pos = Vector3(
		normalized.x * _half_w,
		-normalized.y * y_range + y_center,
		forward_offset
	)


# ---------------------------------------------------------------------------
# Atualização da posição alvo pelo teclado (WASD / Setas)
# ---------------------------------------------------------------------------

func _update_keyboard_target(input_dir: Vector2, delta: float) -> void:
	# O teclado move a posição alvo local diretamente de forma contínua
	_target_local_pos.x += input_dir.x * speed * delta
	_target_local_pos.y -= input_dir.y * speed * delta
	_target_local_pos.z = forward_offset


# ---------------------------------------------------------------------------
# Rotação Estética (Juice)
# ---------------------------------------------------------------------------

func _handle_ship_rotation(delta: float) -> void:
	if not ship_model:
		return

	var dir_x := clampf(_recent_move_local.x / maxf(1.0, speed * delta), -1.0, 1.0)
	var dir_y := clampf(_recent_move_local.y / maxf(1.0, speed * delta), -1.0, 1.0)

	ship_model.rotation.z = lerpf(ship_model.rotation.z, -dir_x * roll_amount, rotation_speed * delta)
	ship_model.rotation.x = lerpf(ship_model.rotation.x, dir_y * pitch_amount, rotation_speed * delta)
	ship_model.rotation.y = lerpf(ship_model.rotation.y, -dir_x * 0.25, rotation_speed * delta)


# ---------------------------------------------------------------------------
# Sistema de Armas
# ---------------------------------------------------------------------------

func _spawn_bullet() -> void:
	if not bullet_scene:
		return

	var spawn_offset := Vector3(0.0, 0.0, -4.0)
	var spawn_pos := global_position + global_basis * spawn_offset

	var bullet: Bullet = bullet_scene.instantiate() as Bullet
	if not bullet:
		return

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos
	bullet.setup(-global_basis.z.normalized())


func stop_firing() -> void:
	_is_firing = false
	_fire_timer = 0.0
