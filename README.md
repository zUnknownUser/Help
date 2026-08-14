# Help

Monorepo do marketplace de serviços Help.

```text
apps/
  mobile/       Aplicativo Flutter
services/
  api/          BFF Go, PostgreSQL e migrations
```

## Desenvolvimento

```powershell
cd services/api
.\scripts\db-up.ps1
.\scripts\smoke-test.ps1

cd ../../apps/mobile
flutter pub get
flutter test
flutter run
```

Para instalar em um Android físico na mesma rede da máquina, informe o IP local
que expõe a API:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:8080
```

Segredos do Firebase Admin, MailerSend e PostgreSQL nunca devem ser incluídos no Flutter ou versionados.
