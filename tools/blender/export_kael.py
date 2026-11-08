"""Re-export the saved, possibly hand-edited kael.blend without regenerating it.

blender --background --factory-startup --python tools/blender/export_kael.py
"""
import sys
from pathlib import Path

import bpy

if not bpy.app.background:
    raise RuntimeError("Use a separate Blender --background process.")
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_kael import OUT, export_asset

bpy.ops.wm.open_mainfile(filepath=str(OUT / "kael.blend"))
export_asset()
