# central-integracoes

Tela ADVPL no Protheus que conecta a categoria → provedor → credencial da
IntegrationPlatform diretamente do ERP, sem duplicar credenciais no Protheus.
Fundação reutilizável por qualquer automação futura (a primeira delas: Régua de
Cobrança Inteligente, projeto irmão).

## Estrutura

| Arquivo | Papel |
|---|---|
| `Central de Integracoes/CTIA001.tlpp` | Tela de conector: categoria → provedor → formulário de credencial montado em runtime |
| `Cadastros/ZC1A001.prw` | Cadastro MVC da ZC1 — qual conta atende cada finalidade de integração |
| `Classes/IntegrationPlatformClient.tlpp` | Cliente REST da IntegrationPlatform |
| `Dicionario/ZC1-campos.md` | Especificação da ZC1 para cadastro manual no Configurador |

## Pré-requisitos no ambiente

Dois parâmetros (SIGACFG → Ambiente → Cadastros → Parâmetros), tipo caractere:

| Parâmetro | Conteúdo |
|---|---|
| `ZZ_CTIURL` | URL base da IntegrationPlatform, sem barra final |
| `ZZ_CTIKEY` | API Key enviada no header `X-Api-Key` |

A tabela ZC1 é cadastrada manualmente conforme `Dicionario/ZC1-campos.md`, e as
rotinas `CTIA001` e `ZC1A001` são incluídas no menu do módulo desejado (tipo
Função de Usuário).
