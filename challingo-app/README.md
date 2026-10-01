# challingo

Generated with the `mbkh_app` Mason brick.

**New to this codebase? Start with [`ARCHITECTURE.md`](ARCHITECTURE.md)** — layered flow, request lifecycle, DI, and tooling diagrams.

- API origin: `https:&#x2F;&#x2F;example.com` → REST base `https:&#x2F;&#x2F;example.com/api/`
- Primary color: `#27756a` → `AppColors.primaryColor` and `AppColors.actions`

## Included

- MBKH feature-first folder structure
- Core/helpers/interfaces/controllers/widgets baseline files
- Core navigation scaffold
- Per-feature DI (`login_di.dart`, `profile_di.dart`) + aggregators
- `.cursor/rules` starter rules
- Seeded features: login, home, profile
- `unified_fields` v1 integration with `challingo_field_decoration.dart`
- fa-first localization with `FailureLocalizer`

## Next steps

1. Run `flutter create .` in this folder (if platforms are not yet present).
2. Run `flutter pub get`.
3. Run the app.
4. Use the `mbkh_feat` brick for new features and `mbkh_usecase` for new usecases — both auto-wire routes/DI via post_gen hooks (see `WIRING_REQUIRED.md` for the manual fallback).
