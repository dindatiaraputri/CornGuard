"""Deteksi Bulai untuk BANYAK gambar sekaligus (satu foto, banyak foto, atau satu folder).

Dua mode:
  1. Lokal (bawaan): memakai models/best.onnx langsung, tanpa server.
  2. API (--api URL): mengirim tiap foto ke endpoint Django, untuk menguji end-to-end.

Contoh (jalankan dari folder ai_service):
  python scripts/dev/detect_folder.py tests
  python scripts/dev/detect_folder.py tests/DJI_0234.JPG tests/DJI_0456.JPG
  python scripts/dev/detect_folder.py D:/foto_lahan --recursive --out hasil_lahan
  python scripts/dev/detect_folder.py tests --conf 0.3 --mode letterbox
  python scripts/dev/detect_folder.py tests --api http://127.0.0.1:8000/api/detect/

Hasil: gambar berkotak + ringkasan.csv + deteksi.csv di folder --out (bawaan: hasil_deteksi/).
"""
import argparse
import csv
import sys
import time
from pathlib import Path

import cv2

BASE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BASE))

EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def kumpulkan(paths, rekursif):
    files = []
    for p in map(Path, paths):
        if p.is_dir():
            it = p.rglob("*") if rekursif else p.glob("*")
            files += sorted(f for f in it if f.suffix.lower() in EXT and f.is_file())
        elif p.is_file():
            files.append(p)
        else:
            print(f"(dilewati, tidak ditemukan: {p})")
    return files


def gambar(image, detections):
    out = image.copy()
    tebal = max(2, out.shape[1] // 500)
    font = max(0.5, out.shape[1] / 830)
    for d in detections:
        p1, p2 = (int(d["x1"]), int(d["y1"])), (int(d["x2"]), int(d["y2"]))
        cv2.rectangle(out, p1, p2, (255, 0, 255), tebal)
        cv2.putText(out, f'{d["confidence"]:.2f}', (p1[0], max(p1[1] - 8, 20)),
                    cv2.FONT_HERSHEY_SIMPLEX, font, (255, 0, 255), tebal, cv2.LINE_AA)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="file gambar dan/atau folder")
    ap.add_argument("--out", default=str(BASE / "hasil_deteksi"), help="folder hasil")
    ap.add_argument("--recursive", action="store_true", help="masuk ke subfolder")
    ap.add_argument("--conf", type=float, help="ganti conf_threshold dari model_meta.json")
    ap.add_argument("--mode", choices=["letterbox", "stretch"], help="ganti resize_mode dari model_meta.json")
    ap.add_argument("--api", help="URL endpoint (mis. http://127.0.0.1:8000/api/detect/) untuk uji end-to-end")
    ap.add_argument("--no-save", action="store_true", help="jangan simpan gambar berkotak, hanya CSV")
    args = ap.parse_args()

    files = kumpulkan(args.paths, args.recursive)
    if not files:
        sys.exit("Tidak ada gambar yang ditemukan.")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    detector = None
    if args.api:
        try:
            import requests
        except ImportError:
            sys.exit("Mode --api butuh paket requests:  pip install requests")
        print(f"Mode API: {args.api}")
    else:
        from app.detector import YOLODetector
        detector = YOLODetector()
        if args.conf is not None:
            detector.conf_threshold = args.conf
        if args.mode:
            if hasattr(detector, "resize_mode"):
                detector.resize_mode = args.mode
            else:
                print("(peringatan: detector.py belum mendukung resize_mode, --mode diabaikan)")
        print(f"Mode lokal: conf={detector.conf_threshold}, resize_mode={getattr(detector, 'resize_mode', 'letterbox (detector lama)')}")

    ringkas, semua = [], []
    for f in files:
        image = cv2.imread(str(f))
        if image is None:
            print(f"(dilewati, bukan gambar yang valid: {f})")
            continue
        h, w = image.shape[:2]
        t0 = time.perf_counter()

        if args.api:
            try:
                with f.open("rb") as fh:
                    resp = requests.post(args.api, files={"image": (f.name, fh, "image/jpeg")}, timeout=120)
            except requests.RequestException as exc:
                sys.exit(f"Server tidak bisa dihubungi di {args.api}\n"
                         "Jalankan dulu:  cd api  lalu  python manage.py runserver\n"
                         f"(detail: {type(exc).__name__})")
            if resp.status_code != 200:
                print(f"{f.name}: HTTP {resp.status_code} {resp.text[:120]}")
                continue
            data = resp.json()
            dets = data.get("detections", data.get("lokasi", []))
        else:
            dets = detector.predict(image)["detections"]

        ms = (time.perf_counter() - t0) * 1000
        nama = "__".join(f.parts[-2:]) if args.recursive else f.name
        cmax = max((d["confidence"] for d in dets), default=0.0)
        ringkas.append([nama, w, h, len(dets), round(cmax, 3), round(ms)])
        for d in dets:
            semua.append([nama, round(d["x1"], 1), round(d["y1"], 1), round(d["x2"], 1), round(d["y2"], 1), round(d["confidence"], 4)])
        if not args.no_save:
            cv2.imwrite(str(out / f"{Path(nama).stem}_deteksi.jpg"), gambar(image, dets))
        print(f"{nama:32s} {w}x{h:<6} {len(dets):3d} deteksi  conf maks {cmax:.2f}  {ms:6.0f} ms")

    with open(out / "ringkasan.csv", "w", newline="", encoding="utf-8") as fh:
        wr = csv.writer(fh); wr.writerow(["file", "lebar", "tinggi", "jumlah_deteksi", "conf_maks", "waktu_ms"]); wr.writerows(ringkas)
    with open(out / "deteksi.csv", "w", newline="", encoding="utf-8") as fh:
        wr = csv.writer(fh); wr.writerow(["file", "x1", "y1", "x2", "y2", "confidence"]); wr.writerows(semua)

    n_dengan = sum(1 for r in ringkas if r[3] > 0)
    print(f"\n{len(ringkas)} gambar diproses, {n_dengan} punya deteksi, total {len(semua)} kotak.")
    print(f"Hasil di: {out}")


if __name__ == "__main__":
    main()
