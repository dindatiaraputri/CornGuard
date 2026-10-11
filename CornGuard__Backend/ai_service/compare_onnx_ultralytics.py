
from ultralytics import YOLO
from pathlib import Path

image_path = "tests/DJI_0456.JPG"
model_path = "models/best.pt"

model = YOLO(model_path, task="detect")

results = model.predict(
    source=image_path,
    imgsz=960,
    rect=False,
    conf=0.2002002,
    iou=0.45,
    save=True,
    project="tests/comparison",
    name="best_pt_ultralytics",
    exist_ok=True,
)

for result in results:
    print("Image shape:", result.orig_shape)
    print("Classes:", result.names)

    if result.boxes is None or len(result.boxes) == 0:
        print("Tidak ada deteksi")
        continue

    for box in result.boxes:
        print({
            "xyxy": [
                round(float(v), 2)
                for v in box.xyxy[0].cpu().tolist()
            ],
            "confidence": round(float(box.conf[0]), 4),
            "class_id": int(box.cls[0]),
            "class_name": result.names[int(box.cls[0])],
        })
