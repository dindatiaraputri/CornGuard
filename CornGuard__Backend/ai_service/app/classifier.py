"""Klasifikasi MobileNet (tahap 1 pipeline) berbasis ONNX.

Butuh dua berkas di ai_service/models/:
  - classifier.onnx
  - classifier_meta.json   (contoh di bawah)

{
  "input_size": 224,
  "classes": ["Blight", "Bulai", "Common Rust", "Gray Leaf Spot", "Healthy"],
  "preprocess": "zero_one",
  "resize": "stretch"
}

PENTING: "classes" harus URUT SAMA dengan urutan saat training MobileNet, dan
"preprocess" harus sama dengan yang dipakai saat training:
  zero_one : piksel / 255
  minus1_1 : piksel / 127.5 - 1   (preprocess_input bawaan MobileNetV2)
  imagenet : (piksel/255 - mean) / std
  none     : tidak diubah (pakai ini kalau preprocessing SUDAH ada di dalam model .keras)
"""
import json
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort

MODEL_DIR = Path(__file__).resolve().parents[1] / "models"

_IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
_IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

_PREPROCESS = {
    "zero_one": lambda x: x / 255.0,
    "minus1_1": lambda x: x / 127.5 - 1.0,
    "imagenet": lambda x: (x / 255.0 - _IMAGENET_MEAN) / _IMAGENET_STD,
    "none": lambda x: x,
}


class ONNXClassifier:
    def __init__(self, model_path=None, meta_path=None):
        model_path = Path(model_path or MODEL_DIR / "classifier.onnx")
        meta_path = Path(meta_path or MODEL_DIR / "classifier_meta.json")

        if not model_path.is_file():
            raise FileNotFoundError(f"Model klasifikasi tidak ditemukan: {model_path}")
        if not meta_path.is_file():
            raise FileNotFoundError(f"Metadata klasifikasi tidak ditemukan: {meta_path}")

        with meta_path.open("r", encoding="utf-8") as f:
            self.meta = json.load(f)

        self.input_size = int(self.meta["input_size"])
        self.classes = list(self.meta["classes"])
        self.preprocess_name = self.meta.get("preprocess", "zero_one")
        if self.preprocess_name not in _PREPROCESS:
            raise ValueError(
                f"preprocess '{self.preprocess_name}' tidak dikenal; "
                f"pilihan: {sorted(_PREPROCESS)}"
            )
        if self.meta.get("resize", "stretch") != "stretch":
            raise ValueError("Saat ini hanya resize 'stretch' yang didukung.")

        self.session = ort.InferenceSession(
            str(model_path), providers=["CPUExecutionProvider"]
        )
        inputs = self.session.get_inputs()
        outputs = self.session.get_outputs()
        if len(inputs) != 1 or len(outputs) != 1:
            raise ValueError("Model klasifikasi harus punya satu input dan satu output.")

        self.input_name = inputs[0].name
        self.output_name = outputs[0].name

        shape = inputs[0].shape  # contoh: [1,224,224,3] (NHWC) atau [1,3,224,224] (NCHW)
        if len(shape) != 4:
            raise ValueError(f"Shape input tidak didukung: {shape}")
        if shape[-1] == 3:
            self.layout = "NHWC"
        elif shape[1] == 3:
            self.layout = "NCHW"
        else:
            raise ValueError(f"Tidak bisa menentukan layout dari shape: {shape}")

        n_out = outputs[0].shape[-1]
        if isinstance(n_out, int) and n_out != len(self.classes):
            raise ValueError(
                f"Output model {n_out} kelas, tapi metadata {len(self.classes)} kelas."
            )

    def predict(self, image):
        """image: array BGR OpenCV. Mengembalikan label, confidence, dan skor tiap kelas."""
        if not isinstance(image, np.ndarray) or image.ndim != 3 or image.shape[2] != 3:
            raise ValueError("Format gambar tidak valid")

        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        resized = cv2.resize(
            rgb, (self.input_size, self.input_size), interpolation=cv2.INTER_LINEAR
        )
        x = _PREPROCESS[self.preprocess_name](resized.astype(np.float32))
        x = x.astype(np.float32)
        if self.layout == "NCHW":
            x = x.transpose(2, 0, 1)
        x = np.expand_dims(np.ascontiguousarray(x), axis=0)

        probs = np.asarray(
            self.session.run([self.output_name], {self.input_name: x})[0][0],
            dtype=np.float64,
        )
        # Beberapa model mengeluarkan logit, bukan probabilitas.
        if probs.min() < 0 or abs(probs.sum() - 1.0) > 1e-3:
            e = np.exp(probs - probs.max())
            probs = e / e.sum()

        idx = int(np.argmax(probs))
        return {
            "label": self.classes[idx],
            "confidence": round(float(probs[idx]), 4),
            "scores": {c: round(float(p), 4) for c, p in zip(self.classes, probs)},
        }
