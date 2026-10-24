# 🌽 CornGuard - Backend Service (API)

Backend layanan API berbasis Django REST Framework (DRF) untuk aplikasi **CornGuard**. Bertanggung jawab mengolah autentikasi pengguna (JWT), memproses diagnosis penyakit daun jagung menggunakan pipeline AI (MobileNet + YOLOv8), serta mencatat riwayat diagnosis ke database.

---

## 🚀 Panduan Memulai (Quick Start)

### 1. Persiapan Virtual Environment
Masuk ke direktori proyek dan aktifkan environment Python:

```powershell
# Jalankan di PowerShell / Terminal
.\.venv\Scripts\Activate.ps1
```

### 2. Instalasi Dependensi
```powershell
pip install -r requirements.txt
```

### 3. Jalankan Migrasi Database
```powershell
cd api
python manage.py migrate
```

### 4. Jalankan Server Lokal
```powershell
python manage.py runserver
```
> Server akan berjalan di: `http://127.0.0.1:8000/`

---

## 🔑 Akun Uji Coba (Testing Accounts)

| Role | Username | Password | Keterangan |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin` | `adminjagung` | Akses penuh ke Django Administrator (`/admin/`) |
| **User (Petani)** | `petani1` | `petanijagung` | Akun pengguna biasa untuk pengujian API/JWT |

---

## 📡 Daftar Endpoint Utama

### 🔐 Autentikasi (JWT)
* `POST /api/auth/register/` - Registrasi akun pengguna baru.
* `POST /api/auth/token/` - Login & dapatkan `access_token` serta `refresh_token`.
* `POST /api/auth/token/refresh/` - Perbarui token yang telah kadaluarsa.

### 🔬 Diagnosis AI
* `POST /api/diagnose/` - Upload foto daun jagung untuk mendapatkan hasil analisis penyakit & rekomendasi.
  > **Wajib Header:** `Authorization: Bearer <access_token>`

---

## 🧪 Langkah-Langkah Uji Coba API (Thunder Client / Postman)

### Step 1: Dapatkan Access Token JWT
1. Buat request dengan method **`POST`** ke `http://127.0.0.1:8000/api/auth/token/`.
2. Masukkan kredensial akun user (`petani1`).
3. Kirim (*Send*) dan salin nilai string **`access`** dari respon JSON.

![Tampilan Response Akses Token JWT](image.png)

### Step 2: Kirim Gambar untuk Diagnosis
1. Buat request **`POST`** ke `http://127.0.0.1:8000/api/diagnose/`.
2. Buka tab **Headers**, tambahkan:
   * **Key:** `Authorization`
   * **Value:** `Bearer <paste_access_token_di_sini>`
3. Buka tab **Body** (pilih `Form-Data` / `Multipart`):
   * **Key:** `image` (Ubah tipe dari *Text* menjadi *File*)
   * **Value:** Pilih foto daun jagung dari perangkat Anda.
4. Klik **Send**.

![Tampilan Input Gambar /api/diagnose](image2.png)

---

## 📊 Verifikasi Data di Dashboard Admin

1. Akses dashboard admin di `http://127.0.0.1:8000/admin/`.
2. Login menggunakan akun **Admin** (`admin`).
3. Masuk ke grup **Detection** -> **Diagnoses**.
4. Pastikan hasil diagnosis terbaru dari `petani1` tercatat otomatis beserta nama user, tingkat kepastian (*confidence*), dan tanggalnya.