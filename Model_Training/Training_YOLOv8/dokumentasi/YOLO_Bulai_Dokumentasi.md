# Dokumentasi Task 04: Model Deteksi Bulai (YOLOv8)

Model deteksi objek untuk menandai lokasi gejala penyakit **Bulai** pada daun jagung. Di sistem CornGuard, model ini adalah tahap kedua AI Pipeline: ia hanya dipanggil setelah MobileNet mengklasifikasikan foto sebagai Bulai.

| | |
|---|---|
| Model | YOLOv8s (`yolov8s.pt`, fine-tuning) |
| Kelas | 1 (`Bulai`) |
| Ukuran input | 960 x 960 |
| Format akhir | ONNX |
| Notebook | `01_Training_YOLO_Bulai.ipynb`, `02_Evaluasi_Ekspor_YOLO_Bulai.ipynb` |

## 1. Data Preprocessing & Annotation

**Sumber dataset:** Roboflow *bulai-jagung* (workspace `student-tqkot`, proyek `bulai-jagung-oakym`, versi 7), lisensi **CC BY 4.0**. Dataset asli memiliki 3 kelas: `PENYAKIT-BULAI-JAGUNG`, `Sehat-Muda`, `sehat Tua`.

**Anotasi:** bounding box berasal dari dataset Roboflow tersebut. *(Isi di sini bila tim menambah atau memperbaiki anotasi sendiri.)*

**Langkah preprocessing** (otomatis di notebook 01 dan 02, `SEED=42`):
1. Unzip dataset dari Google Drive.
2. Hanya kelas Bulai yang dipertahankan, dan di-remap menjadi class-id 0. Dua kelas sehat dibuang karena YOLO tidak pernah dipanggil untuk daun sehat dalam alur sistem.
3. Foto yang tidak lagi memiliki box (foto sehat) dibuang.
4. `data.yaml` ditulis ulang: `nc: 1`, `names: [Bulai]`, path absolut.
5. Verifikasi: jumlah gambar sama dengan jumlah label, dan hanya class-id 0 yang tersisa.

| Split | Foto asli | Foto Bulai (dipakai) | Dibuang | Jumlah box Bulai |
|---|---|---|---|---|
| train | 3217 | 1190 | 2027 | 24145 |
| valid | 322 | 107 | 215 | 2300 |
| test | 169 | 68 | 101 | 1220 |

Rata-rata sekitar 20 box per foto, jadi objeknya padat dan banyak yang kecil.

## 2. YOLO Training

| Parameter | Nilai |
|---|---|
| Model awal | `yolov8s.pt` |
| Ukuran input (`imgsz`) | 960 |
| Batch | 16 |
| Epoch maksimum | 150 |
| Patience (early stopping) | 50 |
| Seed | 42 |
| Hardware | Google Colab, GPU T4 |

Hasil: training berhenti otomatis di **epoch 111** (early stopping). Bobot terbaik (`best.pt`) berasal dari **epoch 61**.

Percobaan sebelumnya (`imgsz=640`) memberi mAP@50 test 0.531 dan mAP@50-95 0.205. Menaikkan resolusi ke 960 memperbaikinya ke 0.572 dan 0.259, kemungkinan karena gejala yang kecil dan padat.

## 3. Model Evaluation

Threshold confidence dipilih dari kurva F1 pada data **valid** (bukan test), yaitu **0.2**. Data test hanya dipakai untuk pelaporan akhir.

| Split | Precision | Recall | F1 | mAP@50 | mAP@50-95 |
|---|---|---|---|---|---|
| valid | 0.610 | 0.622 | 0.616 | 0.631 | 0.290 |
| **test** | **0.565** | **0.593** | **0.579** | **0.572** | **0.259** |

Precision, Recall, dan F1 dihitung pada conf 0.2. mAP dihitung dengan threshold confidence rendah standar Ultralytics.

**Analisis kesalahan (test, 68 foto):** model memprediksi 1238 box dibanding 1220 box ground truth. Sebanyak 25 foto over-detect, 28 foto under-detect, dan 15 foto jumlahnya tepat. Jadi model tidak condong ke false positive maupun false negative.

**Pengamatan dari grafik training:** loss train terus turun, tetapi `val/box_loss` dan `val/dfl_loss` mulai naik sejak sekitar epoch 40-50, sementara mAP valid mendatar di kisaran 0.6. Ini tanda overfitting ringan, sehingga menambah epoch tidak membantu.

**Interpretasi:** mAP@50 sekitar 0.57 tergolong moderat. mAP@50-95 jauh lebih rendah daripada mAP@50, yang *diduga* karena batas gejala bulai kabur (daun menguning tanpa tepi tegas). Dugaan ini belum diuji.

## 4. Model Export

Model diekspor ke **ONNX** (`best.onnx`, input 960) dan diverifikasi pada data test.

| | best.pt | model.onnx |
|---|---|---|
| Precision | 0.5877 | 0.5844 |
| Recall | 0.5705 | 0.5533 |
| mAP@50 | 0.5720 | 0.5649 |
| mAP@50-95 | 0.2587 | 0.2557 |
| Ukuran file | 22.6 MB | 45.0 MB |

Selisih mAP@50 sebesar 0.0071, jadi konversi dianggap aman. Ukuran ONNX dua kali lipat karena `best.pt` disimpan dalam FP16 sedangkan ONNX dalam FP32.

Kecepatan pada GPU T4 (saat validasi `best.pt`): sekitar 15 ms pra-proses, 24 ms inferensi, dan 6 ms pasca-proses per gambar. Angka kecepatan dari pengujian ONNX di notebook 02 diambil di CPU dan tidak representatif.

**Berkas hasil ekspor** (folder `.../bulai_yolov8s_960/weights/`):
- `best.onnx`
- `model_meta.json` (nama model, ukuran input, nama kelas, `conf_threshold`)

## 5. Cara Memakai Model (untuk integrasi backend)

- Muat `best.onnx` dengan `onnxruntime`.
- Gambar di-resize ke 960 x 960 sebelum masuk model. Pra-proses dan pasca-proses (NMS, konversi koordinat ke ukuran foto asli) harus ditulis ulang di layanan AI karena output ONNX masih mentah.
- Gunakan `conf_threshold` dari `model_meta.json` sebagai nilai awal.
- Panggil model ini hanya jika MobileNet menyatakan hasil Bulai.

## 6. Keterbatasan

- Data test hanya 68 foto, jadi metrik bisa berfluktuasi.
- Gejala kecil dan padat, sehingga akurasi lokasi (mAP@50-95) masih rendah.
- Kebocoran data antar split (foto hampir kembar dari lahan yang sama) belum diperiksa.
- Model hanya mendeteksi lokasi Bulai, tidak untuk Blight, Common Rust, dan Gray Leaf Spot.
- Belum diuji pada foto lapangan di luar dataset.
- Threshold 0.2 dipilih untuk YOLO yang berdiri sendiri. Dalam pipeline (setelah MobileNet) nilainya perlu diuji ulang.

## 7. Reproduksi

1. Jalankan `01_Training_YOLO_Bulai.ipynb` (GPU) untuk training. Hasil tersimpan di Drive.
2. Jalankan `02_Evaluasi_Ekspor_YOLO_Bulai.ipynb` untuk evaluasi dan ekspor. Nilai `DRIVE_OUT`, `RUN_NAME`, dan `IMGSZ` harus sama dengan notebook 01.

## 8. Lokasi Berkas

Berkas besar (dataset, bobot model, hasil ekspor) tidak disimpan di repository GitHub karena ukurannya lebih dari 700 MB. Semuanya ada di Google Drive:

https://drive.google.com/drive/folders/1IXWIYFEphMfiJP_dalBK1-q8YKNaVv9o?usp=drive_link

Peta berkas yang relevan dengan dokumen ini (folder lain di Drive adalah sisa percobaan awal dan tidak dipakai):

| Berkas | Lokasi di Drive |
|---|---|
| Dataset (zip, 438 MB) | `BULAI JAGUNG.v7i.yolov8.zip` |
| Bobot model (`best.pt`, `last.pt`) | `training_bulai/bulai_yolov8s_960/weights/` |
| Model ONNX (`best.onnx`) dan `model_meta.json` | `training_bulai/bulai_yolov8s_960/weights/` |
| Grafik training (`results.png`, kurva PR/F1, confusion matrix) | `training_bulai/bulai_yolov8s_960/` |
| CSV evaluasi dan verifikasi ekspor | `training_bulai/` |

## 9. Atribusi

Dataset: *bulai-jagung* oleh `student-tqkot` di Roboflow Universe (CC BY 4.0).
https://universe.roboflow.com/student-tqkot/bulai-jagung-oakym/dataset/7
