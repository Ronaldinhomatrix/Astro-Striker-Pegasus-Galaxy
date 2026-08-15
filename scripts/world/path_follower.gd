class_name PathFollower
extends PathFollow3D

## Avança automaticamente ao longo da trajetória definida por um Path3D pai.
## A CÂMERA (filha deste nó) acompanha o Path3D.
## A câmera olha na direção do movimento (tangente da curva), sem "strafe".
## A direção de mira é suavizada para que as mudanças de direção sejam fluidas
## (sem "socos"), mantendo a câmera sempre apontada para onde se desloca.

# ---------------------------------------------------------------------------
# Exportações e Configurações
# ---------------------------------------------------------------------------

@export_category("Movimento ao Longo do Path")
@export var forward_speed: float = 65.0  ## Unidades por segundo ao longo da curva

@export_category("Suavizacao da Curva")
@export var look_ahead: float = 5.0  ## Distância à frente (unidades) usada para mirar. Antecipa as curvas.
@export var turn_smoothing: float = 4.0  ## Rapidez de suavizar a direção (maior = responde mais rápido/menos suave)

# ---------------------------------------------------------------------------
# Estado Interno
# ---------------------------------------------------------------------------

var _paused: bool = false
var _smoothed_forward: Vector3 = Vector3.ZERO
var _forward_initialized: bool = false

# ---------------------------------------------------------------------------
# Ciclo de Vida
# ---------------------------------------------------------------------------

func _ready() -> void:
	# ROTATION_NONE: controlamos a rotação manualmente para suavizar as curvas.
	rotation_mode = RotationMode.ROTATION_NONE
	_forward_initialized = false


func _physics_process(delta: float) -> void:
	if _paused:
		return

	progress += forward_speed * delta

	# Alinha a câmera à direção do movimento, suavizando a mudança de direção.
	_align_to_path(delta)


# ---------------------------------------------------------------------------
# Alinhamento da Direção
# ---------------------------------------------------------------------------

func _align_to_path(delta: float) -> void:
	var curve := get_parent() as Path3D
	if not curve or not curve.curve or curve.curve.point_count < 2:
		return

	var c: Curve3D = curve.curve

	# Direção alvo: um ponto À FRENTE na curva (no sentido do movimento).
	# Isso mantém a câmera sempre olhando para onde se desloca (sem "strafe")
	# enquanto antecipa suavemente as curvas.
	var here := c.sample_baked(progress, true)
	var ahead := c.sample_baked(progress + look_ahead, true)
	var raw_forward := ahead - here
	if raw_forward.length_squared() < 0.000001:
		return
	raw_forward = raw_forward.normalized()

	# Inicializa a direção suavizada na primeira chamada (evita salto inicial).
	if not _forward_initialized:
		_smoothed_forward = raw_forward
		_forward_initialized = true

	# Suavização exponencial DA DIREÇÃO DE MIRA (não da rotação final).
	# Isso remove os "socos" nas trocas de direção sem introduzir o atraso
	# posicional que causava o "strafe" (aplicamos a base resultante
	# diretamente, sem lag entre posição e rotação).
	var t := 1.0 - exp(-turn_smoothing * delta)
	_smoothed_forward = _smoothed_forward.slerp(raw_forward, t).normalized()
	var forward := _smoothed_forward

	# Up da curva (mantém o horizonte estável).
	var up := c.sample_baked_up_vector(progress, true)

	var right := up.cross(forward).normalized()
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	var corrected_up := forward.cross(right).normalized()

	# Aplica diretamente: -Z (frente da câmera) aponta para a direção suavizada.
	global_transform.basis = Basis(right, corrected_up, -forward).orthonormalized()


# ---------------------------------------------------------------------------
# API Pública
# ---------------------------------------------------------------------------

func set_paused(paused: bool) -> void:
	_paused = paused


func reset_progress() -> void:
	progress = 0.0
	_forward_initialized = false