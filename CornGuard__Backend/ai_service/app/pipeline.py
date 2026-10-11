"""Pipeline hybrid: MobileNet dulu, YOLO hanya jika hasilnya Bulai."""
import time


class PipelineNotReady(RuntimeError):
    """Salah satu model yang dibutuhkan pipeline belum termuat."""


class HybridPipeline:
    def __init__(self, classifier, detector, trigger_label="Bulai"):
        self.classifier = classifier
        self.detector = detector
        self.trigger_label = trigger_label.lower()

    def predict(self, image):
        if self.classifier is None:
            raise PipelineNotReady("Model klasifikasi (MobileNet) belum termuat.")
        if self.detector is None:
            raise PipelineNotReady("Model deteksi (YOLO) belum termuat.")

        height, width = image.shape[:2]

        t0 = time.perf_counter()
        cls = self.classifier.predict(image)
        t_cls = (time.perf_counter() - t0) * 1000

        result = {
            "penyakit": cls["label"],
            "kepercayaan": cls["confidence"],
            "skor_kelas": cls["scores"],
            "image_width": width,
            "image_height": height,
            "detektor_dipanggil": False,
            "lokasi": [],
        }
        t_det = 0.0

        if cls["label"].lower() == self.trigger_label:
            t1 = time.perf_counter()
            det = self.detector.predict(image)
            t_det = (time.perf_counter() - t1) * 1000
            result["detektor_dipanggil"] = True
            result["lokasi"] = det["detections"]

        result["waktu_ms"] = {
            "klasifikasi": round(t_cls, 1),
            "deteksi": round(t_det, 1),
            "total": round(t_cls + t_det, 1),
        }
        return result
