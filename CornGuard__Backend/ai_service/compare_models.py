
from pathlib import Path
from ultralytics import YOLO

image_path = "tests/DJI_0456.JPG"
model_path = r"models\best.pt"

model = YOLO(model_path)

results = model.predict(
    source=image_path,
    imgsz=960,
    conf=0.2002002,
    iou=0.45,
    save=True,
    project="tests/comparison",
    name="pt_rect_test",
    exist_ok=True,
)

for result in results:
    print("Image:", result.orig_shape)

    if result.boxes is None:
        print("Tidak ada deteksi")
        continue

    for box in result.boxes:
        print({
            "xyxy": box.xyxy[0].cpu().tolist(),
            "confidence": float(box.conf[0]),
            "class_id": int(box.cls[0]),
            "class_name": result.names[int(box.cls[0])],
        })
