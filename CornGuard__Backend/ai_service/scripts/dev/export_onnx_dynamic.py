
from ultralytics import YOLO

model = YOLO("models/best.pt")

model.export(
    format="onnx",
    imgsz=960,
    dynamic=True,
    simplify=True,
)
