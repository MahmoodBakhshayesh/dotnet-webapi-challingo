# Wiring Checklist (MBKH)

Feature: `<feature_name>`

## 1. Routes

`lib/core/navigation/app_route_names.dart`

```dart
static const <featureName> = '<feature_name>';
```

`lib/core/navigation/router_provider.dart`

```dart
GoRoute(
  path: '/${AppRouteNames.<featureName>}',
  name: AppRouteNames.<featureName>,
  builder: (context, state) => const <Feature>View(),
),
```

## 2. DI (`lib/features/<feature_name>/<feature_name>_di.dart`)

```dart
void register<Feature>Dependencies(GetIt locator) {
  registerFeatureStack<<Feature>DataSourceLocal, <Feature>DataSourceRemote, <Feature>Repository>(
    locator: locator,
    name: '<Feature>DataSource',
    createLocal: (l) => <Feature>DataSourceLocal(l()),
    createRemote: (l) => <Feature>DataSourceRemote(l()),
    createRepository: <Feature>Repository.builder,
  );

  locator.registerLazySingleton(() => MyUsecase(locator()));
}
```

Wire the registrar in `lib/core/di/app_features_di.dart` (manual features) or
`lib/core/di/generated_features_di.dart` (`mbkh_feat` output).

## 3. Localization

Add ARB keys to `lib/l10n/app_en.arb` and `lib/l10n/app_fa.arb` for all user-visible strings.

## 4. API path

Update `<feature>_data_source_remote.dart` with the real endpoint and HTTP verb.
