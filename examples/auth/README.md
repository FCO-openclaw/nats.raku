# Testes de Autenticação NATS

Este diretório contém scripts para testar os diferentes métodos de autenticação implementados no nats.raku.

## Ambiente de Teste

O ambiente de teste usa Docker Compose para criar:

1. Três servidores NATS:
   - `nats-token`: Configurado com autenticação por token (`--auth=test_token_123`)
   - `nats-basic`: Configurado com autenticação básica de usuário/senha (`--user admin --pass password123`)
   - `nats-jwt`: Configurado via arquivo de configuração que implementa autenticação por token (preparação para JWT completo)

2. Um container Raku:
   - Com o código do nats.raku montado
   - Pronto para executar os testes contra os servidores NATS

## Testes Implementados

- `test-token-auth.raku`: Testa a autenticação por token simples
- `test-basic-auth.raku`: Testa a autenticação por usuário/senha
- `test-jwt-token.raku`: Testa a configuração de JWT (implementação simples)
- `test-jetstream-pull-auth.raku`: Testa o JetStream Pull Consumer com autenticação

## Como Executar

```bash
# Navegue até o diretório de teste
cd /path/to/nats.raku/test-auth

# Execute todos os testes
./run-tests.sh
```

O script `run-tests.sh` automaticamente:
1. Inicia o ambiente Docker Compose
2. Executa todos os testes
3. Exibe os resultados
4. Desliga o ambiente Docker Compose

## Observações Sobre JWT

A implementação JWT completa requer:
1. Geração de chaves ED25519 para o servidor e clientes
2. Configuração do sistema de contas NATS
3. Assinatura de nonces com libsodium ou similar

No momento, estamos testando apenas a parte mais básica da infraestrutura JWT (usando tokens simples),
pois a implementação completa da assinatura ED25519 em Raku requer mais desenvolvimento.