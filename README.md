# Folio Flutter — V6 Signature

Warm broken-white / beige / mocha design system with custom financial data visualizations and premium mobile UX.

Folio, iOS ve Android için Flutter ile geliştirilmiş premium bir kişisel finans uygulamasıdır. Bu paket **UI V3** görsel refactor'unu içerir: çalışan veri/OCR/import altyapısı korunurken uygulama kabuğu, ana ekran, chart, navigation, işlemler, analiz, bütçeler, abonelikler, aylık rapor ve profil deneyimi quiet-luxury / editorial-finance tasarım diliyle baştan düzenlenmiştir.

## UI V3 — bu sürümde ne değişti?

- iPhone status bar / Dynamic Island ile çakışmayı engelleyen güvenli app shell
- Sıcak ivory + graphite tabanlı light/dark tasarım sistemi
- Manrope tabanlı editorial tipografi ve tabular finansal rakamlar
- Yeni Folio wordmark ve signature **Financial Pulse** görseli
- Baştan tasarlanan premium harcama ritmi chart'ı ve touch tooltip
- Generic BottomNavigationBar yerine floating Folio dock
- Kart kalabalığını azaltan açık, whitespace ağırlıklı ana ekran
- Hızlı ve tek-elle kullanılabilir manuel harcama akışı
- Storytelling mantığında Analytics
- Premium Budget / Subscription / Transaction detail ekranları
- Paylaşılabilir kalite hedefleyen fullscreen aylık rapor story
- Contextual loading / success / empty states
- Tek merkezden yönetilen color, spacing, radius, typography ve motion tokenları

Detaylı değişiklik listesi için `V3_CHANGELOG.md`, tasarım kuralları için `DESIGN_SYSTEM.md` dosyasına bakın.

## Neler hazır?

- Premium light / dark theme ve responsive mobil UI
- Opsiyonel Face ID / Touch ID / Android cihaz kilidi gizlilik perdesi
- iOS / Android native hissi veren navigation ve motion
- Ana sayfa: aylık harcama, trend, Money Pulse, kategori dağılımı, içgörüler
- Manuel harcama ekleme
- Mağazaya göre otomatik kategori tahmini
- İşlem arama, filtreleme ve detay
- İşlem silme
- Bütçeler ve kategori bazlı limitler
- Abonelik takibi
- Analiz ekranı: kategori, merchant, haftanın günleri, tasarruf oranı
- Aylık fullscreen "story" raporu
- SQLite ile cihaz üzerinde kalıcı veri
- Demo veri seti
- Uygulama içinde gerçek canlı kamera preview ile fiş tarama
- Kamera flaşı + galeri + native kamera fallback akışı
- Google ML Kit ile **cihaz üzerinde gerçek OCR**
- Fişten mağaza, tarih ve toplam tutar çıkarımı + kullanıcı doğrulaması
- CSV ekstrelerini cihaz üzerinde gerçek ayrıştırma
- XLSX ekstrelerini cihaz üzerinde gerçek ayrıştırma
- PDF ekstreler için güvenli doğrulamalı preview adapter'ı
- PWA/web değil: gerçek Flutter mobile app mimarisi
- App icon + native splash config
- iOS kamera/fotoğraf izin açıklamaları
- Android/iOS production shell bootstrap scripti
- Analyze / test / release build doğrulama scripti

## Teknoloji

- Flutter 3.47+
- Dart 3.12+
- Riverpod
- go_router
- sqflite
- shared_preferences (yeni cache API)
- google_mlkit_text_recognition
- camera (CameraX / AVFoundation-backed live preview)
- local_auth (Face ID / Touch ID / biometrics / device passcode)
- image_picker
- file_picker
- fl_chart
- excel
- csv

## Mimari

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── constants/
│   ├── router/
│   ├── theme/
│   └── utils/
├── data/
│   ├── database/
│   ├── demo/
│   ├── repositories/
│   └── services/
├── domain/
│   ├── analytics/
│   └── models/
├── state/
└── presentation/
    ├── add/
    ├── analytics/
    ├── budgets/
    ├── dashboard/
    ├── import/
    ├── onboarding/
    ├── profile/
    ├── report/
    ├── shell/
    ├── subscriptions/
    ├── transactions/
    └── widgets/
```

UI → Riverpod state → Repository → SQLite şeklinde katmanlıdır. OCR ve ekstre ayrıştırıcıları servis olarak ayrılmıştır; ileride API/Supabase/Firebase bağlamak için UI'ı yeniden yazmak gerekmez.

---

# 1. İlk kurulum

Makinede Flutter stable kurulu olmalı. macOS'ta iOS için ayrıca Xcode, Android için Android Studio/SDK gerekir.

Proje klasöründe:

```bash
chmod +x tool/bootstrap.sh tool/verify.sh
FOLIO_BUNDLE_ID=com.sirketiniz.folio ./tool/bootstrap.sh
```

Bu script:

1. Makinedeki Flutter sürümünü kontrol eder.
2. Eksikse güncel Flutter SDK'nızla `ios/` ve `android/` platform shell'lerini oluşturur.
3. `FOLIO_BUNDLE_ID` ile verdiğiniz Bundle/Application ID, min SDK ve izinleri uygular.
4. `flutter pub get` çalıştırır.
5. App icon ve native splash üretir.
6. `flutter analyze` çalıştırır.
7. Testleri çalıştırır.

Platform klasörlerinin yerel Flutter sürümünüzle üretilmesi bilinçli bir tercihtir; bu sayede eski bir Flutter template'ini ZIP içine gömmek yerine kurduğunuz güncel SDK'nın native dosyaları kullanılır.

---

# 2. Çalıştırma

## iPhone Simulator

```bash
open -a Simulator
flutter run
```

Birden çok device varsa:

```bash
flutter devices
flutter run -d <device-id>
```

## Android Emulator

Android Studio'dan emulator başlatın:

```bash
flutter devices
flutter run -d <device-id>
```

## Gerçek cihaz

```bash
flutter devices
flutter run -d <device-id>
```

Fiş kamerası, flaş, gallery picker ve OCR akışını fiziksel cihazda mutlaka test edin.

---

# 3. Release doğrulama

```bash
./tool/verify.sh
```

Script:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

çalıştırır. macOS'ta ayrıca codesign olmadan iOS release build dener.

---

# 4. Google Play release

Önce kendi benzersiz package ID'nizi kullanın. Projede placeholder:

```text
com.folio.wallet
```

Bootstrap sırasında sahip olduğunuz benzersiz ID’yi environment variable ile verin, örneğin:

```bash
FOLIO_BUNDLE_ID=com.sirketiniz.folio ./tool/bootstrap.sh
```

Android App Bundle:

```bash
flutter build appbundle --release
```

Çıktı normalde:

```text
build/app/outputs/bundle/release/app-release.aab
```

Google Play Console'a yüklemeden önce:

- release signing / keystore
- Privacy Policy URL
- Data safety form
- uygulama kategorisi
- içerik derecelendirmesi
- store screenshots
- production testleri

hazırlanmalıdır.

`docs/GOOGLE_PLAY_CHECKLIST.md` dosyasına bakın.

---

# 5. App Store release

macOS + Xcode gerekir.

Önce bootstrap sırasında gerçek Bundle ID’nizi verin, ardından Apple Developer hesabınızın Team ve Bundle ID ayarlarını Xcode’da yapılandırın.

```bash
flutter build ipa --release
```

Ardından Xcode Organizer / Transporter üzerinden App Store Connect'e yükleyebilirsiniz.

Bu proje fiş OCR'ı için ML Kit kullandığından iOS deployment target `15.5` olarak ayarlanır.

`docs/APP_STORE_CHECKLIST.md` dosyasına bakın.

---

# 5.1 Native kamera

Fiş ekranı yalnızca sistem picker açmaz. `camera` paketiyle uygulama içinde canlı arka kamera preview gösterir; kullanıcı çerçeve içinde fişi konumlandırabilir, flaşı açabilir ve doğrudan fotoğraf çekebilir. Kamera erişilemezse galeri ve native kamera fallback akışları korunur. Video/ses kaydı yapılmaz; `CameraController` `enableAudio: false` ile başlatılır.

Kamera lifecycle yönetimi uygulama arka plana/alana dönerken controller'ı dispose/reinitialize eder. Bu davranışı gerçek iPhone ve Android cihazda test edin.

## Cihaz kilidi

Profil → Veri ve gizlilik → **Cihaz kilidi** ile opsiyonel koruma açılabilir. `local_auth`, doğrulamayı işletim sistemine bırakır; Folio Face ID/parmak izi verisine erişmez. Kilit açıksa uygulama arka plandan döndüğünde finansal içerik tekrar gizlenir.

# 6. Fiş OCR nasıl çalışıyor?

`lib/data/services/receipt_analyzer.dart`

Akış:

```text
Canlı CameraPreview / galeri
      ↓
Camera + ImagePicker fallback
      ↓
ML Kit Text Recognition (on-device)
      ↓
ReceiptTextParser
      ↓
Merchant + Date + Amount + Category
      ↓
Kullanıcı doğrulaması
      ↓
SQLite transaction
```

OCR sonucu **kesin finansal gerçek** kabul edilmez. Kaydetmeden önce kullanıcıya alanlar düzenlenebilir şekilde gösterilir. Bu özellikle farklı fiş formatlarında yanlış tutar kaydetme riskini azaltır.

---

# 7. Ekstre import

`lib/data/services/statement_parser.dart`

### CSV
Gerçek ayrıştırılır. Türkçe/İngilizce yaygın sütun isimleri algılanır:

```text
Açıklama / İşlem / Merchant / Description
Tutar / Amount
Borç / Debit
Alacak / Credit
Tarih / Date
```

### XLSX
`excel` paketi ile cihaz üzerinde gerçek okunur. İlk sayfalardaki metadata satırlarını geçip olası header satırı bulunur.

### PDF
Bankaların PDF yapısı ve tablo layout'u birbirinden ciddi ölçüde farklı olduğu için sessizce yanlış finansal veri üretmek yerine doğrulamalı preview adapter'ı kullanılır. Production'da hedef bankalar belli olduğunda `StatementParser` arayüzünün altına banka-spesifik parser'lar veya güvenli backend parser eklenebilir.

---

# 8. Veri gizliliği

Mevcut sürüm:

- kullanıcı hesabı gerektirmez,
- finansal hareketleri SQLite'ta cihaz üzerinde tutar,
- telemetry/analytics SDK eklemez,
- reklam SDK'sı içermez,
- fiş OCR'ını uygulama servis katmanında on-device yapar,
- kartın tam numarasını saklamaz,
- kullanıcı isterse uygulama erişimini cihaz biyometrisi/parolasıyla kilitler; biyometrik veri uygulamaya verilmez.

Bu davranışı backend, analytics veya crash-reporting eklediğinizde Privacy Policy ve mağaza veri beyanlarıyla güncellemeniz gerekir.

`docs/PRIVACY_NOTES.md` dosyasına bakın.

---

# 9. Tasarım sistemi

`DESIGN_SYSTEM.md`

Temel yaklaşım:

- quiet luxury
- editorial finance
- sıcak off-white canvas
- az kart, çok whitespace
- tabular finansal sayılar
- düşük kontrastlı border
- kontrollü iris accent
- motion yalnızca feedback için
- AI etiketi yerine doğrudan faydalı içgörü
- minimum 44px dokunma alanları

Typography `google_fonts` üzerinden **Manrope** kullanır; para değerlerinde tabular figures ve kontrollü negatif tracking uygulanır. Projeye lisansı belirsiz/proprietary font dosyası gömülmemiştir. İsterseniz daha sonra `AppTypography` üzerinden kendi lisanslı fontunuzu tek noktadan değiştirebilirsiniz.

---

# 10. Production'a geçmeden önce önerilen sonraki katmanlar

Bu ZIP güçlü bir çalışan local-first MVP temelidir. Gerçek ürün yayınında aşağıdakiler ayrıca eklenebilir:

- authentication
- encrypted cloud sync / backend
- multi-device sync
- bank integrations / open banking
- backup & restore
- crash reporting
- remote feature flags
- localization (EN vb.)
- server-side bank PDF parsers
- real subscription detection model
- push notification permission flow
- legal Terms / Privacy screens

Bunların hiçbiri mevcut UI/data mimarisinin yeniden yazılmasını gerektirmez; repository/service katmanları bu amaçla ayrılmıştır.

---

# UI V3 sonrası ilk yerel doğrulama

Bu paket UI katmanında kapsamlı bir refactor içerir. Projeyi kendi Flutter SDK'nızın bulunduğu makinede açtıktan sonra ilk olarak şunları çalıştırın:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

`build/`, `.dart_tool/`, iOS `Pods/` ve makineye özel `local.properties` gibi yeniden üretilebilen dosyalar dağıtım ZIP'ine bilinçli olarak dahil edilmez. `flutter pub get` / CocoaPods bunları gerektiğinde yeniden üretir.

# Komut özeti

```bash
FOLIO_BUNDLE_ID=com.sirketiniz.folio ./tool/bootstrap.sh
flutter run
./tool/verify.sh
flutter build appbundle --release
flutter build ipa --release
```