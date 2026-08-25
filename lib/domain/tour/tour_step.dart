/// Something the tour can point at.
///
/// Named rather than keyed so the phone dock and the tablet rail can offer the
/// same targets without the tour knowing which shell is on screen.
enum TourTarget { homeTab, transactionsTab, addButton, analyticsTab, profileTab }

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
    target: TourTarget.homeTab,
    title: 'Ana',
    body: 'Seçili dönemin özeti: ne harcadın, ne kazandın, sende ne kaldı.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.transactionsTab,
    title: 'İşlemler',
    body: 'Her kayıt burada. Filtreleyebilir, düzeltebilir, silebilirsin.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.addButton,
    title: 'Ekle',
    body: 'Elle gelir ya da gider ekle, fiş tara, banka ekstreni aktar.',
  ),
  TourSpotlightStep(
    tab: 2,
    target: TourTarget.analyticsTab,
    title: 'Analiz',
    body: 'Dönemin tüm görünümü. Üstteki dönem düğmesi geçmiş ayları açar — '
        'ekstre çoğunlukla kapanmış bir dönemi kapsar, oraya oradan geçersin.',
  ),
  TourSpotlightStep(
    tab: 3,
    target: TourTarget.profileTab,
    title: 'Profil',
    body: 'Bütçeler, abonelikler ve verini dışa aktarma burada.',
  ),
];
