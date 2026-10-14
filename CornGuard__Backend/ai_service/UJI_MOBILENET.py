"""
Uji MobileNet (classifier.onnx) memakai kode classifier milik backend.

Taruh file ini di folder `ai_service/` (sejajar dengan folder `app/`), lalu jalankan:

    python uji_mobilenet.py <folder_foto> [--maks 50]

Struktur <folder_foto> (nama subfolder harus sama dengan nama kelas):
    folder_foto/
        Blight/            isi: foto .jpg / .jpeg / .png
        Common_Rust/
        Gray_Leaf_Spot/
        Healthy/
Subfolder yang tidak ada akan dilewati.
"""
import argparse
import pathlib
import random
from collections import Counter

import cv2

from app.classifier import ONNXClassifier

EKSTENSI = {".jpg", ".jpeg", ".png"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--maks", type=int, default=50, help="maksimal foto per kelas")
    a = ap.parse_args()

    clf = ONNXClassifier()
    kelas = clf.classes
    print(f"Model termuat. Kelas: {kelas} | preprocess: {clf.preprocess_name}\n")

    random.seed(7)
    benar = Counter()
    jumlah = Counter()
    tertukar = Counter()      # (asli, tebakan) -> jumlah
    ragu = 0                  # keyakinan di bawah 0.7
    salah_list = []
    rusak = 0

    for k in kelas:
        d = pathlib.Path(a.folder) / k
        if not d.is_dir():
            print(f"[lewati] folder tidak ada: {d}")
            continue
        files = sorted(f for f in d.iterdir() if f.suffix.lower() in EKSTENSI)
        if len(files) > a.maks:
            files = random.sample(files, a.maks)
        for f in files:
            img = cv2.imread(str(f))
            if img is None:
                rusak += 1
                continue
            r = clf.predict(img)
            jumlah[k] += 1
            ragu += r["confidence"] < 0.7
            if r["label"] == k:
                benar[k] += 1
            else:
                tertukar[(k, r["label"])] += 1
                salah_list.append((f.name, k, r["label"], r["confidence"]))

    total = sum(jumlah.values())
    if total == 0:
        print("Tidak ada foto yang bisa diuji. Cek struktur folder.")
        return

    print(f"{'Kelas':16s}{'Benar':>7s}{'Jumlah':>8s}{'Akurasi':>9s}")
    for k in kelas:
        if jumlah[k]:
            print(f"{k:16s}{benar[k]:>7d}{jumlah[k]:>8d}{benar[k] / jumlah[k]:>9.1%}")
    akurasi = sum(benar.values()) / total
    print(f"{'TOTAL':16s}{sum(benar.values()):>7d}{total:>8d}{akurasi:>9.1%}")
    print(f"Foto rusak/tidak terbaca: {rusak} | Keyakinan < 0.7: {ragu}\n")

    if tertukar:
        print("Kesalahan terbanyak (asli -> tebakan):")
        for (asli, tebak), n in tertukar.most_common(5):
            print(f"  {asli} -> {tebak}: {n}")
        print("\nContoh foto yang salah (maks 8):")
        for nama, asli, tebak, kyk in salah_list[:8]:
            print(f"  {nama}: asli {asli}, tebakan {tebak} (keyakinan {kyk})")

    # Diagnosis cepat
    print("\nDiagnosis:")
    if akurasi < 0.5:
        print("  [!] Akurasi sangat rendah. Cek 'preprocess' di classifier_meta.json "
              "(harus \"none\") dan urutan 'classes'.")
    tebakan = Counter()
    for (_, t), n in tertukar.items():
        tebakan[t] += n
    if tebakan and tebakan.most_common(1)[0][1] / total > 0.5:
        print("  [!] Lebih dari separuh foto ditebak sebagai satu kelas yang sama. "
              "Curigai preprocess atau urutan kelas.")
    if akurasi >= 0.85:
        print("  [OK] Model berjalan wajar.")


if __name__ == "__main__":
    main()