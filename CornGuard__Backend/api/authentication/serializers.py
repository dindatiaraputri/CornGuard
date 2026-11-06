from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

User = get_user_model()

class RegisterSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(
        write_only=True, 
        required=True, 
        validators=[validate_password]
    )
    password_confirm = serializers.CharField(
        write_only=True, 
        required=True
    )

    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'password', 'password_confirm')

    def validate_email(self, value):
        """Memastikan email belum terdaftar di sistem."""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email ini sudah terdaftar.")
        return value

    def validate(self, attrs):
        """Memastikan password dan password_confirm cocok."""
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Password dan konfirmasi password tidak cocok."})
        return attrs

    def create(self, validated_data):
        # Buang password_confirm sebelum disimpan ke database
        validated_data.pop('password_confirm')
        
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user