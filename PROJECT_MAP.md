# Folio Project Map

| Alan | Dosya |
|---|---|
| Entry | `lib/main.dart` |
| App / Theme mode | `lib/app.dart` |
| Router | `lib/core/router/app_router.dart` |
| Colors | `lib/core/theme/app_colors.dart` |
| Typography | `lib/core/theme/app_typography.dart` |
| Theme | `lib/core/theme/app_theme.dart` |
| SQLite | `lib/data/database/app_database.dart` |
| Repository | `lib/data/repositories/wallet_repository.dart` |
| Receipt OCR | `lib/data/services/receipt_analyzer.dart` |
| Statement parser | `lib/data/services/statement_parser.dart` |
| Analytics engine | `lib/domain/analytics/analytics_engine.dart` |
| App state | `lib/state/wallet_controller.dart` |
| Preferences | `lib/state/settings_controller.dart` |
| Dashboard | `lib/presentation/dashboard/dashboard_screen.dart` |
| Add expense | `lib/presentation/add/add_transaction_sheet.dart` |
| Transactions | `lib/presentation/transactions/transactions_screen.dart` |
| Transaction detail | `lib/presentation/transactions/transaction_detail_screen.dart` |
| Receipt flow | `lib/presentation/import/receipt_scan_screen.dart` |
| Statement flow | `lib/presentation/import/statement_import_screen.dart` |
| Analytics | `lib/presentation/analytics/analytics_screen.dart` |
| Budgets | `lib/presentation/budgets/budgets_screen.dart` |
| Subscriptions | `lib/presentation/subscriptions/subscriptions_screen.dart` |
| Monthly story | `lib/presentation/report/monthly_report_screen.dart` |
| Profile/settings | `lib/presentation/profile/profile_screen.dart` |
| Shell/navigation | `lib/presentation/shell/app_shell.dart` |
| Signature Money Pulse | `lib/presentation/widgets/money_pulse.dart` |
| Bootstrap native shells | `tool/bootstrap.sh` |
| Native patch | `tool/patch_platforms.py` |
| Release verification | `tool/verify.sh` |

## Tests

- `test/analytics_engine_test.dart`
- `test/merchant_normalizer_test.dart`
- `test/receipt_parser_test.dart`
- `test/statement_parser_test.dart`

## V3 shared visual primitives

- `lib/presentation/widgets/folio_background.dart` — restrained ambient screen background
- `lib/presentation/widgets/premium_surface.dart` — canvas/surface/elevated primitive
- `lib/presentation/widgets/money_pulse.dart` — Folio signature balance visual
- `lib/presentation/widgets/spending_chart.dart` — premium touch-aware spending rhythm chart

## V6 signature additions
- `lib/presentation/widgets/spending_composition_chart.dart` — custom segmented category composition chart.
- Dashboard, Analytics, Transactions, Budgets, Subscriptions, Statement Import, Receipt Review and Profile were visually reworked under the V6 warm signature system.
