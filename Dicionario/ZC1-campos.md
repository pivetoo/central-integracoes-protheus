# ZC1 — Referência de Conector por Finalidade

Referência para cadastro **manual** da tabela ZC1 via Configurador
(SIGACFG → Base de Dados → Dicionário de Dados). Sem compatibilizador — a
tabela é criada na mão neste e em cada ambiente de destino, seguindo a
especificação abaixo.

ZC1 não guarda credencial de provedor — apenas a referência (id + nome de
exibição) do conector da IntegrationPlatform associado a cada finalidade de
integração (ex: `cobranca-whatsapp` → conector Twilio).

## SX2 — Cadastro da tabela

| Campo | Valor |
|---|---|
| Chave (X2_CHAVE) | `ZC1` |
| Nome (X2_NOME) | Referência de Conector por Finalidade |
| Modo (X2_MODO) | C (Compartilhado) |

## SX3 — Campos

| Campo | Tipo | Tam. | Dec. | Título | Descrição | Obrigat. | Browse | Picture/Válido | Combo |
|---|---|---|---|---|---|---|---|---|---|
| ZC1_FILIAL | C | 8 | - | Filial | Filial do sistema (preenchida automaticamente) | N | N | - | - |
| ZC1_CODIGO | C | 15 | - | Código | Código da finalidade de integração (ex: `cobranca-whatsapp`) | S | S | Válido: `NaoVazio()` | - |
| ZC1_DESC | C | 60 | - | Descrição | Descrição da finalidade de integração | S | S | Válido: `NaoVazio()` | - |
| ZC1_CATEG | C | 30 | - | Categoria | Identificador da categoria na IntegrationPlatform (ex: `whatsapp`) | S | S | Válido: `NaoVazio()` | - |
| ZC1_CONECT | N | 15 | 0 | Cod Conector | Id do conector selecionado na IntegrationPlatform | S | N | Picture: `999999999999999`, Válido: `NaoVazio()` | - |
| ZC1_CONNM | C | 60 | - | Nom Conector | Nome do conector (cache de exibição, evita chamada à API) | N | N | - | - |
| ZC1_ATIVO | C | 1 | - | Ativo | Indica se a finalidade está ativa | N | S | Picture: `@!`, Válido: `Pertence('SN')` | `S=Sim;N=Nao` |

Atenção ao cadastrar: **ZC1_CODIGO e ZC1_CATEG não levam picture `@!`**
(que forçaria maiúsculas) — ambos precisam bater exatamente com
identificadores externos em minúsculas/kebab-case (`cobranca-whatsapp`,
`whatsapp`) vindos do usuário ou da API da IntegrationPlatform.

Nenhum campo usa gatilho SX7 ou lookup F3 — ZC1_CONECT referencia um id da
API externa IntegrationPlatform, resolvido em tela via REST, não via
F3/DBEdit de tabela do Protheus.

## SIX — Índice

| Ordem | Chave | Descrição |
|---|---|---|
| 01 | `ZC1_FILIAL+ZC1_CODIGO` | Filial + Código (chave primária de busca) |

É a chave que o Model usa em `ObjectFromMetadata("ZC1",, {"ZC1_FILIAL", "ZC1_CODIGO"})`.

## Ao preencher o primeiro registro

`ZC1_CONECT` é obrigatório e a busca automática de conector ainda é um stub
(`buscaConector` devolve JSON vazio), então digite o id manualmente — ele
aparece na Central de Integrações após gravar a conta. `ZC1_CONNM` é
somente-leitura pelo Model e será preenchido quando a busca existir.
