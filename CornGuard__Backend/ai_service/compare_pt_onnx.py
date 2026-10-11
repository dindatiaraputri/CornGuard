
from pathlib import Path

import cv2
import numpy as np
from ultralytics import YOLO
import onnxruntime as ort

BASE_DIR = Path(__file__).resolve().parent

IMAGE_PATH = BASE_DIR / "tests" / "DJI_0456.JPG"
PT_PATH = BASE_DIR / "models" / "best.pt"
ONNX_PATH = BASE_DIR / "models" / "best.onnx"

OUTPUT_DIR = BASE_DIR / "tests" / "comparison"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

IMGSZ = 960
CONF = 0.2002002
IOU = 0.45

# A. Prediksi menggunakan best.pt
pt_model = YOLO(str(PT_PATH))

pt_results = pt_model.predict(
    source=str(IMAGE_PATH),
    imgsz=IMGSZ,
    conf=CONF,
    iou=IOU,
    save=False,
    verbose=False,
)

pt_result = pt_results[0]
pt_image = pt_result.plot()

cv2.imwrite(
    str(OUTPUT_DIR / "0507_best_pt.jpg"),
    pt_image,
)

# B. Prediksi menggunakan best.onnx
onnx_model = YOLO(str(ONNX_PATH), task="detect")

onnx_results = onnx_model.predict(
    source=str(IMAGE_PATH),
    imgsz=IMGSZ,
    conf=CONF,
    iou=IOU,
    save=False,
    verbose=False,
)

onnx_result = onnx_results[0]
onnx_image = onnx_result.plot()

cv2.imwrite(
    str(OUTPUT_DIR / "0507_best_onnx.jpg"),
    onnx_image,
)

# C. Ringkasan hasil
def summarize(name, result):
    boxes = result.boxes

    print(f"\n=== {name} ===")
    print("Jumlah deteksi:", len(boxes))

    for i, box in enumerate(boxes):
        x1, y1, x2, y2 = box.xyxy[0].cpu().tolist()
        confidence = float(box.conf[0])

        print(
            f"{i + 1}. "
            f"box=({x1:.1f}, {y1:.1f}, "
            f"{x2:.1f}, {y2:.1f}), "
            f"confidence={confidence:.4f}"
        )

summarize("BEST.PT", pt_result)
summarize("BEST.ONNX", onnx_result)

print("\nGambar tersimpan:")
print(OUTPUT_DIR / "0507_best_pt.jpg")
print(OUTPUT_DIR / "0507_best_onnx.jpg")
