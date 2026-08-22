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
@export var forward_speed: float = 65.0  ## Velocidade base (unidades por segundo ao longo da curva)
## Curva de velocidade opcional: eixo X = progresso do caminho (0 a 1),
## eixo Y = multiplicador de velocidade (0 = parado, 1 = velocidade base, 2 = dobro).
## Desenhe a curva no inspector para ter trechos rápidos/lentos.
@export var speed_curve: Curve

@export_category("Suavizacao da Curva")
@export var look_ahead: float = 5.0  ## Distância à frente (unidades) usada para mirar. Antecipa as curvas.
@export var turn_smoothing: float = 4.0  ## Rapidez de suavizar a direção (maior = responde mais rápido/menos suave)

@export_category("Tilt da Curva (Bank)")
@export var tilt_intensity: float = 0.25  ## Intensidade do tilt nas curvas (0 = sem tilt, valores maiores = mais tilt)
@export var tilt_smoothing: float = 3.0  ## Suavização do tilt (maior = responde mais rápido)
@export_range(0.0, 90.0) var max_tilt_degrees: float = 35.0  ## Ângulo máximo de inclinação (graus)

# ---------------------------------------------------------------------------
# Estado Interno
# ---------------------------------------------------------------------------

var _paused: bool = false
var _smoothed_forward: Vector3 = Vector3.ZERO
var _forward_initialized: bool = false
var _smoothed_tilt: float = 0.0  ## Tilt suavizado (roll em radians)
var _prev_forward: Vector3 = Vector3.ZERO  ## Direção anterior (para calcular taxa de curva)

# ---------------------------------------------------------------------------
# Ciclo de Vida
# ---------------------------------------------------------------------------

func _ready() -> void:
	# ROTATION_NONE: controlamos a rotação manualmente para suavizar as curvas.
	rotation_mode = RotationMode.ROTATION_NONE
	_forward_initialized = false
	_prev_forward = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _paused:
		return

	progress += _current_speed() * delta

	# Alinha a câmera à direção do movimento, suavizando a mudança de direção.
	_align_to_path(delta)


# ---------------------------------------------------------------------------
# Velocidade atual (base + curva de velocidade opcional)
# ---------------------------------------------------------------------------

## Retorna a velocidade atual, levando em conta a curva de velocidade.
## Se `speed_curve` estiver definida, o progresso normalizado (0-1) é usado
## como entrada e o valor da curva (Y) multiplica a velocidade base.
func _current_speed() -> float:
	if speed_curve and speed_curve.point_count > 0:
		var parent_path := get_parent() as Path3D
		var total := 1.0
		if parent_path and parent_path.curve:
			total = maxf(parent_path.curve.get_baked_length(), 0.001)
		var normalized := clampf(progress / total, 0.0, 1.0)
		var factor := speed_curve.sample_baked(normalized)
		# Salvaguarda: nunca deixa a velocidade chegar a zero (evita travar).
		return forward_speed * clampf(factor, 0.1, 10.0)
	return forward_speed


# ---------------------------------------------------------------------------
# Alinhamento da Direção
# ---------------------------------------------------------------------------

func _align_to_path(delta: float) -> void:
	var curve := get_parent() as Path3D
	if not curve or not curve.curve or curve.curve.point_count < 2:
		return

	var c: Curve3D = curve.curve

	# SALVAGUARDA: Se a curva tem pontos zero no início, o sample_baked
	# retorna (0,0,0) e a câmera/nave ficam presas na origem. Detectamos
	# isso e pulamos o frame para evitar o erro "Zero length interval".
	var first_point := c.get_point_position(0)
	if first_point.length_squared() < 0.0001 and c.point_count > 1:
		# O primeiro ponto é zero — a curva está corrompida. Tenta usar
		# o segundo ponto como referência para não travar.
		first_point = c.get_point_position(1)
		if first_point.length_squared() < 0.0001:
			return  # Curva totalmente corrompida, não faz nada.

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

	# -----------------------------------------------------------------------
	# Tilt (Bank) — inclinação nas curvas como um avião
	# -----------------------------------------------------------------------
	# Calcula a taxa de curva (velocidade angular) comparando a direção atual
	# com a anterior. Quanto mais rápido a direção muda, maior o tilt.
	var angular_velocity: float = 0.0
	if _prev_forward.length_squared() > 0.0001:
		# O ângulo entre os vetores (em radians) representa a taxa de curva
		var dot := clampf(_prev_forward.dot(forward), -1.0, 1.0)
		angular_velocity = acos(dot) / maxf(delta, 0.0001)
		
		# Detecta o lado da curva (esquerda vs direita) usando produto vetorial
		var cross := _prev_forward.cross(forward)
		var sign: float = signf(cross.y)  # Y positivo = curva para esquerda
		angular_velocity *= sign
	
	_prev_forward = forward
	
	# Tilt alvo: proporcional à taxa de curva
	# Inclina para DENTRO da curva (sinal negativo para inclinar corretamente)
	var target_tilt: float = -angular_velocity * tilt_intensity
	
	# Limita o ângulo máximo de tilt (converte graus para radians)
	var max_tilt_rad := deg_to_rad(max_tilt_degrees)
	target_tilt = clampf(target_tilt, -max_tilt_rad, max_tilt_rad)
	
	# Suaviza o tilt (resposta exponencial)
	var tilt_t := 1.0 - exp(-tilt_smoothing * delta)
	_smoothed_tilt = lerpf(_smoothed_tilt, target_tilt, tilt_t)
	
	# Up da curva com tilt aplicado (roll no eixo forward)
	var up := Vector3.UP
	
	# Aplica o roll (tilt) rotacionando o up ao redor do forward
	var tilted_up := up.rotated(forward, _smoothed_tilt)

	# Ordem correta para uma base RIGHT-HANDED (não espelhada):
	# right = forward x up  e  up = right x forward.
	var right := forward.cross(tilted_up).normalized()
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	var corrected_up := right.cross(forward).normalized()

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