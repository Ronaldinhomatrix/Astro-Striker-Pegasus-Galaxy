# Astro Striker — Pegasus Galaxy (NOTES.md)

Projeto: Shoot'em up arcade 3D estilo Novastorm (1994).
Engine: Godot 4.7, renderizador forward_plus.
Janela: paisagem 1920x1080.

## Cena principal
scenes/game.tscn

## Arquitetura (conceito-chave)
Path3D = caminho que a CAMERA percorre automaticamente.
A nave é filha do PathFollower; herda movimento/rotação.
Jogador controla apenas X/Y (plano da tela).

Estrutura:
Game (Node3D, game_controller.gd)
├── WorldEnvironment (céu espacial, iluminação diurna)
├── DirectionalLight3D
├── FlightPath (Path3D)  ← caminho da câmera
│   └── PathFollower (PathFollow3D, path_follower.gd)
│       ├── Camera3D (current)
│       └── Player (CharacterBody3D, player.gd) — nave
├── HUD (CanvasLayer, pontuação)
└── Mountains1 (terreno GLTF, material de detalhe aplicado em runtime)

## Arquivos importantes
- scripts/world/path_follower.gd — avança no path; câmera com look_ahead + turn_smoothing
- scripts/player/player.gd — nave: segue ponteiro/WASD, limites por frustum, tiro
- scripts/world/game_controller.gd — HUD/pontuação, aplica material do terreno em runtime
- scripts/projectiles/bullet.gd — projétil (viagem reta, colisão, auto-destruição por distância)
- resources/flight_curve.tres — Curve3D do caminho
- scenes/player.tscn, scenes/bullet.tscn

## Decisões / pontos importantes
- NÃO usar renderizador mobile (causa artefatos em malhas double-sided). Usar forward_plus.
- Movimentação manual no editor exige Ctrl+S antes do agente mexer; senão force_reload descarta.
- Asset de terreno: usar modelos manifold/low-poly (o mountains_1 atual é adequado).
- Erro benigno do plugin MCP "Capture already registered: 'mcp'" — ignorar.
- Detalhe de textura do terreno: StandardMaterial3D nativo (assets/materials/terrain_detailed.tres)
  com detail texturing; aplicado em RUNTIME no game_controller.gd (o terreno é instância GLTF,
  então material_override não persiste no .tscn).

## Plugin Path Point Inserter
Local: addons/path_point_inserter/
Uso: selecionar o nó FlightPath → voar no editor 3D (segurar botão DIREITO do mouse + WASD/QE)
→ pressionar F8 (ou botão "Path+") para cravar um ponto na posição da câmera.
A curva é salva no disco automaticamente a cada ponto.

## Fluxo de trabalho (acordos)
- NÃO fazer commit/push a cada prompt; o usuário faz manualmente ao fim do dia.
- Salvar alterações LOCALMENTE antes de qualquer desligamento.
- O agente PODE desligar o PC ao final da tarefa quando o prompt incluir "salve tudo e desligue".