# Help Mobile

Aplicativo Flutter do marketplace Help, organizado por features e camadas `domain`, `data` e `presentation`.

## Recursos atuais

- Login com e-mail/senha e Google pelo Firebase Auth.
- Recuperação de senha via API Go e MailerSend.
- Apple visível e desabilitado como “Em breve”.
- Home dinâmica por uma única chamada a `GET /v1/home`.
- Cache em memória, skeleton, retry e fallback de imagens.
- Design System compartilhado e golden test visual.
- App icon gerado para Android e iOS a partir de `assets/icons/app_icon.png`.

## API local

No emulador Android, a URL padrão é `http://10.0.2.2:8080`. Para outro ambiente:

```powershell
flutter run --dart-define=API_BASE_URL=https://api.vendlydigital.com.br
```

Em release, `API_BASE_URL` é obrigatória e deve usar HTTPS. A assinatura de
produção deve ser configurada em `android/key.properties`, usando
`android/key.properties.example` como referência. Sem isso, a build não usa a
chave insegura de debug.

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.seudominio.com
```

## Validar

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Novas regras seguem TDD: teste vermelho, implementação mínima, suíte verde e refatoração.
