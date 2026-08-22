import os
import sys

# Add the project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scripts.tools.normalize_level import NormalizeLevel

normalizer = NormalizeLevel.new()
result = normalizer.normalize('assets/models/levels/grand_canyon.glb', 1000.0)
print('Resultado:', result)