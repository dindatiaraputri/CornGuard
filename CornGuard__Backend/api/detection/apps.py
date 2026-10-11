import os
import sys

from django.apps import AppConfig


class DetectionConfig(AppConfig):
    name = "detection"

    def ready(self):
        # Muat model saat server start, BUKAN per request.
        argv = sys.argv
        is_manage = bool(argv) and argv[0].endswith("manage.py")

        # migrate, shell, test, dll. tidak butuh model.
        if is_manage and (len(argv) < 2 or argv[1] != "runserver"):
            return
        # runserver menjalankan 2 proses (autoreload); muat hanya di proses anak.
        if is_manage and os.environ.get("RUN_MAIN") != "true":
            return

        from .ai import load_models

        load_models()
