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

## Teknologi yang Digunakan
- Flutter (SDK ^3.10.8)
- Supabase → Backend as a Service (Database & Auth)
- fl_chart → Visualisasi data (grafik)
- intl → Formatting (mata uang, tanggal, dll)

## Arsitektur Sistem
Project ini menggunakan pendekatan layered architecture, yang terdiri dari:

- Presentation Layer → UI & interaksi pengguna
- Data Layer → Model & service (logic + API)
- Core Layer → Konfigurasi global (Supabase & theme)

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

## Analisis Struktur Code
### 1. Core Layer

`supabase_config.dart`
File ini berfungsi sebagai pusat konfigurasi backend:
``` dart
class SupabaseConfig {
  static const String url = 'YOUR_URL';
  static const String anonKey = 'YOUR_KEY';
}
``` 
Digunakan untuk:
- Inisialisasi koneksi ke Supabase
- Menghindari hardcode di banyak tempat

`app_theme.dart`
Mengatur tema global aplikasi:
``` dart
ThemeData(
  primarySwatch: Colors.brown,
  scaffoldBackgroundColor: Colors.white,
)
```
Tujuan:
- Konsistensi UI
- Maintainability desain

### 2. Data Layer

#### a. Models
Contoh: `menu_item_model.dart`
``` dart
class MenuItem {
  final String name;
  final int price;

  MenuItem({required this.name, required this.price});

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: json['name'],
      price: json['price'],
    );
  }
}
```
Fungsi:
- Representasi struktur tabel database
- Konversi JSON → Object (deserialization)

#### b. Services (Logic + Database Access)

`menu_service.dart`
Mengambil data menu dari Supabase:
``` dart
final response = await Supabase.instance.client
    .from('menu')
    .select();
```
`transaksi_service.dart`

Mengelola transaksi:

- Insert data transaksi
- Relasi dengan detail transaksi

`stock_service.dart`

Mengatur stok:
- Update stok saat transaksi
- Kontrol ketersediaan barang

`report_service.dart`

Menghasilkan laporan:
- Total penjualan
- Statistik data

`auth_service.dart`

Mengelola autentikasi:
- Login
- Register
- Session management

### 3. Presentation Layer

Layer ini adalah bagian UI.

#### a. Authentication
- `login_page.dart`
- `register_page.dart`
- `auth_wrapper.dart` → handle session login
  
#### b. Dashboard
`home_screen.dart`:
- Menampilkan ringkasan data
- Menggunakan widget seperti:
   - `dashboard_card.dart`
   - `header.dart`
     
#### c. Navigation
`main_navigation.dart`:
- Bottom navigation
- Routing antar halaman

#### d. Modul Fitur
| Modul   | Fungsi                    |
| ------- | ------------------------- |
| Menu    | Menampilkan daftar produk |
| Sales   | Transaksi penjualan       |
| Stock   | Manajemen stok            |
| Reports | Laporan                   |
| Rider   | Interface khusus kurir    |
| Profile | Data user                 |

#### e. Reusable Widgets
Contoh:
``` dart
DashboardCard(
  title: "Total Sales",
  value: "Rp 1.000.000",
)
```
Keuntungan:
- Mengurangi duplikasi kode
- Konsistensi UI

## Alur Sistem
- User login melalui auth_service
- Sistem memverifikasi ke Supabase
- User masuk ke dashboard
- Data diambil dari service layer
- Data ditampilkan ke UI
- Transaksi dilakukan
- Stok otomatis diperbarui
- Laporan dapat diakses real-time


## Cara Menjalankan:
Jalankan Melalui Terminal:
``` bash
flutter pub get
flutter run
```
Jalankan Melalui Web:
``` bash
flutter run -d chrome
```

## Konfigurasi Supabase
Pastikan mengisi:
- URL
- Anon Key
Pada:
``` dart
Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
);
```

## Kesimpulan
Aplikasi Ad A Coffee merupakan implementasi sistem informasi berbasis mobile yang dirancang untuk mendukung pengelolaan operasional coffee shop secara terintegrasi. Sistem ini menggabungkan berbagai fungsi utama seperti manajemen menu, transaksi penjualan, pengelolaan stok, serta penyajian laporan dalam satu platform yang terstruktur. Dengan memanfaatkan Flutter sebagai framework utama dan Supabase sebagai backend service, aplikasi ini mampu menghadirkan pengolahan data secara real-time dengan arsitektur yang modular dan terorganisir. Secara keseluruhan, aplikasi ini menunjukkan penerapan konsep pengembangan perangkat lunak yang sistematis, mulai dari pemisahan layer hingga integrasi layanan backend, sehingga mampu memenuhi kebutuhan dasar sistem informasi pada skala bisnis coffee shop.
