
from pathlib import Path

import cv2

from app.detector import YOLODetector


BASE_DIR = Path(__file__).resolve().parent
IMAGE_PATH = BASE_DIR / "tests" / "DJI_0507.JPG"
OUTPUT_PATH = BASE_DIR / "tests" / "result_detector_0507.jpg"


def main():
    if not IMAGE_PATH.is_file():
        raise FileNotFoundError(
            f"Foto uji tidak ditemukan: {IMAGE_PATH}"
        )

    image = cv2.imread(str(IMAGE_PATH))

    if image is None:
        raise ValueError(
            f"Gagal membaca gambar: {IMAGE_PATH}"
        )

    detector = YOLODetector()
    result = detector.predict(image)

    print("=== HASIL DETEKSI CORNGUARD ===")
    print(
        f"Ukuran foto: {result['image_width']} x "
        f"{result['image_height']}"
    )
    print(f"Jumlah deteksi: {len(result['detections'])}")

    for i, detection in enumerate(
        result["detections"], start=1
    ):
        print(f"\nDeteksi {i}: {detection}")

    # Visualisasikan hasil pada gambar yang sama
    for detection in result["detections"]:
        x1 = int(detection["x1"])
        y1 = int(detection["y1"])
        x2 = int(detection["x2"])
        y2 = int(detection["y2"])

        confidence = detection["confidence"]
        class_name = detection["class_name"]

        cv2.rectangle(
            image,
            (x1, y1),
            (x2, y2),
            (0, 255, 0),
            4,
        )

        label = f"{class_name}: {confidence:.2f}"

        cv2.putText(
            image,
            label,
            (x1, max(y1 - 10, 30)),
            cv2.FONT_HERSHEY_SIMPLEX,
            1.0,
            (0, 255, 0),
            2,
        )

    if not cv2.imwrite(str(OUTPUT_PATH), image):
        raise RuntimeError(
            f"Gagal menyimpan hasil: {OUTPUT_PATH}"
        )

    print(f"\nHasil gambar: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
