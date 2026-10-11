"""Memuat model SEKALI saat server start, lalu dipakai ulang oleh semua request."""
import logging
import threading

import numpy as np

from .classifier import ONNXClassifier
from .detector import YOLODetector
from .pipeline import HybridPipeline

log = logging.getLogger(__name__)

_lock = threading.Lock()
_detector = None
_classifier = None
_pipeline = None
_errors = {}


def load_models(force=False):
    """Muat YOLO (wajib) dan MobileNet (jika berkasnya sudah ada). Aman dipanggil berulang."""
    global _detector, _classifier, _pipeline
    with _lock:
        if _pipeline is not None and not force:
            return _pipeline

        _errors.clear()

        _detector = YOLODetector()  # wajib; error di sini sengaja tidak ditelan
        _detector.predict(np.zeros((64, 64, 3), dtype=np.uint8))  # pemanasan
        log.info("Model YOLO termuat.")

        try:
            _classifier = ONNXClassifier()
            _classifier.predict(np.zeros((64, 64, 3), dtype=np.uint8))  # pemanasan
            log.info("Model MobileNet termuat.")
        except FileNotFoundError as exc:
            _classifier = None
            _errors["classifier"] = str(exc)
            log.warning("MobileNet belum tersedia: %s", exc)
        except Exception as exc:
            _classifier = None
            _errors["classifier"] = f"{type(exc).__name__}: {exc}"
            log.exception("MobileNet gagal dimuat")

        _pipeline = HybridPipeline(_classifier, _detector)
        return _pipeline


def get_pipeline():
    return _pipeline if _pipeline is not None else load_models()


def get_detector():
    if _detector is None:
        load_models()
    return _detector


def status():
    return {
        "yolo": _detector is not None,
        "classifier": _classifier is not None,
        "errors": dict(_errors),
    }
