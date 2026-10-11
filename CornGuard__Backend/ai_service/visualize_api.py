
import cv2
import requests
from pathlib import Path

image_path = Path("tests/DJI_0456.JPG")
api_url = "http://127.0.0.1:8000/api/detect/"

image = cv2.imread(str(image_path))

if image is None:
    raise FileNotFoundError(f"Gambar tidak ditemukan: {image_path}")

with image_path.open("rb") as f:
    response = requests.post(
        api_url,
        files={"image": (image_path.name, f, "image/jpeg")},
        timeout=120,
    )

print("HTTP status:", response.status_code)
response.raise_for_status()
result = response.json()


print("Jumlah deteksi:", len(result.get("detections", [])))

# Warna kontras dalam format BGR (OpenCV)

# Warna dalam format BGR (OpenCV)
BOX_COLOR = (255, 0, 255)       # Magenta
TEXT_COLOR = (255, 255, 255)    # Putih
TEXT_BG_COLOR = (180, 0, 180)   # Ungu tua

BOX_THICKNESS = 10
FONT = cv2.FONT_HERSHEY_SIMPLEX
FONT_SCALE = 2.0
FONT_THICKNESS = 5

for detection in result.get("detections", []):
    x1 = int(detection["x1"])
    y1 = int(detection["y1"])
    x2 = int(detection["x2"])
    y2 = int(detection["y2"])

    label = (
        f'{detection["class_name"]} '
        f'{detection["confidence"]:.2f}'
    )

    # Gambar bounding box yang tebal
    cv2.rectangle(
        image,
        (x1, y1),
        (x2, y2),
        BOX_COLOR,
        BOX_THICKNESS,
    )

    # Hitung ukuran teks agar latar label pas
    (text_w, text_h), baseline = cv2.getTextSize(
        label, FONT, FONT_SCALE, FONT_THICKNESS
    )

    # Utamakan label di atas kotak, tetapi jangan keluar gambar
    label_y = y1 - 10

    if label_y - text_h - baseline < 0:
        label_y = min(
            y1 + text_h + baseline + 10,
            image.shape[0] - baseline - 2,
        )

    label_x = max(0, min(x1, image.shape[1] - text_w - 10))

    # Latar ungu solid supaya teks tidak menyatu dengan daun
    bg_top = max(0, label_y - text_h - baseline - 6)
    bg_bottom = min(image.shape[0], label_y + baseline + 4)
    bg_right = min(image.shape[1], label_x + text_w + 10)

    cv2.rectangle(
        image,
        (label_x, bg_top),
        (bg_right, bg_bottom),
        TEXT_BG_COLOR,
        thickness=-1,
    )

    cv2.putText(
        image,
        label,
        (label_x + 5, label_y),
        FONT,
        FONT_SCALE,
        TEXT_COLOR,
        FONT_THICKNESS,
        cv2.LINE_AA,
    )

output_path = Path("tests/result_api_0507.jpg")

saved = cv2.imwrite(str(output_path), image)

if not saved:
    raise RuntimeError("Gagal menyimpan gambar visualisasi.")

print("Gambar hasil disimpan di:", output_path.resolve())
