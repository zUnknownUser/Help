# Contrato agregado da Home

## Objetivo

`GET /v1/home` funciona como endpoint BFF: o aplicativo faz uma única chamada e recebe localização, busca, promoções, categorias, recomendações e benefícios.

```text
Flutter -> GET /v1/home -> Home use case
                            |-- categories
                            |-- catalog
                            |-- promotions
                            |-- providers
                            `-- home frame
```

Os módulos permanecem independentes e são unidos apenas pelo caso de uso `GetHome`. Isso permite criar endpoints específicos no futuro sem acoplar o Flutter às tabelas do banco.

## Performance

- As consultas independentes ao PostgreSQL executam em paralelo.
- O pool começa com 2 conexões e aceita até 10 por instância.
- Categorias, serviços e promoções possuem índices parciais para os registros ativos.
- Promoções, features e ações são carregadas em uma única consulta com agregação JSON.
- O agregado final possui cache de 30 segundos com `singleflight`, evitando consultas duplicadas sob concorrência.
- O cancelamento de um cliente não cancela a carga compartilhada pelos demais; a consulta agregada possui timeout próprio.
- Features, ações e benefícios têm limites no SQL para manter o payload previsível.
- O Flutter mantém o último conteúdo válido em memória e o usa quando a rede falha.
- Imagens remotas possuem fallback local e são decodificadas no tamanho exibido, reduzindo uso de memória.

## Evolução

Novas seções devem entrar como módulos independentes e ser adicionadas ao agregador. Alterações incompatíveis exigem uma nova versão do endpoint, preservando `/v1/home` para builds já publicados.
