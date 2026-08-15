class_name Bullet
extends Area3D

## Projétil que viaja em linha reta e causa dano ao colidir.
##
## ARQUITETURA:
## - Viaja em direção definida via setup().
## - Colisão detectada via signals (body_entered, area_entered).
## - Auto-destrói ao sair da área de jogo.
## - O dano é tratado pelo alvo (target recebe o sinal e processa).

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

const SPEED: float = 800.0

# ---------------------------------------------------------------------------
# Propriedades exportadas
# ---------------------------------------------------------------------------

@export var damage: int = 1

# Distância máxima antes de auto-destruir (evita bullets eternos).
@export var max_distance: float = 2000.0

# ---------------------------------------------------------------------------
# Estado interno
# ---------------------------------------------------------------------------

var _direction: Vector3 = Vector3.FORWARD
var _spawn_position: Vector3 = Vector3.ZERO

# ---------------------------------------------------------------------------
# Ciclo de vida
# ---------------------------------------------------------------------------

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_spawn_position = global_position


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

func setup(dir: Vector3) -> void:
	## Define a direção de viagem.
	_direction = dir.normalized()


# ---------------------------------------------------------------------------
# Processamento
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	global_position += _direction * SPEED * delta

	# Auto-destrói se ultrapassar distância máxima
	if global_position.distance_squared_to(_spawn_position) > max_distance * max_distance:
		queue_free()

	# Fallback: remove se sair completamente da área visível
	if absf(global_position.x) > 800 or absf(global_position.y) > 800 or absf(global_position.z) > 800:
		queue_free()


# ---------------------------------------------------------------------------
# Colisões
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	## Colisão com corpo físico.
	# Futuro: verificar se o corpo implementa interface IDamageable
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		return

	# Colisão com paredes/obstáculos: apenas destrói o projétil
	if not body is CharacterBody3D:  # Não destrói ao colidir com CharacterBody (nave)
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	## Colisão com outra área (ex: área de dano, escudo).
	# Futuro: sistema de dano em área
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()