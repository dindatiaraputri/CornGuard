from django.urls import path

from .views import detect_image, diagnose_image, health

urlpatterns = [
    path("detect/", detect_image, name="detect-image"),      # YOLO saja (uji)
    path("diagnose/", diagnose_image, name="diagnose-image"),  # pipeline hybrid
    path("health/", health, name="health"),
]
