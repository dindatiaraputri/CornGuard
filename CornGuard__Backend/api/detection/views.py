import logging

import cv2
import numpy as np
from rest_framework import status
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

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
    return Response({"success": True, **result})


@api_view(["GET"])
def health(request):
    """Cek model termuat atau belum (berguna untuk debugging dan deployment)."""
    info = model_status()
    ready = info["yolo"] and info["classifier"]
    return Response(
        {"ready": ready, **info},
        status=status.HTTP_200_OK if info["yolo"] else status.HTTP_503_SERVICE_UNAVAILABLE,
    )
