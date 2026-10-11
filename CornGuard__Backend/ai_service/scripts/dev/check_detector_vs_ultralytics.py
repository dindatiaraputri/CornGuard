"""Bandingkan detector buatan sendiri (app/detector.py) dengan Ultralytics pada model ONNX YANG SAMA.

Ini perbandingan yang adil: keduanya memakai best.onnx dan gambar persegi 960x960.
(Membandingkan dengan best.pt kurang adil, karena Ultralytics memakai gambar persegi panjang
untuk PT sehingga confidence sedikit berbeda.)

Jalankan dari folder ai_service:
    python scripts/dev/check_detector_vs_ultralytics.py tests/DJI_0456.JPG
Butuh ultralytics (lihat requirements-dev.txt).
"""
import sys
from pathlib import Path

import cv2

BASE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BASE))

from ultralytics import YOLO  # noqa: E402

from app.detector import YOLODetector  # noqa: E402


def iou(a, b):
    ix1, iy1 = max(a[0], b[0]), max(a[1], b[1])
    ix2, iy2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, ix2 - ix1) * max(0, iy2 - iy1)
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union else 0.0


image_path = Path(sys.argv[1]) if len(sys.argv) > 1 else BASE / "tests" / "DJI_0456.JPG"
detector = YOLODetector()
mine = [
    (d["x1"], d["y1"], d["x2"], d["y2"], d["confidence"])
    for d in detector.predict(cv2.imread(str(image_path)))["detections"]
]

result = YOLO(str(BASE / "models" / "best.onnx"), task="detect").predict(
    source=str(image_path),
    imgsz=detector.input_size,
    conf=detector.conf_threshold,
    iou=detector.iou_threshold,
    verbose=False,
)[0]
theirs = [(*b.xyxy[0].tolist(), float(b.conf[0])) for b in result.boxes]

print(f"Foto: {image_path.name}")
print(f"Detector sendiri: {len(mine)} deteksi | Ultralytics (ONNX): {len(theirs)} deteksi")

ok = len(mine) == len(theirs)
for t in theirs:
    best = max(mine, key=lambda m: iou(m, t), default=None)
    if best is None:
        print(f"  Ultralytics {t[4]:.3f}: TIDAK ada pasangan di detector sendiri")
        ok = False
        continue
    overlap = iou(best, t)
    print(f"  Ultralytics conf {t[4]:.3f} | sendiri conf {best[4]:.3f} | IoU {overlap:.3f}")
    ok = ok and overlap > 0.9 and abs(best[4] - t[4]) < 0.02

print("\nHASIL:", "COCOK, detector sendiri setara Ultralytics" if ok else "BEDA, periksa praproses/pascaproses di detector.py")
