# Astro Striker: Pegasus Galaxy - Documentação de Criação de Níveis

## Visão Geral
Sistema para criar níveis 3D consistentes sem ajustes manuais de escala, câmera ou física.

## Arquitetura do Sistema

### 1. `resources/level_defaults.tres`
Resource centralizado com todas as configurações padrão:
- `camera_fov`: 56.25
- `camera_offset_z`: 33.85669
- `player_forward_offset`: -40.0
- `player_bounce_strength`: 320.0
- `player_bounce_damping`: 15.0
- `path_forward_speed`: 95.0
- `ship_scale`: 1.5
- `collider_size`: Vector3(5, 2.5, 9)

### 2. `scenes/stages/_level_template.tscn`
Template de cena base com:
- WorldEnvironment, DirectionalLight3D configurados
- Game node com referências para PathFollower e Player
- Camera3D com fov=56.25 e offset Z=33.85669
- Player com fire_rate=0.5, bounce_strength=320.0, bounce_damping=15.0
- HighBridge placeholder

### 3. `scripts/tools/normalize_level.gd`
Ferramenta para normalizar cenários 3D importados:
- Calcula o AABB do modelo
- Determina escala para largura alvo (padrão: 1000.0)
- Salva como `.tscn` normalizado
- Funcão `inspect()` para debug

### 4. `scenes/stages/level_*.tscn`
Cada nível segue este fluxo:
1. Duplicar `_level_template.tscn` → `level_X.tscn`
2. Substituir o nó do cenário pelo novo asset **já normalizado**
3. Ajustar apenas o `Path3D` (curva de voo) e decoração
4. **Zero ajustes de escala/câmera/física necessários**

## Fluxo de Criação de Novo Nível

### Passo 1: Importar o modelo 3D
```bash
# Baixar/colocar o novo modelo em assets/models/levels/
# Ex: new_canyon.glb
```

### Passo 2: Normalizar o modelo
```gdscript
# No script ou console GDScript:
var normalizer = load("res://scripts/tools/normalize_level.gd").new()
var result_path = normalizer.normalize("res://assets/models/levels/new_canyon.glb", 1000.0)
print("Normalizado para: ", result_path)
# Resultado: new_canyon_normalized.tscn com escala calculada
```

### Passo 3: Criar o nível
```bash
# Duplicar o template:
# cp scenes/stages/_level_template.tscn scenes/stages/level_3.tscn

# Substituir o nó do cenário:
# - Remover nó "Mountains1" ou "GrandCanyon"
# - Adicionar o novo modelo normalizado
#   instance = ExtResource("res://assets/models/levels/new_canyon_normalized.tscn")

# Opcional: ajustar Path3D para a nova curva de voo
# Opcional: adicionar decoração, obstáculos, inimigos
```

### Passo 4: Testar
```bash
# Executar o nível
# Verificar que:
# - Nave tem o mesmo tamanho visual em todos os níveis
# - Câmera tem o mesmo FOV e distância
# - Velocidade da nave é consistente
# - Colisão funciona corretamente
```

## Exemplos

### level_1.tscn (GrandCanyon)
- Cenário: GrandCanyon (originalmente 25x de escala)
- Após normalização: escala ajustada automaticamente para largura 1000
- Configurações aplicadas via `LevelDefaults.apply_to_scene()`

### level_2.tscn (Mountains1)
- Cenário: Mountains1 (originalmente 0.01x de escala)
- Após normalização: escala ajustada automaticamente para largura 1000
- Configurações aplicadas via `LevelDefaults.apply_to_scene()`

## Migração de Níveis Existentes

### level_1.tscn (GrandCanyon)
**Problema original:**
- Cenário com escala 25x
- Nave com escala 1.5 (visual) + colisor 5×2.5×9
- forward_offset = -40 (câmera→nave)

**Migração:**
1. Normalizar o GrandCanyon: `normalize_level.normalize("res://assets/models/levels/grand_canyon.glb", 1000.0)`
2. O resultado terá escala calculada para largura 1000
3. Substituir o nó GrandCanyon no level_1.tscn pelo modelo normalizado
4. O `LevelDefaults.apply_to_scene()` aplicará automaticamente:
   - ship_scale = 1.5 (permanece)
   - collider_size = Vector3(5, 2.5, 9) (permanece)
   - camera_fov = 56.25 (permanece)
   - path_forward_speed = 95.0 (permanece)

### level_2.tscn (Mountains1)
**Problema original:**
- Cenário com escala 0.01x (muito pequeno)
- Mesmo problema de consistência

**Migração:**
1. Normalizar o Mountains1: `normalize_level.normalize("res://assets/models/levels/mountains_1/scene.gltf", 1000.0)`
2. Substituir o nó Mountains1 no level_2.tscn pelo modelo normalizado
3. `LevelDefaults.apply_to_scene()` aplica configurações padrão

## Mapa da Estrutura de Nível (referência rápida)

> Esta é a anatomia padrão de um nível. Entender isto evita confusão ao
> reposicionar a nave, redesenhar a rota ou trocar o cenário.

```
Game (Node3D + game_controller.gd)
├─ WorldEnvironment
├─ DirectionalLight3D
├─ <Cenário>          (ex: GrandCanyon, Mountains1 — modelo normalizado)
├─ <Decoração>        (ex: HighBridge)
└─ FlightPath (Path3D)             ← a curva de voo (selecione para desenhar)
   └─ PathFollower (PathFollow3D + path_follower.gd)
      ├─ Camera3D                  ← offset (0, 0, +33.85669), fov 56.25, current
      └─ Player (instância de player.tscn)  ← posição local (0, 0, -40)
```

**Regras importantes:**

- **A nave (Player) NÃO vive solta no mundo**: ela é filha do `PathFollower`,
  que desliza sobre a curva do `Path3D`. Por isso o `game_controller.gd` usa
  `node_paths` (`path_follower`, `player`) e os caminhos
  `FlightPath/PathFollower` e `FlightPath/PathFollower/Player`.

- **Para reposicionar a nave no editor**: mova o nó **`FlightPath`** (o Path3D),
  não o `Player` diretamente — o PathFollow3D recalcula a posição local da nave.

- **Para redesenhar a rota**: selecione o nó **`FlightPath`** e use a ferramenta
  **Path** da barra superior do viewport 3D. Não delete o `FlightPath`
  (levaria nave + câmera junto). Para recomeçar do zero, limpe a `curve`
  (Curve3D) mantendo PathFollower/nave/câmera.

- **Velocidade de avanço** da nave é o `forward_speed` no **`PathFollower`**
  (categoria "Movimento ao Longo do Path"). O `speed` no `Player` controla
  apenas a manobra lateral/tela (mouse/teclado/toque), não o avanço na rota.

- **Raiz do nível** chama-se **`Game`** (padrão alinhado entre
  `_level_template.tscn`, `level_1.tscn` e `level_2.tscn`).

## Boas Práticas

### ✅ Fazer
- Sempre normalizar modelos 3D antes de usar em níveis
- Usar `LevelDefaults.apply_to_scene()` como ponto de partida
- Manter o `Path3D`/curva de voo como a principal variável de diferencial entre níveis
- Testar a consistência visual entre níveis (posição da nave na tela)

### ❌ Evitar
- Ajustar manualmente `ShipModel.scale` entre níveis
- Mudar `Camera3D.fov` por nível (a menos que haja motivo artístico)
- Alterar `forward_offset` sem necessidade
- Esquecer de normalizar o modelo (causa escala inconsistente)

## Solução de Problemas

### Nave parece muito grande/pequena
1. Verificar se o modelo foi normalizado
2. Confirmar que `LevelDefaults.apply_to_scene()` foi chamado
3. Verificar `ship_scale` no `level_defaults.tres`

### Câmera "colada" ou "muito longe"
1. Verificar `camera_fov` e `camera_offset_z` no resource
2. O offset Z é calculado automaticamente baseado no AABB do modelo

### Colisão não funciona
1. Confirmar que `collider_size` no `level_defaults.tres` corresponde ao `BoxShape3D` no `player.tscn`
2. Verificar se o modelo normalizado não tem colisores conflitantes

## Próximos Desenvolvimentos
- [ ] Integrar `LevelDefaults.apply_to_scene()` no `_ready()` de cada nível
- [ ] Criar validação automática ao carregar nível
- [ ] Adicionar atalhos de editor para normalização rápida
- [ ] Documentar exemplos de Path3D para diferentes tipos de nível