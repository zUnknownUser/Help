# Help API

API BFF em Go para o aplicativo Help. Ela concentra integrações privadas, autenticação administrativa e a composição otimizada da Home.

## Subir o ambiente local

Os segredos ficam em `.env.local`, ignorado pelo Git. Depois execute:

```powershell
.\scripts\db-up.ps1
.\scripts\smoke-test.ps1
```

O ambiente Docker contém:

- PostgreSQL 17 com volume persistente.
- Serviço de migrations idempotente.
- API Go em `http://localhost:8080`.

Conexão PostgreSQL local:

```text
Host: localhost
Porta: 5432
Banco: help
Usuário: help
Senha: help_local_only
SSL: disable
```

Esses dados são exclusivos para desenvolvimento local. Produção deve usar credenciais armazenadas em um gerenciador de segredos.

## Endpoints

- `GET /health`
- `GET /ready` (inclui conectividade com PostgreSQL)
- `GET /v1/home`
- `POST /v1/auth/password-reset`

`GET /v1/home` entrega todas as áreas necessárias para renderizar a tela em uma única chamada. Consulte [docs/home.md](docs/home.md).

## Testes

```powershell
.\scripts\test.ps1
.\scripts\smoke-test.ps1
```

O smoke test valida PostgreSQL, migration, composição da Home, Firebase Admin e o contrato HTTP.

O contêiner da API usa Go `1.26.6` e possui healthcheck próprio. O pool pode ser
ajustado com `DB_MIN_CONNECTIONS` e `DB_MAX_CONNECTIONS`. Mantenha
`TRUST_PROXY_HEADERS=false`; habilite somente quando a API estiver protegida por
um proxy reverso confiável.
