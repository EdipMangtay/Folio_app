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
  });

  /// The branch index the shell must be showing before this stop makes sense.
  final int tab;
  final TourTarget target;
  final String title;
  final String body;
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
    title: 'Önce dönemi seç',
    body: 'Buradan ay değiştirirsin. Banka ekstresi çoğunlukla kapanmış bir '
        'ayı kapsar, o yüzden rakamlarını göremezsen ilk bakacağın yer burası.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.incomeMetric,
    title: 'Gelirini buradan ekle',
    body: 'Bu rakama dokunduğunda gelir formu açılır. Ay sonunda sende ne '
        'kaldığı, gelirinden giderin çıkarılarak bulunur.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.homeTab,
    title: 'Ana',
    body: 'Seçili dönemin özeti: ne harcadın, ne kazandın, sende ne kaldı. '
        'Altında günlük harcama grafiğin ve kategori dağılımın var.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.addButton,
    title: 'Veriyi buradan eklersin',
    body: 'Bu düğme üç yol açar: banka ekstreni aktar (CSV, XLSX, PDF), '
        'fişini kameraya okut, ya da tek bir kaydı elle gir.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.transactionsTab,
    title: 'İşlemler',
    body: 'Her kayıt burada toplanır. Bir kayda dokunup düzeltebilir ya da '
        'silebilirsin.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.transactionFilters,
    title: 'Kayıtları süz',
    body: 'Bu hafta, bu ay, sadece gider ya da sadece gelir. Üstteki arama '
        'kutusundan mağaza ve kategoriye göre de arayabilirsin.',
  ),
  TourSpotlightStep(
    tab: 2,
    target: TourTarget.analyticsTab,
    title: 'Analiz',
    body: 'Dönemin tüm görünümü: günlük harcama, nakit akışı, kategori '
        'dağılımı ve en çok harcadığın yerler.',
  ),
  TourSpotlightStep(
    tab: 3,
    target: TourTarget.profileTab,
    title: 'Profil',
    body: 'Bütçe sınırları, tekrarlayan abonelikler, verini dışa aktarma ve '
        'turu tekrar izleme burada.',
  ),
];
