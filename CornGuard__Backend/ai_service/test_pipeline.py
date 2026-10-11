"""Uji logika pipeline hybrid dan pemuatan model.  Jalankan:  python test_pipeline.py
(dari folder ai_service). MobileNet diganti objek palsu, jadi tidak butuh classifier.onnx."""
from pathlib import Path

import cv2
import numpy as np

import app.classifier as classifier_module
import onnxruntime as ort
import app.registry as registry
from app.classifier import ONNXClassifier
from app.detector import YOLODetector
from app.pipeline import HybridPipeline, PipelineNotReady

REAL_SESSION = ort.InferenceSession  # disimpan agar bisa dipulihkan setelah uji classifier

IMAGE = Path(__file__).resolve().parent / "tests" / "DJI_0456.JPG"


class FakeClassifier:
    def __init__(self, label):
        self.label = label

    def predict(self, image):
        return {"label": self.label, "confidence": 0.9, "scores": {self.label: 0.9}}


class SpyDetector:
    def __init__(self, real):
        self.real, self.calls = real, 0

    def predict(self, image):
        self.calls += 1
        return self.real.predict(image)


def test_bulai_memanggil_yolo(image, real_detector):
    spy = SpyDetector(real_detector)
    out = HybridPipeline(FakeClassifier("Bulai"), spy).predict(image)
    assert spy.calls == 1 and out["detektor_dipanggil"] is True
    assert out["penyakit"] == "Bulai" and isinstance(out["lokasi"], list)
    print("OK  Bulai -> YOLO dipanggil, lokasi:", len(out["lokasi"]), "kotak")


def test_selain_bulai_tidak_memanggil_yolo(image, real_detector):
    for label in ["Healthy", "Blight", "Common Rust", "Gray Leaf Spot"]:
        spy = SpyDetector(real_detector)
        out = HybridPipeline(FakeClassifier(label), spy).predict(image)
        assert spy.calls == 0 and out["detektor_dipanggil"] is False and out["lokasi"] == []
    print("OK  Healthy/Blight/Rust/GLS -> YOLO tidak dipanggil")


def test_label_tidak_peka_huruf_besar(image, real_detector):
    spy = SpyDetector(real_detector)
    HybridPipeline(FakeClassifier("BULAI"), spy).predict(image)
    assert spy.calls == 1
    print("OK  'BULAI' dikenali sama dengan 'Bulai'")


def test_tanpa_classifier_gagal_jelas(image, real_detector):
    try:
        HybridPipeline(None, real_detector).predict(image)
    except PipelineNotReady as exc:
        print("OK  classifier kosong -> PipelineNotReady:", exc)
        return
    raise AssertionError("seharusnya PipelineNotReady")


class FakeSession:
    def __init__(self, shape, out):
        self._shape, self._out = shape, out
        self.last_input = None

    def get_inputs(self):
        return [type("I", (), {"name": "in", "shape": self._shape})()]

    def get_outputs(self):
        return [type("O", (), {"name": "out", "shape": [1, len(self._out)]})()]

    def run(self, names, feed):
        self.last_input = feed["in"]
        return [np.array([self._out], dtype=np.float32)]


def make_classifier(tmp, shape, out, preprocess="zero_one"):
    import json
    model, meta = tmp / "c.onnx", tmp / "c.json"
    model.write_bytes(b"x")
    meta.write_text(json.dumps({
        "input_size": 8, "classes": ["Blight", "Bulai", "Healthy"], "preprocess": preprocess}))
    classifier_module.ort.InferenceSession = lambda *a, **k: FakeSession(shape, out)
    return ONNXClassifier(model, meta)


def test_classifier_layout_dan_softmax(image):
    try:
        _test_classifier(image)
    finally:
        ort.InferenceSession = REAL_SESSION  # onnxruntime dipakai bersama YOLO, wajib dipulihkan


def _test_classifier(image):
    import tempfile
    tmp = Path(tempfile.mkdtemp())
    c = make_classifier(tmp, [1, 8, 8, 3], [0.1, 0.8, 0.1])
    r = c.predict(image)
    assert c.layout == "NHWC" and c.session.last_input.shape == (1, 8, 8, 3)
    assert r["label"] == "Bulai" and 0 <= c.session.last_input.max() <= 1
    c2 = make_classifier(tmp, [1, 3, 8, 8], [0.1, 3.0, 0.2])  # logit -> harus di-softmax
    r2 = c2.predict(image)
    assert c2.layout == "NCHW" and c2.session.last_input.shape == (1, 3, 8, 8)
    assert abs(sum(r2["scores"].values()) - 1) < 1e-2 and r2["label"] == "Bulai"
    c3 = make_classifier(tmp, [1, 8, 8, 3], [0.1, 0.8, 0.1], "minus1_1")
    c3.predict(image)
    assert c3.session.last_input.min() >= -1 and c3.session.last_input.min() < 0
    print("OK  classifier: NHWC/NCHW terdeteksi, logit di-softmax, preprocess minus1_1 benar")


def test_model_dimuat_sekali(real_detector):
    created = {"n": 0}
    original = registry.YOLODetector

    def counting(*a, **k):
        created["n"] += 1
        return original(*a, **k)

    registry.YOLODetector = counting
    registry._pipeline = registry._detector = registry._classifier = None
    p1 = registry.get_pipeline()
    p2 = registry.get_pipeline()
    registry.get_detector()
    registry.YOLODetector = original
    assert created["n"] == 1 and p1 is p2
    print("OK  3x get_* -> YOLO dibuat", created["n"], "kali (bukan per request)")
    st = registry.status()
    print("    status:", st)
    assert st["yolo"] is True
    if not (Path(__file__).resolve().parent / "models" / "classifier.onnx").is_file():
        assert st["classifier"] is False and "classifier" in st["errors"]
        try:
            registry.get_pipeline().predict(np.zeros((64, 64, 3), dtype=np.uint8))
        except PipelineNotReady:
            print("OK  classifier.onnx belum ada -> server tetap start, /diagnose akan 503")
            return
        raise AssertionError("seharusnya PipelineNotReady")


if __name__ == "__main__":
    image = cv2.imread(str(IMAGE))
    assert image is not None, f"foto uji tidak terbaca: {IMAGE}"
    real = YOLODetector()
    test_bulai_memanggil_yolo(image, real)
    test_selain_bulai_tidak_memanggil_yolo(image, real)
    test_label_tidak_peka_huruf_besar(image, real)
    test_tanpa_classifier_gagal_jelas(image, real)
    test_classifier_layout_dan_softmax(image)
    test_model_dimuat_sekali(real)
    print("\nSEMUA UJI LULUS")
