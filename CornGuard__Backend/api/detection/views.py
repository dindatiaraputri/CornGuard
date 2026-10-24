import logging
import os
import cv2
import numpy as np
from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from .models import Diagnosis, Recommendation
from .ai import PipelineNotReady, get_detector, get_pipeline, model_status

log = logging.getLogger(__name__)

MAX_IMAGE_BYTES = 10 * 1024 * 1024


def _read_image(request):
    """Mengembalikan (image, None) bila valid, atau (None, Response error)."""
    uploaded = request.FILES.get("image")

    def fail(message, code):
        return None, Response({"success": False, "message": message}, status=code)

    if uploaded is None:
        return fail("Field gambar wajib diisi dengan nama 'image'.", status.HTTP_400_BAD_REQUEST)
    if uploaded.size == 0:
        return fail("File gambar kosong.", status.HTTP_400_BAD_REQUEST)
    if uploaded.size > MAX_IMAGE_BYTES:
        return fail("Ukuran gambar maksimal 10 MB.", status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)

    buffer = np.frombuffer(uploaded.read(), dtype=np.uint8)
    image = cv2.imdecode(buffer, cv2.IMREAD_COLOR)
    if image is None:
        return fail("File bukan gambar yang valid.", status.HTTP_400_BAD_REQUEST)
    return image, None


@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])
def detect_image(request):
    """Endpoint uji: hanya YOLO, tanpa klasifikasi."""
    image, error = _read_image(request)
    if error:
        return error
    try:
        result = get_detector().predict(image)
    except Exception:
        log.exception("Deteksi YOLO gagal")
        return Response(
            {"success": False, "message": "Terjadi kesalahan saat menjalankan deteksi."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
    return Response({"success": True, "model": "YOLO ONNX", **result})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def diagnose_image(request):
    """Pipeline hybrid: MobileNet, lalu YOLO hanya jika hasilnya Bulai."""
    image, error = _read_image(request)
    if error:
        return error
    try:
        result = get_pipeline().predict(image)
    except PipelineNotReady as exc:
        return Response(
            {"success": False, "message": str(exc)},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except Exception:
        log.exception("Pipeline diagnosis gagal")
        return Response(
            {"success": False, "message": "Terjadi kesalahan saat menjalankan diagnosis."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    # --- Validasi Anomali Untuk Semua Jenis Penyakit ---
    top_confidence = result.get("kepercayaan", 0)
    lokasi_list = result.get("lokasi", [])
    penyakit = result.get("penyakit")

    # 1. Jika tertebak Bulai TAPI YOLO tidak menemukan objek sama sekali -> Tolak
    if penyakit == "Bulai" and not lokasi_list:
        return Response(
            {
                "success": False,
                "message": "Gejala tidak terdeteksi dengan jelas. Harap ambil foto daun jagung dari jarak dekat."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    # 2. Jika tertebak penyakit lain TAPI confidence ragu-ragu (< 30%)
    if top_confidence < 0.30:
        return Response(
            {
                "success": False,
                "message": "Gambar tidak terdeteksi sebagai daun jagung yang valid. Mohon pastikan pencahayaan cukup dan foto fokus pada daun."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    user_obj = request.user if request.user.is_authenticated else None

    # Simpan ke Database
    rec = Recommendation.objects.filter(label=result["penyakit"]).first()
    Diagnosis.objects.create(
        user=user_obj,
        label=result["penyakit"],
        confidence=result["kepercayaan"],
        scores=result["skor_kelas"],
        detections=lokasi_list,
        recommendation=rec,
    )
    result["rekomendasi"] = rec.content if rec else None

    # --- Visualisasi Bounding Box & Generate URL ---
    result["image_url"] = None
    if lokasi_list:
        img_visual = image.copy()
        for item in lokasi_list:
            x1, y1 = int(item.get("x1", 0)), int(item.get("y1", 0))
            x2, y2 = int(item.get("x2", 0)), int(item.get("y2", 0))
            conf = item.get("confidence", 0)

            cv2.rectangle(img_visual, (x1, y1), (x2, y2), (0, 0, 255), 3)
            cv2.putText(
                img_visual,
                f"Bulai {conf}",
                (x1, max(y1 - 10, 20)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 0, 255),
                2,
            )

        output_dir = os.path.join(settings.BASE_DIR, "media", "hasil_deteksi")
        os.makedirs(output_dir, exist_ok=True)
        
        # Simpan file spesifik user biar nggak ke-overwrite anonim
        filename = f"result_{user_obj.id if user_obj else 'anon'}.jpg"
        save_path = os.path.join(output_dir, filename)
        cv2.imwrite(save_path, img_visual)

        # Mengembalikan absolute URL gambar
        result["image_url"] = request.build_absolute_uri(f"/media/hasil_deteksi/{filename}")

    return Response({"success": True, **result})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_user_history(request):
    """SubTask #72: Mengambil daftar riwayat diagnosa milik user yang login."""
    diagnoses = Diagnosis.objects.filter(user=request.user).order_by('-created_at')
    
    history_data = []
    for d in diagnoses:
        history_data.append({
            "id": d.id,
            "label": d.label,
            "confidence": round(d.confidence * 100 if d.confidence <= 1 else d.confidence, 1),
            "created_at": d.created_at.strftime("%d %b %Y, %H:%M"),
            "recommendation": d.recommendation.content if d.recommendation else None,
        })
        
    return Response({"success": True, "history": history_data})


@api_view(["GET"])
def health(request):
    """Cek model termuat atau belum (berguna untuk debugging dan deployment)."""
    info = model_status()
    ready = info["yolo"] and info["classifier"]
    return Response(
        {"ready": ready, **info},
        status=status.HTTP_200_OK if info["yolo"] else status.HTTP_503_SERVICE_UNAVAILABLE,
    )