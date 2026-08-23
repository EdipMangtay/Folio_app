# Google Play Release Checklist

- [ ] Benzersiz `applicationId` belirle (`com.folio.wallet` placeholder'ını değiştir).
- [ ] Release keystore oluştur ve güvenli sakla.
- [ ] Play App Signing yapılandır.
- [ ] Version code/version name güncelle.
- [ ] Target SDK'yı kullanılan güncel Flutter template'inin ürettiği değerde tut.
- [ ] minSdk 24 doğrula.
- [ ] Kamera/photo picker akışını fiziksel Android cihazda test et.
- [ ] Farklı ekran boyutları ve gesture navigation test et.
- [ ] Privacy Policy URL hazırla.
- [ ] Data Safety formunu gerçek build'e göre doldur.
- [ ] Content rating tamamla.
- [ ] Store listing, icon, screenshots ve feature graphic hazırla.
- [ ] Internal testing track'e yükle.
- [ ] `flutter analyze` temiz.
- [ ] `flutter test` temiz.
- [ ] `flutter build appbundle --release` başarılı.
- [ ] Crash/ANR pre-launch report sonuçlarını kontrol et.

- [ ] Android biyometrik/device credential kilit akışını gerçek cihazda test et.
