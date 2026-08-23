# Privacy Notes — Folio

Bu belge hukuki danışmanlık değildir; uygulamanın mevcut teknik veri akışını açıklar.

## Mevcut local-first davranış

- Transactions: cihazdaki SQLite veritabanında tutulur.
- Budgets/subscriptions: cihazdaki SQLite veritabanında tutulur.
- Tema/onboarding/isim tercihleri: shared preferences içinde tutulur.
- Receipt images: kullanıcı canlı kamera ile bilinçli olarak çeker veya galeriden seçer. Kamera controller ses kaydını kapalı (`enableAudio: false`) başlatır.
- Receipt OCR: ML Kit text recognition servis katmanında cihaz üzerinde çalışır.
- App içinde reklam SDK'sı yoktur.
- App içinde analytics/marketing SDK'sı yoktur.
- Opsiyonel cihaz kilidi `local_auth` üzerinden işletim sistemi doğrulamasını çağırır; uygulama biyometrik template/veri görmez veya saklamaz.
- Kartın tam PAN numarasını saklayan alan yoktur; demo payment label sadece maskeli gösterimdir.

## Production öncesi tekrar kontrol edilmesi gerekenler

Yeni SDK veya backend eklediğinizde:

1. Hangi verilerin cihazdan çıktığını belgeleyin.
2. Privacy Policy'yi güncelleyin.
3. App Store Privacy Nutrition Label cevaplarını güncelleyin.
4. Google Play Data Safety cevaplarını güncelleyin.
5. Hesap açma eklenirse hesap silme sürecini ekleyin.
6. Cloud backup eklenirse encryption, retention ve deletion kurallarını belirtin.
7. Crash/analytics SDK eklenirse SDK vendor veri pratiklerini ayrı değerlendirin.

Mağaza beyanlarını yayın anındaki gerçek uygulama build'ine göre doldurun; bu taslak tek başına mağaza beyanı değildir.
