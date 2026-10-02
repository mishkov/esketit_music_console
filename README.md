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

## AI agent / MCP settings

Administrators with `access_control.manage` can open **Settings → AI Agent / MCP**
to select the user connected agents act as and edit workflow/upload guidance.
Selecting **Disabled — no acting user** stops agent operations. Saves use the
settings version to prevent overwriting another administrator's changes; on a
conflict, the editor preserves the draft until you reload and review it.

This screen requires the server's `GET/PATCH /api/mcp/settings` endpoints.
The dedicated MCP connection credential is configured on the server and is
never returned to the console. The screen reports whether it is configured.
Permissions, upload limits, and review lifecycle rules remain server-enforced.
