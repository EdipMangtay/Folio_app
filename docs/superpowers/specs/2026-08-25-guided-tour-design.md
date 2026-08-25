# Guided in-app tour

**Date:** 2026-08-25
**Status:** design, approved in chat, not yet implemented

## The problem

A new install currently opens a four-slide screen that describes Folio and asks
for an income figure, then drops the user on an empty dashboard. The slides talk
about the app from outside it: nothing the user is told is attached to the thing
it describes, and the four tabs are never mentioned. People finish the slides
without knowing what İşlemler or Analiz are for.

The tour should instead walk through the running app — change tabs itself, point
at the control it is talking about, and say what that part is for.

## Decisions taken

| Question | Decision |
|---|---|
| What happens to the slide screen | Replaced entirely. There is one tour and it runs inside the app. |
| How the user advances | The tour drives. It switches tabs itself and highlights the target; the user presses **İleri**. Nothing depends on the user finding the right control. |
| Where the income step sits | **First.** Every later stop then shows the user's own figure instead of an empty screen. |

The income-first order is what makes the rest of the tour worth watching: on a
fresh install the dashboard, the transaction list and the analysis page are all
empty, so a tour that ends with income would spend five stops explaining blank
screens.

## Architecture

### Components

**`TourStep`** — a value describing one stop.

```
sealed class TourStep
  SpotlightStep(tab, target, title, body)
  FormStep(title, body)          // the income card; no target to point at
```

`tab` is the branch index the shell must be on before the step is shown.
`target` names a widget, not a key — see the registry.

**`TourTarget`** — an enum of the things the tour can point at:
`homeTab`, `transactionsTab`, `addButton`, `analyticsTab`, `profileTab`.

**`TourTargetRegistry`** — maps `TourTarget` to the `GlobalKey` of the widget
currently representing it. The dock and the tablet rail both register the same
targets; only one of them is mounted at a time, so the last registration wins and
the tour works in either shell without knowing which is on screen.

**`TourController`** (Riverpod `Notifier`) — holds `running` and the step index,
and exposes `start()`, `next()`, `skip()`. It is the only thing that decides
which step is current; the overlay only draws.

**`TourOverlay`** — a widget in `AppShell`'s `Stack`, above the tabs and the
dock. For a `SpotlightStep` it reads the target's `RenderBox` through the
registry, paints a scrim with that rect cut out, and places the bubble on
whichever side has room. For a `FormStep` it centres the income card instead.

### Why a Stack in AppShell, not an Overlay entry

`AppShell` already owns `navigationShell`, which is the thing that has to move
between tabs, and it rebuilds when the branch changes — which is exactly when the
overlay needs to re-measure. An `Overlay` entry would float above bottom sheets,
which we do not need, at the cost of manually driving its rebuilds from outside
the widget tree that changes. A third-party coach-mark package was considered and
rejected: this repo deliberately carries its own implementations (bundled fonts,
local PDF parsing, no INTERNET permission in release builds), and a package's
bubble would not match the design system without fighting it.

### Step sequence

| # | Kind | Tab | Target | Says |
|---|---|---|---|---|
| 1 | Form | — | — | Aylık gelirin — amount + source, **Kaydet** / **Şimdilik geç** |
| 2 | Spotlight | Ana | `homeTab` | Ayın özeti: harcadığın, kazandığın, sende kalan |
| 3 | Spotlight | İşlemler | `transactionsTab` | Her kayıt burada; filtrele, düzelt, sil |
| 4 | Spotlight | İşlemler | `addButton` | Elle ekle, fiş tara, ekstre aktar |
| 5 | Spotlight | Analiz | `analyticsTab` | Dönemin tüm görünümü; üstteki dönem düğmesi geçmiş ayları açar |
| 6 | Spotlight | Profil | `profileTab` | Bütçeler, abonelikler, veriyi dışa aktarma |

Step 5 names the period control on purpose: an imported statement covers a closed
month, and not knowing that is the specific thing that has already confused a
user of this app.

### Timing

A step cannot be measured until its tab has settled — `FolioTabSwitcher` animates
over `FolioMotion.tab`. Each transition therefore runs as: set the branch, wait
for that duration plus one frame, read the target rect, then show the bubble. If
the registry has no key for the target, or the key has no `RenderBox` yet, the
step renders its bubble centred with no cut-out rather than throwing — a missing
highlight is a worse tour, not a crash.

### Entry and exit

`buildAppRouter` loses its `onboardingSeen` parameter and always starts at `/`.
`FolioApp` passes the flag to the tour instead: `AppShell` starts the tour on
first build when `hasSeenOnboarding` is false. Finishing or skipping calls the
existing `completeOnboarding()`.

`OnboardingScreen` and the `/onboarding` route are deleted. The income form
inside it is extracted to `presentation/widgets/income_entry_card.dart` and used
by the tour's first step, keeping its existing validation: empty, unreadable,
zero and negative amounts are refused inline under the field, never as a snackbar
over the buttons.

Profile gains **Turu tekrar izle**, which calls `start()`. Without it the tour is
unreachable after the first run and untestable on a device without clearing app
data.

### Accessibility

- The bubble's **İleri** and **Geç** are real buttons, at least 44pt.
- Under `FolioMotion.reduce`, the scrim and bubble appear without animating.
- The overlay is a `Semantics` scope announcing the step's title and body; the
  scrim blocks taps to what is underneath so a screen reader is not led into a
  control the tour has not reached.
- The cut-out is drawn with a visible ring, not only a brightness change, so the
  highlight does not rely on contrast alone.

## Testing

Widget tests over `AppShell` with fake wallet and settings providers:

- a first run starts on the income step, and the slide screen no longer exists
- saving an amount stores one income transaction and moves to step 2
- skipping the income step stores nothing and still moves to step 2
- each spotlight step leaves the shell on the tab that step declares
- the highlighted rect matches the registered target's rect
- **İleri** through every step ends with the tour gone and `completeOnboarding` called
- **Geç** at any step ends the tour and calls `completeOnboarding`
- a step whose target is unregistered still renders its bubble
- reduced motion renders the overlay without animation wrappers
- a second launch does not start the tour; **Turu tekrar izle** does

Unit tests for the step list: every `SpotlightStep` names a target the registry
can hold, and every tab index is within the shell's branch count.

## Out of scope

- Highlighting anything inside a scrolling page (the income figure, the period
  control). Those need scroll-into-view before measuring; the tour points at the
  dock, which is always on screen. Step 5 mentions the period control in words.
- Making the user tap the real control to advance.
- Re-running the tour automatically after an update.
