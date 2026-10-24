import logging
import os
import time
import cv2
import numpy as np
from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.permissions import IsAuthenticated
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
    """Pipeline hybrid dengan penanganan visualisasi bounding box yang aman dan filter top_confidence."""
    uploaded = request.FILES.get("image")
    if not uploaded:
        return Response(
            {"success": False, "message": "Field gambar wajib diisi dengan nama 'image'."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if uploaded.size > MAX_IMAGE_BYTES:
        return Response(
            {"success": False, "message": "Ukuran gambar maksimal 10 MB."},
            status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        )

    try:
        # 1. Baca buffer gambar sekali di awal untuk OpenCV
        uploaded.seek(0)
        file_bytes = np.frombuffer(uploaded.read(), dtype=np.uint8)
        img_opencv = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

        if img_opencv is None:
            return Response(
                {"success": False, "message": "File bukan gambar yang valid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 2. Re-seek ke awal untuk diproses AI Pipeline
        uploaded.seek(0)
        result = get_pipeline().predict(img_opencv)

    except PipelineNotReady as exc:
        return Response(
            {"success": False, "message": str(exc)},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except Exception as e:
        log.exception("Pipeline diagnosis gagal")
        return Response(
            {"success": False, "message": f"Terjadi kesalahan AI: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    top_confidence = result.get("kepercayaan", 0)
    lokasi_list = result.get("lokasi", [])
    penyakit = result.get("penyakit", "Unknown")

    # --- FILTER SATPAM TOP CONFIDENCE (BATAS 20%) ---
    if top_confidence < 0.20:
        return Response(
            {
                "success": False,
                "message": "Gejala tidak terdeteksi dengan jelas. Mohon ambil foto daun jagung lebih dekat dan pastikan pencahayaan cukup."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    user_obj = request.user if request.user.is_authenticated else None

    # 3. Simpan ke Database (Hanya jika lolos filter top_confidence)
    rec = Recommendation.objects.filter(label=penyakit).first()
    diagnosis_obj = Diagnosis.objects.create(
        user=user_obj,
        label=penyakit,
        confidence=top_confidence,
        scores=result.get("skor_kelas", {}),
        detections=lokasi_list,
        recommendation=rec,
    )

    # 4. Format data respon dasar
    response_data = {
        "success": True,
        "id": diagnosis_obj.id,
        "penyakit": penyakit,
        "kepercayaan": top_confidence,
        "rekomendasi": rec.content if rec else None,
        "lokasi": lokasi_list,
        "image_url": None,
    }

    # 5. Visualisasi Bounding Box (Jika lokasi ditemukan oleh YOLO)
    if lokasi_list:
        try:
            img_visual = img_opencv.copy()
            for item in lokasi_list:
                if isinstance(item, dict):
                    x1 = int(item.get("x1", item.get("box", [0, 0, 0, 0])[0]))
                    y1 = int(item.get("y1", item.get("box", [0, 0, 0, 0])[1]))
                    x2 = int(item.get("x2", item.get("box", [0, 0, 0, 0])[2]))
                    y2 = int(item.get("y2", item.get("box", [0, 0, 0, 0])[3]))
                    conf = item.get("confidence", item.get("conf", 0))

                    cv2.rectangle(img_visual, (x1, y1), (x2, y2), (0, 0, 255), 4)
                    label_text = f"{penyakit} {float(conf):.2f}"
                    
                    (text_w, text_h), _ = cv2.getTextSize(label_text, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
                    cv2.rectangle(img_visual, (x1, max(y1 - 25, 0)), (x1 + text_w, max(y1, 25)), (0, 0, 255), -1)
                    cv2.putText(
                        img_visual,
                        label_text,
                        (x1, max(y1 - 5, 20)),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.7,
                        (255, 255, 255),
                        2,
                    )

            output_dir = os.path.join(settings.BASE_DIR, "media", "hasil_deteksi")
            os.makedirs(output_dir, exist_ok=True)

            filename = f"result_{user_obj.id if user_obj else 'anon'}_{int(time.time())}.jpg"
            save_path = os.path.join(output_dir, filename)
            cv2.imwrite(save_path, img_visual)

            response_data["image_url"] = request.build_absolute_uri(f"/media/hasil_deteksi/{filename}")
        except Exception as e:
            log.exception(f"Gagal menggambar bounding box: {e}")

    return Response(response_data, status=status.HTTP_200_OK)


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