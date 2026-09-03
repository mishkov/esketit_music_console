# esketit_music_console

A new Flutter project.

## Sentry

Sentry error reporting, structured logs, and performance tracing are enabled by
default. The project DSN is compiled in and can be overridden or disabled with
`--dart-define=SENTRY_DSN=...`. The environment and trace sample rate can be set
with `SENTRY_ENVIRONMENT` and `SENTRY_TRACES_SAMPLE_RATE`.

To expose an intentional test-error button in Settings, run:

```bash
flutter run -d chrome \
  --dart-define=SENTRY_VERIFY_SETUP=true \
  --dart-define=SENTRY_ENVIRONMENT=development
```

Press **Verify Sentry setup** and confirm that `Sentry setup verification`
appears in the `esketit-console` Sentry project.

# How to deploy

Ensure that main.dart has right base url then run

```bash
flutter build web --release --base-href /console/ && rsync -av --delete build/web/ mishkov@46.101.162.92:/var/www/esketit_music_console/console
```
