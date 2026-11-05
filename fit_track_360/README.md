# fit_track_360

La URL del API no va hardcodeada en el código. El contrato de config local está en `env/example.json`: `apiBaseUrl` es `http://10.0.2.2:3000` (emulador Android hacia el host). `API_BASE_URL` repite ese valor porque el cliente HTTP actual lee ese define.

En el simulador de iOS usa `http://127.0.0.1:3000` en una copia local, no en el example versionado.

```bash
flutter run --dart-define-from-file=env/example.json
```

Para otra URL, copia el example a `env/local.json` (no se versiona) y pásalo con `--dart-define-from-file=env/local.json`. Sin API keys; HTTPS queda para cuando el API esté en la nube.
