# Folio V5 Luxe Redesign

Bu sürüm özellikle senin geri bildirimin doğrultusunda renk dili ve görsel rafinasyon için yeniden yapıldı.

## Bu turda odaklandığım şeyler

- Soğuk veya rastgele duran tonlar çıkarıldı.
- Ana renk sistemi kırık beyaz, sütlü fildişi, bej, açık kahve ve taupe eksenine alındı.
- Kart yüzeyleri artık daha sıcak, daha sakin ve daha premium görünüyor.
- Grafik bileşenleri daha güçlü hale getirildi.
- Analiz ekranı da ana ekranla aynı kalite seviyesine yaklaştırıldı.

## Yapılan ana değişiklikler

### 1) Renk sistemi tamamen yenilendi
- `app_colors.dart` yeniden yazıldı.
- Light mode artık broken white + beige + latte + coffee paleti kullanıyor.
- Dark mode da aynı lüks hissi koruyacak şekilde sıcak koyu tonlara alındı.

### 2) Theme rafine edildi
- `app_theme.dart` güncellendi.
- Switch, chip, input, button ve selected state renkleri daha uyumlu hale getirildi.

### 3) Premium yüzeyler güçlendirildi
- `premium_surface.dart` içinde daha doğal gölge ve daha sıcak card hissi verildi.
- Hafif highlight ve daha kontrollü border sistemi eklendi.

### 4) Arka plan daha iyi hale getirildi
- `folio_background.dart` iki katmanlı yumuşak glow ile yeniden düzenlendi.
- Artık ekran daha boş değil, ama hâlâ temiz ve premium.

### 5) Grafikler güçlendirildi
- `spending_chart.dart` içinde:
  - daha rafine alan dolgusu,
  - daha iyi average line,
  - daha iyi tooltip davranışı,
  - daha güçlü çizgi hissi verildi.

### 6) Dashboard daha üst seviyeye çekildi
- Büyük sayı alanı + metrik kartları + harcama ritmi kartı + kategori kartı daha premium yapıya geçti.
- Son işlemler ve quick links daha temiz yüzeylerde toplandı.

### 7) Analytics screen de geliştirildi
- Bölümler kart yapısına taşındı.
- Merchant ranking, weekday rhythm ve savings story daha güçlü gösteriliyor.

## Güncellenen ana dosyalar
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_theme.dart`
- `lib/presentation/widgets/folio_background.dart`
- `lib/presentation/widgets/premium_surface.dart`
- `lib/presentation/widgets/spending_chart.dart`
- `lib/presentation/dashboard/dashboard_screen.dart`
- `lib/presentation/analytics/analytics_screen.dart`
- `lib/presentation/profile/profile_screen.dart`
- `lib/presentation/widgets/category_spend_row.dart`
- `lib/presentation/widgets/insight_block.dart`

## Not
Flutter SDK bu ortamda olmadığı için burada derleme yapılamadı. Cursor içinde açıp şu sırayla çalıştır:

```bash
flutter pub get
dart format .
flutter analyze
flutter run
```
