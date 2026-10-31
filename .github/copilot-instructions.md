# Instruksi Copilot untuk Autodesk Complete Uninstaller

## Gambaran umum proyek

- Repositori ini adalah alat pembersihan Windows yang khusus untuk produk dan sisa-sisa Autodesk.
- Logika utama penghapusan produk berada di `autodesk_complete_uninstaller.bat`; file ini melakukan deteksi, uninstall berurutan berdasarkan dependensi, pembersihan mendalam, verifikasi, dan pembuatan log.
- GUI di `gui/src/AutodeskCleaner` adalah lapisan WPF yang tipis di atas mesin ini. GUI ini menyematkan file batch sebagai resource, mengekstraknya saat runtime, dan menjalankannya dengan flag lingkungan khusus GUI seperti `ADSK_GUI_MODE` dan `ADSK_GUI_ACTION`.
- Perilaku startup dibuat dengan prinsip keamanan: aplikasi memeriksa hak administrator, mendukung single-instance, dan menulis crash log ke direktori data aplikasi.

## Perintah build, test, dan validasi

Gunakan perintah berikut sebagai titik validasi yang saat ini tersedia di repositori:

- Build proyek GUI:
  - `dotnet build gui/src/AutodeskCleaner/AutodeskCleaner.csproj --nologo`
- Jalankan self-test headless (yang paling mirip dengan automated check yang ada):
  - `dotnet run --project gui/src/AutodeskCleaner/AutodeskCleaner.csproj -- --self-test`
- Tidak ada perintah lint khusus yang dikonfigurasi di repositori ini.
- Di checkout ini tidak ada `.sln` atau proyek dengan `dotnet test`.

Catatan keadaan saat ini: di workspace ini, proyek sedang gagal build dengan `CS0246` karena `App.xaml.cs` mereferensikan `MainWindow`, padahal tipe `MainWindow` tidak ada di proyek. Anggap perintah build di atas sebagai perintah yang diharapkan, tetapi verifikasi masalah window yang hilang sebelum menyimpulkan GUI sehat.

## Arsitektur tingkat tinggi

- `autodesk_complete_uninstaller.bat` adalah sumber kebenaran untuk perilaku uninstall dan pembersihan sisa-sisa. File ini besar dan stateful; ia mendaftarkan produk Autodesk yang terpasang, menghentikan layanan, mematikan proses, menghapus kunci registry, menghapus folder, dan memverifikasi sistem setelahnya.
- `gui/src/AutodeskCleaner` membungkus mesin tersebut dan menyediakan GUI Windows yang ramah untuk pengguna awam. Bagian pentingnya adalah:
  - `App.xaml.cs`: startup aplikasi, relaunch dengan elevation/UAC, enforcement single-instance, crash logging, dan penanganan `--self-test`.
  - `Services/EngineService.cs`: mengekstrak engine batch yang tertanam, menjalankannya melalui `cmd.exe`, dan mengalirkan output kembali ke GUI.
  - `Services/ProductScanner.cs`: deteksi produk Autodesk berdasarkan registry, dengan klasifikasi tipe/kategori dan deteksi orphan.
  - `Services/SettingsService.cs` dan `Localization/Loc.cs`: penyimpanan pengaturan dan pengalihan bahasa.
  - `Services/SelfTest.cs`: smoke test headless yang memvalidasi ekstraksi engine, kesamaan kunci lokalisasi, sumber daya tema, dan scanning registry.
- Aplikasi ini memang khusus untuk Windows: pembacaan/penulisan registry, UAC, penjadwalan tugas, restart Explorer, dan pembersihan filesystem adalah asumsi normal yang berlaku.
- Log dan artefak kerja diharapkan berada di `Desktop\Autodesk_Uninstaller` saat eksekusi engine normal. Jangan menganggap direktori temp generik saat mengubah perilaku output.

## Konvensi utama dan pola spesifik repositori

- Jaga agar file batch tetap menjadi mesin pembersihan utama. Hindari mengimplementasikan ulang logika uninstall di C# ketika engine sudah memilikinya.
- Pertahankan safety rails: pengecekan hak admin, konfirmasi pengguna, pembuatan log, restore point, dan langkah verifikasi/deteksi adalah bagian dari desain produk, bukan sekadar polish.
- Anggap kompatibilitas Windows 10/11 sebagai kebutuhan utama. Perbedaan registry/view, execution policy, hak admin, dan file locking adalah bagian dari lingkungan operasional normal.
- README dan CONTRIBUTING menegaskan pentingnya testing pada mesin nyata Windows dengan produk Autodesk yang terpasang. Jangan menganggap pengujian lintas platform sama.
- Saat mengubah engine atau aksi GUI, periksa baik file batch maupun pemetaan aksi di GUI agar perilaku tetap selaras.
- Tambahkan komentar untuk logika yang tidak jelas, terutama di file batch, karena proyek ini memang alat pembersihan berisiko tinggi dan bukan framework aplikasi umum.

## Panduan proyek dari dokumen yang sudah ada

- Ini adalah alat batch single-file sesuai desain, dan dokumen proyek secara eksplisit menyebutkan agar layer script tetap single-file.
- `CONTRIBUTING.md` mewajibkan testing dengan hak elevated/admin dan pada mesin Windows nyata yang memiliki produk Autodesk terpasang.
- Proyek ini adalah utilitas komunitas untuk Windows; prioritaskan kompatibilitas mundur dengan Windows 10 dan jangan membuang prompt verifikasi atau konfirmasi tanpa alasan yang jelas.
