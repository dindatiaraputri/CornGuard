from django.db import models


class Recommendation(models.Model):
    label = models.CharField(max_length=50, unique=True)
    title = models.CharField(max_length=200)
    content = models.TextField()
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.label


class Diagnosis(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    label = models.CharField(max_length=50)
    confidence = models.FloatField()
    scores = models.JSONField()
    detections = models.JSONField(default=list)
    recommendation = models.ForeignKey(
        Recommendation, null=True, blank=True, on_delete=models.SET_NULL
    )