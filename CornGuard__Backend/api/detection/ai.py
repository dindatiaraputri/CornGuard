"""Penghubung Django ke paket ai_service (satu tempat untuk mengatur sys.path)."""
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
AI_SERVICE_DIR = PROJECT_ROOT / "ai_service"

if not (AI_SERVICE_DIR / "app" / "detector.py").is_file():
    raise FileNotFoundError(f"detector.py tidak ditemukan di: {AI_SERVICE_DIR}")

if str(AI_SERVICE_DIR) not in sys.path:
    sys.path.insert(0, str(AI_SERVICE_DIR))

from app.pipeline import PipelineNotReady  # noqa: E402,F401
from app.registry import get_detector, get_pipeline, load_models  # noqa: E402,F401
from app.registry import status as model_status  # noqa: E402,F401
