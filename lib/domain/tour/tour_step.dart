/// Something the tour can point at.
///
/// Named rather than keyed so the phone dock and the tablet rail can offer the
/// same targets without the tour knowing which shell is on screen.
enum TourTarget {
  homeTab,
  transactionsTab,
  addButton,
  analyticsTab,
  profileTab,

  // Controls inside a page. A tour that only names tabs says where things
  // live but never where anything is done.
  periodSelector,
  incomeMetric,
  transactionFilters,
}

sealed class TourStep {
  const TourStep();
}

/// A stop that asks for something instead of pointing at something.
class TourFormStep extends TourStep {
  const TourFormStep({required this.title, required this.body});

  final String title;
  final String body;
}

/// A stop that highlights one control and says what it is for.
class TourSpotlightStep extends TourStep {
  const TourSpotlightStep({
    required this.tab,
    required this.target,
    required this.title,
    required this.body,
    this.badge,
  });

  /// The branch index the shell must be showing before this stop makes sense.
  final int tab;
  final TourTarget target;
  final String title;
  final String body;
  final String? badge;
}

/// Income comes first on purpose: a fresh install has an empty wallet, so a
/// tour that asked for it last would spend every stop explaining blank screens.
const List<TourStep> kTourSteps = <TourStep>[
  TourFormStep(
    title: 'Gelirini gir.',
    body: 'Tek bir gelir kaydı yeter. Turun geri kalanını kendi rakamınla '
        'gezersin, sonra istediğin zaman değiştirebilirsin.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.periodSelector,
    badge: 'DÖNEM SEÇİMİ',
    title: 'Önce dönemi seç',
    body: 'Buradan ay değiştirirsin. Banka ekstresi çoğunlukla kapanmış bir '
        'ayı kapsar, o yüzden rakamlarını göremezsen ilk bakacağın yer burası.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.incomeMetric,
    badge: 'GELİR YÖNETİMİ',
    title: 'Gelirini buradan ekle',
    body: 'Bu rakama dokunduğunda gelir formu açılır. Ay sonunda sende ne '
        'kaldığı, gelirinden giderin çıkarılarak bulunur.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.homeTab,
    badge: 'ANA SAYFA',
    title: 'Ana Görünüm',
    body: 'Seçili dönemin özeti: ne harcadın, ne kazandın, sende ne kaldı. '
        'Finansal sağlık puanın ve birikim hedeflerin tek bakışta burada.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.addButton,
    badge: 'HIZLI İŞLEM',
    title: 'Veriyi buradan eklersin',
    body: 'Bu düğme üç yol açar: banka ekstreni aktar (CSV, XLSX, PDF), '
        'fişini kameraya okut ya da tek bir kaydı elle gir.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.transactionsTab,
    badge: 'İŞLEMLER',
    title: 'İşlem Defteri',
    body: 'Tüm harcamaların ve gelirlerin burada toplanır. Bir kayda dokunup '
        'düzenleyebilir veya silebilirsin.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.transactionFilters,
    badge: 'FİLTRE & SIRALAMA',
    title: 'Kayıtları süz ve sırala',
    body: 'Kategori çipleri ile anında süz, tarihe veya tutara göre sırala. '
        'Arama kutusundan mağaza adına göre hızlıca bulabilirsin.',
  ),
  TourSpotlightStep(
    tab: 2,
    target: TourTarget.analyticsTab,
    badge: 'FİNANSAL ANALİZ',
    title: 'Analiz & Özetler',
    body: 'Günlük harcama ritmi, nakit akışı, kategori payları, haftalık ve '
        'aylık interaktif finansal hikâyelerin burada.',
  ),
  TourSpotlightStep(
    tab: 3,
    target: TourTarget.profileTab,
    badge: 'KONTROL & AYARLAR',
    title: 'Profil & Bildirimler',
    body: 'Birikim kasaları, bütçe sınırları, gizlilik kilidi, haftalık '
        'özet bildirimleri ve veri yedekleme burada.',
  ),
];
