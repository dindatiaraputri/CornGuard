from django.contrib import admin
from .models import Recommendation, Diagnosis


@admin.register(Recommendation)
class RecommendationAdmin(admin.ModelAdmin):
    list_display = ('label', 'title', 'updated_at')
    search_fields = ('label', 'title', 'content')


@admin.register(Diagnosis)
class DiagnosisAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'label', 'confidence', 'created_at') # <-- Tambah 'user'
    list_filter = ('label', 'created_at', 'user')
    search_fields = ('label', 'user__username')
    readonly_fields = ('created_at',)