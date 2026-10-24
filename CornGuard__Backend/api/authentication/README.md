Daftar Endpoint Utama:
POST /api/auth/token/ - Login & dapatkan token JWT.   
POST /api/diagnose/ - Upload foto daun & dapatkan hasil prediksi AI (wajib Header Authorization: Bearer <token>).

**TUTORIAL / UJI COBA **
1. Akun Admin Django Administrator (http://127.0.0.1:8000/admin/)
    username: admin
    password: adminjagung

2. Akun User:
    username: petani1
    password: petanijagung

# masuk venv kalau dependansi di venv
# Jalanin Server di PS D:\CORNGUARD_BACKEND\CornGuard__Backend\api> python manage.py runserver   

3. Test melalui Thunder Client / Postman / DRF
   # langkah-langkah
   1. Method: POST / http://127.0.0.1:8000/api/auth/token/
   2. Login sebagai akun user (bukan admin) > send
   3. Salin token (akses token)

   ![Tampilan Response Akses Token JWT](image.png)

   4. Masukkan token ke Header Authorization (Bearer <token>) saat nembak /api/diagnose/

   ![Tampilan Input Gambar /api/diagnosa](image-1.png)
   5. Isi "image" dan klik choose untuk memilih gambar > send

# kembali ke tampilan django administrator
Pilih grup Detection untuk melihat laporan yang disimpan dalam database

