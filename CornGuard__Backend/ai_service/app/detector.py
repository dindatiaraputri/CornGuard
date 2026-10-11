
import json
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort


AI_SERVICE_DIR = Path(__file__).resolve().parents[1]
MODEL_DIR = AI_SERVICE_DIR / "models"


class YOLODetector:
    """YOLOv8 ONNX detector for CornGuard."""

    def __init__(
        self,
        model_path=None,
        metadata_path=None,
        iou_threshold=0.45,
    ):
        model_path = Path(model_path or MODEL_DIR / "best.onnx")
        metadata_path = Path(
            metadata_path or MODEL_DIR / "model_meta.json"
        )

        if not model_path.is_file():
            raise FileNotFoundError(
                f"Model tidak ditemukan: {model_path}"
            )

        if not metadata_path.is_file():
            raise FileNotFoundError(
                f"Metadata tidak ditemukan: {metadata_path}"
            )

        with metadata_path.open("r", encoding="utf-8") as file:
            self.meta = json.load(file)

        self.input_size = int(self.meta["input_size"])
        self.classes = self.meta["classes"]
        self.conf_threshold = float(
            self.meta["conf_threshold"]
        )
        self.iou_threshold = iou_threshold

        self.session = ort.InferenceSession(
            str(model_path),
            providers=["CPUExecutionProvider"],
        )

        inputs = self.session.get_inputs()
        outputs = self.session.get_outputs()

        if len(inputs) != 1 or len(outputs) != 1:
            raise ValueError(
                "Implementasi ini mengharapkan satu input "
                "dan satu output ONNX."
            )

        self.input_name = inputs[0].name
        self.output_name = outputs[0].name


        input_shape = inputs[0].shape

        if len(input_shape) != 4 or input_shape[1] != 3:
            raise ValueError(
                f"Shape input ONNX tidak didukung: {input_shape}"
            )

        print(f"ONNX input shape: {input_shape}")

        self.num_classes = len(self.classes)

    def _preprocess(self, image):
        """Resize dan letterbox gambar ke ukuran tetap model ONNX."""

        height, width = image.shape[:2]
        target = self.input_size

        # Pertahankan rasio gambar
        scale = min(target / width, target / height)

        new_width = int(round(width * scale))
        new_height = int(round(height * scale))

        resized = cv2.resize(
            image,
            (new_width, new_height),
            interpolation=cv2.INTER_LINEAR,
        )

        # Padding hingga tepat target x target
        pad_w = target - new_width
        pad_h = target - new_height

        left = pad_w // 2
        right = pad_w - left
        top = pad_h // 2
        bottom = pad_h - top

        padded = cv2.copyMakeBorder(
            resized,
            top,
            bottom,
            left,
            right,
            cv2.BORDER_CONSTANT,
            value=(114, 114, 114),
        )

        # BGR ke RGB, HWC ke CHW, normalisasi ke 0–1
        rgb = cv2.cvtColor(padded, cv2.COLOR_BGR2RGB)
        tensor = rgb.transpose(2, 0, 1)
        tensor = np.ascontiguousarray(tensor, dtype=np.float32)
        tensor /= 255.0
        tensor = np.expand_dims(tensor, axis=0)

        # Pastikan sesuai input statis ONNX
        assert tensor.shape == (1, 3, target, target), (
            f"Shape tensor tidak sesuai: {tensor.shape}"
        )

        return tensor, scale, left, top


    def predict(self, image):
        """Detect objects in an OpenCV BGR image."""

        if not isinstance(image, np.ndarray):
            raise TypeError("image harus berupa numpy.ndarray")

        if (
            image.size == 0
            or image.ndim != 3
            or image.shape[2] != 3
        ):
            raise ValueError("Format gambar tidak valid")

        original_height, original_width = image.shape[:2]

        tensor, scale, pad_x, pad_y = self._preprocess(image)

        output = self.session.run(
            [self.output_name],
            {self.input_name: tensor},
        )[0]

        if output.ndim != 3 or output.shape[0] != 1:
            raise ValueError(
                f"Shape output tidak didukung: {output.shape}"
            )

        # Expected output: [1, 4 + number_of_classes, candidates].
        # For one class, the expected shape is [1, 5, 18900].
        prediction = output[0].T

        expected_features = 4 + self.num_classes

        if prediction.shape[1] != expected_features:
            raise ValueError(
                "Format output tidak sesuai asumsi YOLOv8: "
                f"{output.shape}; expected "
                f"[1, {expected_features}, candidates]. "
                "Periksa konfigurasi ekspor model."
            )

        boxes_xywh = prediction[:, :4]
        scores = prediction[:, 4:]

        # This implementation assumes standard YOLOv8 output:
        # xywh followed by class probabilities, without objectness.
        class_ids = np.argmax(scores, axis=1)
        confidences = scores[
            np.arange(len(scores)), class_ids
        ]

        valid = (
            np.isfinite(boxes_xywh).all(axis=1)
            & np.isfinite(confidences)
            & (confidences >= self.conf_threshold)
        )

        boxes_xywh = boxes_xywh[valid]
        confidences = confidences[valid]
        class_ids = class_ids[valid]

        if len(boxes_xywh) == 0:
            return {
                "image_width": original_width,
                "image_height": original_height,
                "detections": [],
            }

        # Convert center x/y, width/height to top-left x/y,
        # width and height, as required by OpenCV NMSBoxes.
        boxes_xyxy = np.empty_like(boxes_xywh)
        boxes_xyxy[:, 0] = (
            boxes_xywh[:, 0] - boxes_xywh[:, 2] / 2
        )
        boxes_xyxy[:, 1] = (
            boxes_xywh[:, 1] - boxes_xywh[:, 3] / 2
        )
        boxes_xyxy[:, 2] = (
            boxes_xywh[:, 0] + boxes_xywh[:, 2] / 2
        )
        boxes_xyxy[:, 3] = (
            boxes_xywh[:, 1] + boxes_xywh[:, 3] / 2
        )

        # NMSBoxes expects [x, y, width, height].
        nms_boxes = [
            [
                float(box[0]),
                float(box[1]),
                float(box[2] - box[0]),
                float(box[3] - box[1]),
            ]
            for box in boxes_xyxy
        ]

        indices = cv2.dnn.NMSBoxes(
            nms_boxes,
            confidences.tolist(),
            self.conf_threshold,
            self.iou_threshold,
        )

        if len(indices) == 0:
            selected = []
        else:
            selected = np.asarray(indices).reshape(-1).tolist()

        detections = []

        for index in selected:
            x1, y1, x2, y2 = boxes_xyxy[index]

            # Remove letterbox padding and reverse resize.
            x1 = (x1 - pad_x) / scale
            y1 = (y1 - pad_y) / scale
            x2 = (x2 - pad_x) / scale
            y2 = (y2 - pad_y) / scale

            x1 = float(np.clip(x1, 0, original_width))
            y1 = float(np.clip(y1, 0, original_height))
            x2 = float(np.clip(x2, 0, original_width))
            y2 = float(np.clip(y2, 0, original_height))

            if x2 <= x1 or y2 <= y1:
                continue

            class_id = int(class_ids[index])

            detections.append({
                "x1": round(x1, 2),
                "y1": round(y1, 2),
                "x2": round(x2, 2),
                "y2": round(y2, 2),
                "confidence": round(
                    float(confidences[index]), 4
                ),
                "class_id": class_id,
                "class_name": self.classes[class_id],
            })

        return {
            "image_width": original_width,
            "image_height": original_height,
            "detections": detections,
        }

    def predict_bytes(self, image_bytes):
        """Decode uploaded image bytes and run detection."""

        if not image_bytes:
            raise ValueError("Data gambar kosong")

        buffer = np.frombuffer(image_bytes, dtype=np.uint8)
        image = cv2.imdecode(buffer, cv2.IMREAD_COLOR)

        if image is None:
            raise ValueError("File bukan gambar yang valid")

        return self.predict(image)

