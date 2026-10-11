# CornGuard Backend

Backend CornGuard: Django REST API (`api/`) dan layanan AI (`ai_service/`).
Alur: foto masuk ke Django, lalu pipeline AI (MobileNet dulu, YOLO hanya jika hasilnya Bulai).

## Menjalankan

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/Mac: source .venv/bin/activate)
pip install -r requirements.txt
cd api
python manage.py migrate
python manage.py runserver
```

Model dimuat **sekali saat server start** (bukan per request). Cek di terminal: tidak ada error, lalu buka
`http://127.0.0.1:8000/api/health/`.

## Endpoint

| Method | URL | Fungsi |
|---|---|---|
| GET | `/api/health/` | Status model (yolo, classifier, error bila ada) |
| POST | `/api/detect/` | YOLO saja (uji). Form-data: `image` |
| POST | `/api/diagnose/` | Pipeline hybrid. Membalas 503 sampai model MobileNet tersedia |

## Berkas model (`ai_service/models/`, tidak masuk Git, ambil dari Google Drive tim)

| Berkas | Keterangan |
|---|---|
| `best.onnx`, `model_meta.json` | YOLO deteksi Bulai (input 960, 1 kelas, conf 0.2002) |
| `best.pt` | Bobot asli YOLO (hanya untuk skrip pembanding) |
| `classifier.onnx`, `classifier_meta.json` | MobileNet klasifikasi (belum ada; lihat `ai_service/app/classifier.py` untuk format meta) |

## Uji

```bash
cd ai_service
python test_pipeline.py
```
