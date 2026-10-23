# Taruh file ini di: api/detection/management/commands/seed_recommendations.py
# (buat folder management/ dan management/commands/ kalau belum ada, masing-masing
# butuh file __init__.py kosong supaya dikenali Django sebagai package)
#
# Jalankan dengan: python manage.py seed_recommendations

from django.core.management.base import BaseCommand
from detection.models import Recommendation

DATA = [
    {
        "label": "Bulai",
        "title": "Bulai",
        "content": (
            "Penyebab: Peronosclerospora maydis (oomycetes/jamur).\n\n"
            "Ciri-ciri: Pada bagian daun terlihat jelas batas perbedaan warna antara daun sehat "
            "dan yang terkena jamur. Permukaan daun yang berpenyakit berwarna kuning keputihan "
            "dan pertumbuhannya terhambat.\n\n"
            "Penanganan kimia: Rendam benih sebelum ditanam dengan obat pelindung benih "
            "(metalaksil sudah kurang mempan, bisa diganti dimetomorf/fosfit). Bisa juga disemprot "
            "dengan ekstrak alami seperti rebusan cengkeh, mengkudu, atau bawang putih.\n\n"
            "Perawatan lahan: Segera cabut dan buang tanaman yang sudah terkena, karena bisa jadi "
            "sumber penularan ke tanaman sebelahnya. Pilih benih varietas tahan bulai (P36, Bisi 222). "
            "Jangan tanam jagung terus-menerus di lahan yang sama, selingi dengan kacang tanah, "
            "kedelai, atau ubi jalar.\n\n"
            "Sumber: Efikasi beberapa jenis fungisida nabati untuk mengendalikan penyakit bulai pada "
            "tanaman jagung varietas BISI-18, Jurnal Proteksi Agrikultus UNILA "
            "(https://jpa.fp.unila.ac.id/index.php/jpa/article/view/17)."
        ),
    },
    {
        "label": "Blight",
        "title": "Hawar Daun (Blight)",
        "content": (
            "Penyebab: Helminthosporium / Bipolaris maydis.\n\n"
            "Ciri-ciri: Muncul bercak basah kecil di daun, lama-lama membesar dan berubah coklat kering.\n\n"
            "Penanganan kimia: Semprot fungisida berbahan difenokonazol atau klorotalonil begitu "
            "bercak mulai terlihat.\n\n"
            "Perawatan lahan: Pilih varietas tahan. Segera cabut tanaman atau gulma yang sudah parah "
            "supaya tidak menular. Semprot rutin sampai jagung mulai berbunga.\n\n"
            "Sumber: Jurnal HPT Universitas Brawijaya "
            "(https://jurnalhpt.ub.ac.id/index.php/jhpt/article/view/399)."
        ),
    },
    {
        "label": "Common_Rust",
        "title": "Karat Daun (Common Rust)",
        "content": (
            "Penyebab: Puccinia sorghi / P. polysora.\n\n"
            "Ciri-ciri: Muncul bintik-bintik kecil warna kuning keemasan sampai coklat kemerahan "
            "di permukaan daun, seperti karat besi.\n\n"
            "Penanganan kimia: Semprot fungisida (mancozeb atau benomyl) segera setelah bintik muncul, "
            "ulangi tiap 10 hari sampai tanaman berbunga.\n\n"
            "Perawatan lahan: Pilih varietas tahan (Lamuru, Sukmaraga, Bima-1). Atur jarak tanam jangan "
            "terlalu rapat supaya lahan tidak terlalu lembap.\n\n"
            "Sumber: BBPOPT Kementan "
            "(https://bbpopt.tanamanpangan.pertanian.go.id/artikel/penyakit-karat-daun-tanaman-jagung)."
        ),
    },
    {
        "label": "Gray_Leaf_Spot",
        "title": "Bercak Daun (Gray Leaf Spot)",
        "content": (
            "Penyebab: Cercospora spp.\n\n"
            "Ciri-ciri: Bercak abu-abu memanjang sejajar urat daun, awalnya kekuningan lalu jadi "
            "kering keabuan.\n\n"
            "Penanganan kimia: Semprot fungisida (mancozeb, karbendazim, atau difenoconazol).\n\n"
            "Perawatan lahan: Bersihkan sisa-sisa batang/daun jagung dari panen sebelumnya, jangan "
            "dibiarkan menumpuk di lahan. Selingi tanam dengan tanaman lain.\n\n"
            "Sumber: Dinas Pertanian, materi penyuluhan bercak daun "
            "(https://distan.bulelengkab.go.id/informasi/detail/artikel/"
            "penyakit-bercak-daun-cercospora-pada-tanaman-padi-dan-cara-pengendaliannya-24)."
        ),
    },
    {
        "label": "Healthy",
        "title": "Sehat",
        "content": (
            "Ciri-ciri: Daun hijau segar merata, tanaman tumbuh normal.\n\n"
            "Penanganan: Tidak perlu obat apapun.\n\n"
            "Perawatan lahan: Pupuk cukup dan berimbang, pastikan air tidak menggenang, jarak tanam "
            "cukup lega, tetap dicek rutin biar cepat ketahuan kalau mulai ada tanda sakit."
        ),
    },
]


class Command(BaseCommand):
    help = "Mengisi atau memperbarui tabel Recommendation dari data riset penanganan penyakit jagung."

    def handle(self, *args, **options):
        for item in DATA:
            obj, created = Recommendation.objects.update_or_create(
                label=item["label"],
                defaults={"title": item["title"], "content": item["content"]},
            )
            status = "dibuat" if created else "diperbarui"
            self.stdout.write(self.style.SUCCESS(f"{item['label']}: {status}"))
