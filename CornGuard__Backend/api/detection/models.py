from django.db import models
from django.contrib.auth.models import User  # <-- Import User bawaan Django

class Recommendation(models.Model):
    label = models.CharField(max_length=50, unique=True)
    title = models.CharField(max_length=200)
    content = models.TextField()
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.label


class Diagnosis(models.Model):
    # <-- Tambahkan field user ini:
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='diagnoses')
    
    created_at = models.DateTimeField(auto_now_add=True)
    label = models.CharField(max_length=50)
    confidence = models.FloatField()
    scores = models.JSONField()
    detections = models.JSONField(default=list)
    recommendation = models.ForeignKey(
        Recommendation, null=True, blank=True, on_delete=models.SET_NULL
    )

    def __str__(self):
        return f"{self.label} - {self.created_at.strftime('%Y-%m-%d %H:%M')}"