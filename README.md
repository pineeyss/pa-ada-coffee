![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=flat&logo=supabase&logoColor=white)
![GetX](https://img.shields.io/badge/GetX-8A2BE2?style=flat&logo=flutter&logoColor=white)

# Ad A Coffee – Flutter Coffee Management App
## Deskripsi Singkat
Perkembangan teknologi mobile mendorong digitalisasi pada berbagai sektor bisnis, termasuk industri coffee shop. Sistem manual dalam pengelolaan menu, transaksi, dan stok seringkali menimbulkan permasalahan seperti ketidakefisienan, human error, dan keterlambatan pelaporan.

Berdasarkan permasalahan tersebut, dikembangkan aplikasi Ad A Coffee, yaitu sistem informasi berbasis mobile yang mampu mengelola operasional coffee shop secara terintegrasi menggunakan teknologi Flutter dan Supabase.

## Tujuan Pengembangan
Pengembangan aplikasi ini bertujuan untuk:

- Mengelola data menu kopi secara terstruktur
- Memproses transaksi penjualan
- Mengontrol stok barang
- Menyajikan laporan penjualan
- Mendukung multi-role user (admin & rider)
- Mengintegrasikan database secara real-time

## Alur Sistem
- User login melalui auth_service
- Sistem memverifikasi ke Supabase
- User masuk ke dashboard
- Data diambil dari service layer
- Data ditampilkan ke UI
- Transaksi dilakukan
- Stok otomatis diperbarui
- Laporan dapat diakses real-time


## Teknologi yang Digunakan
- Flutter (SDK ^3.10.8)
- Supabase -> Backend as a Service (Database & Auth)
- fl_chart -> Visualisasi data (grafik)
- intl -> Formatting (mata uang, tanggal, dll)
- Spreadsheets -> untuk menyalin, mengelola, dan menyimpan data agar lebih mudah ditampilkan.

## Cara Menjalankan

1. Clone repository
```bash
git clone <url-repo>
```

2. Masuk ke folder project
```bash
cd pa-ada-coffe
```

3. Buat file `.env` di root project
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Install dependencies
```bash
flutter pub get
```

5. Jalankan aplikasi

- jalankan langsung
```bash
flutter run
```
- jalankan melalui web
```bash
flutter run -d chrome
```

> Pastikan menggunakan Flutter versi stabil terbaru. Cek versi aktif dengan `flutter --version`.



## Struktur Project

```` bash
lib
├── core
│   ├── app_constans.dart
│   ├── supabase
│   │   ├── selected_gerobak_store.dart
│   │   └── supabase_config.dart
│   └── theme
│       └── app_theme.dart
├── data
│   ├── models
│   │   ├── detail_transaksi_model.dart
│   │   ├── menu_item_model.dart
│   │   └── transaksi_model.dart
│   └── services
│       ├── auth_service.dart
│       ├── gerobak_service.dart
│       ├── menu_service.dart
│       ├── report_service.dart
│       ├── stock_service.dart
│       └── transaksi_service.dart
├── main.dart
├── presentation
│   ├── auth
│   │   ├── auth_wrapper.dart
│   │   ├── login_page.dart
│   │   └── register_page.dart
│   ├── dashboard
│   │   └── home_screen.dart
│   ├── home
│   │   └── main_navigation.dart
│   ├── menu
│   │   └── menu_screen.dart
│   ├── profile
│   │   └── profile_screen.dart
│   ├── reports
│   │   └── reports_screen.dart
│   ├── rider
│   │   ├── rider_navigation.dart
│   │   └── rider_page.dart
│   ├── sales
│   │   └── sales_screen.dart
│   ├── stock
│   │   └── stock_screen.dart
│   └── widgets
│       ├── app_button.dart
│       ├── app_card.dart
│       ├── dashboard_card.dart
│       ├── empty_state.dart
│       └── header.dart
└── utils
    ├── currency_formatter.dart
    └── dialog_helper.dart

````

## Fitur Aplikasi

## Databse

untuk database, dalam pengembangan aplikasi Ad A Coffee, disini kami menggunakan Supabase. SUpabase sendiri pada dasarnya adalah database relasional berbasis cloud yang menggunakan PostgreSQL sebagai inti sistemnya. Artinya, Supabase bukan sekadar “tempat menyimpan data”, tapi database SQL lengkap yang sudah siap pakai tanpa perlu instalasi manual.

### Relasional


<img width="1321" height="729" alt="image" src="https://github.com/user-attachments/assets/61ccffc6-27f0-468d-9c46-fbc79b53253d" />

Relasi pada skema tersebut menggambarkan alur data dari identitas pengguna hingga proses transaksi penjualan dalam satu sistem yang saling terhubung. Pada bagian awal, tabel profiles berperan sebagai penyimpan data utama pengguna, seperti nama, email, dan peran. Tabel ini terhubung langsung dengan tabel riders, di mana setiap rider merepresentasikan pengguna yang memiliki peran operasional di lapangan. Hubungan antara keduanya bersifat satu-ke-satu, karena satu akun pengguna hanya diasosiasikan dengan satu rider.


Selanjutnya, rider memiliki keterkaitan dengan tabel gerobak, yang menunjukkan bahwa setiap gerobak dikelola oleh seorang rider. Hubungan ini bersifat satu-ke-banyak, karena satu rider dapat mengelola lebih dari satu gerobak, sementara satu gerobak hanya dimiliki oleh satu rider. Dari gerobak inilah aktivitas bisnis utama berlangsung, termasuk pengelolaan menu dan transaksi.


Tabel menu berfungsi sebagai data master yang menyimpan daftar produk yang dijual. Relasi antara gerobak dan menu tidak langsung, melainkan melalui tabel stok_gerobak. Tabel ini menjadi penghubung yang merepresentasikan hubungan banyak-ke-banyak, karena satu gerobak dapat memiliki banyak jenis menu dan satu menu yang sama bisa tersedia di beberapa gerobak. Selain sebagai penghubung, tabel ini juga menyimpan atribut penting seperti stok awal dan stok saat ini, yang menunjukkan bahwa relasi tersebut tidak hanya bersifat struktural tetapi juga operasional.


Dalam konteks transaksi, tabel transaksi mencatat setiap aktivitas pembelian yang terjadi pada suatu gerobak dan dilakukan oleh rider tertentu. Hubungan ini menunjukkan bahwa satu gerobak dapat menghasilkan banyak transaksi, dan seorang rider juga dapat terlibat dalam banyak transaksi. Untuk merinci isi setiap transaksi, digunakan tabel detail_transaksi yang menghubungkan transaksi dengan menu. Di sinilah terbentuk kembali relasi banyak-ke-banyak, karena satu transaksi bisa terdiri dari beberapa item menu, dan satu menu dapat muncul dalam berbagai transaksi yang berbeda. Tabel ini juga menyimpan informasi kuantitas, harga, dan subtotal, sehingga berperan penting dalam perhitungan nilai transaksi secara keseluruhan.


Secara keseluruhan, struktur relasi ini membentuk alur yang sistematis, dimulai dari identitas pengguna, kemudian ke pengelola (rider), dilanjutkan ke unit bisnis (gerobak), lalu ke produk (menu), hingga akhirnya ke aktivitas penjualan (transaksi dan detailnya). Pola ini mencerminkan penerapan database relasional yang terorganisir dengan baik, di mana setiap entitas memiliki peran spesifik dan saling terhubung melalui kunci relasi yang menjaga konsistensi serta integritas data.


### Tabel


<img width="1551" height="597" alt="image" src="https://github.com/user-attachments/assets/199b86ae-4f59-4528-bfba-482927c17ea0" />


disini dalam aplikasi yanh kami kembangkan, kami membuat 8 tabel yaitu tabel detail_transaksi, gerobak, menu, profiles, riders, stock_outlet, stok_gerobak, dan transaksi.


#### Tabel detail_transaksi


<img width="1532" height="469" alt="image" src="https://github.com/user-attachments/assets/430cdf7f-d757-40c3-807e-778ed5cd9d00" />


#### Tabel gerobak


<img width="1570" height="425" alt="image" src="https://github.com/user-attachments/assets/cd7304ce-4480-44fd-bae2-31da39983bf3" />


#### Tabel menu


<img width="1573" height="604" alt="image" src="https://github.com/user-attachments/assets/9b15f50e-b06d-41de-a16d-d784eee411fa" />


#### Tabel Profiles


<img width="1536" height="489" alt="image" src="https://github.com/user-attachments/assets/679f5924-0c57-4cef-aa15-eb2c4b4db3c9" />


#### Tabel riders


<img width="1572" height="421" alt="image" src="https://github.com/user-attachments/assets/7f1cd1a4-012c-4712-b3a9-536504326915" />


#### Tabel stock_outlet


<img width="1562" height="423" alt="image" src="https://github.com/user-attachments/assets/f3b4bb7f-9511-41b7-8f27-e0de2da9b56f" />


#### Tabel Stok_Gerobak


<img width="1585" height="512" alt="image" src="https://github.com/user-attachments/assets/9c3e405a-9293-4663-9201-ac9e2aa473fc" />


#### Tabel Transaksi


<img width="1553" height="472" alt="image" src="https://github.com/user-attachments/assets/845179b6-0189-4640-9fe8-9b17eb6f868e" />



## Widget yang Digunakan

Dalam pengembangan aplikasi Ad A Coffee, berbagai widget Flutter dimanfaatkan untuk membangun antarmuka yang responsif, modular, dan mudah dipelihara. Penggunaan widget dibagi menjadi dua kategori utama, yaitu built-in widget (bawaan Flutter) dan custom widget (komponen buatan sendiri).

### 1. Built-in Widget (Flutter)

Berikut beberapa widget utama yang digunakan:

a. Struktur Layout
- `Scaffold` → Kerangka dasar halaman (AppBar, Body, BottomNav)
- `AppBar` → Header aplikasi
- `Column & Row` → Menyusun layout secara vertikal & horizontal
- `Expanded & Flexible` → Mengatur proporsi ruang

Contoh:
``` dart
Scaffold(
  appBar: AppBar(title: Text("Dashboard")),
  body: Column(
    children: [
      Text("Welcome"),
    ],
  ),
)
```

#### b. Widget Tampilan Data
- `Text` → Menampilkan teks
- `Image` → Menampilkan gambar dari assets
- `Icon` → Menampilkan ikon
- `Card` → Menampilkan informasi dalam bentuk kartu

Contoh:
``` dart
Card(
  child: ListTile(
    title: Text("Espresso"),
    subtitle: Text("Rp 20.000"),
  ),
)
```

#### c. Navigasi
- `Navigator` → Perpindahan antar halaman
- `BottomNavigationBar` → Navigasi utama aplikasi

Contoh:
``` dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => DetailPage()),
);
```

#### d. Input & Interaksi
- `TextField` → Input user
- `ElevatedButton` → Tombol aksi
- `GestureDetector` → Menangani event klik

### 2. Custom Widget (Reusable Component)

Aplikasi ini juga mengimplementasikan custom widget untuk meningkatkan efisiensi dan konsistensi UI.

#### a. DashboardCard

Widget ini digunakan untuk menampilkan ringkasan data seperti total penjualan.

``` dart
class DashboardCard extends StatelessWidget {
  final String title;
  final String value;

  const DashboardCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(title),
          Text(value),
        ],
      ),
    );
  }
}
```

#### b. CustomButton

Digunakan untuk standarisasi tombol di seluruh aplikasi:
``` dart
ElevatedButton(
  onPressed: onPressed,
  child: Text(label),
)
```

#### c. Widget Modular Lainnya
- `MenuItemCard` → Menampilkan daftar menu kopi
- `TransactionItem` → Menampilkan detail transaksi
- `StockItemTile` → Menampilkan data stok
- `ReportChartWidget` → Visualisasi data (fl_chart)


## Halaman Aplikasi

## Kesimpulan
Aplikasi Ad A Coffee merupakan implementasi sistem informasi berbasis mobile yang dirancang untuk mendukung pengelolaan operasional coffee shop secara terintegrasi. Sistem ini menggabungkan berbagai fungsi utama seperti manajemen menu, transaksi penjualan, pengelolaan stok, serta penyajian laporan dalam satu platform yang terstruktur. Dengan memanfaatkan Flutter sebagai framework utama dan Supabase sebagai backend service, aplikasi ini mampu menghadirkan pengolahan data secara real-time dengan arsitektur yang modular dan terorganisir. Secara keseluruhan, aplikasi ini menunjukkan penerapan konsep pengembangan perangkat lunak yang sistematis, mulai dari pemisahan layer hingga integrasi layanan backend, sehingga mampu memenuhi kebutuhan dasar sistem informasi pada skala bisnis coffee shop.
