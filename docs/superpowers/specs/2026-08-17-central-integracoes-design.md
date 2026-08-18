# Central de Integrações — Spec de Design

## Contexto

Já existe, fora do Protheus, uma plataforma própria de orquestração de integrações — a
**IntegrationPlatform** (`system/integration-platform/IntegrationPlatform`, backend
.NET/Archon + frontend React), consumida hoje pelo `AgencyCampaign`. Ela resolve
categoria → integração → conector → credencial → pipeline (HTTP/JS/SQL) de forma
genérica, com WhatsApp, e-mail, contas a receber/pagar e assinatura digital já
catalogados (25 provedores reais em produção: Twilio/Z-API/Evolution/360Dialog/
WhatsApp Cloud, Mailgun/Sendgrid/Brevo/Postmark/Resend/SMTP, Banco do Brasil/Itaú/
Santander/Inter/Sicredi/Asaas, D4Sign/ZapSign).

Este projeto **não reinventa esse motor** — ele conecta o Protheus a ele. É a Fase 1 de
um roadmap maior (o irmão é a Régua de Cobrança Inteligente, projeto separado, fora de
escopo aqui): tela no Protheus que replica a experiência de categoria → provedor →
credencial da IntegrationPlatform, pra quem só trabalha no Protheus não precisar abrir
outro sistema. Fundação reutilizável por qualquer automação futura, não só a régua de
cobrança.

### Por que não é a IntegrationPlatform de novo, dentro do Protheus

O Protheus **não guarda credencial de provedor**. A Central de Integrações é só a
interface de digitação — o `POST` vai direto pra IntegrationPlatform, que continua
sendo o único lugar onde a credencial de fato mora. O único segredo que o Protheus
guarda é a própria API Key da IntegrationPlatform (uma por cliente/ambiente, via
`X-Api-Key`), não uma por provedor.

## Escopo desta entrega

Dentro:
- Tela dinâmica de conector (categoria → provedor → credencial → salvar/editar).
- Dicionário de dados ZC1 (referência de conector por finalidade) + tela de manutenção
  simples (Smart X, campos fixos).
- Cliente REST reutilizável para a API da IntegrationPlatform.

Fora (fica pra depois, como projetos/fases separadas):
- Régua de Cobrança Inteligente (ZB1/ZB2, ponto de entrada de baixa, motor de disparo).
- Testes automatizados ProBat.
- Inclusão automática de opção de menu em tabela viva (entrega é a `User Function`;
  quem inclui no Configurador é o time do ambiente de destino).

## Decisão de arquitetura: tela clássica ADVPL, não Smart X (para o formulário de conector)

Investigado e descartado: o Smart X não suporta campo definido em tempo de execução.
Confirmado na documentação oficial da TOTVS (TDN, página "Mudança de Comportamento
Smart X"): `AddOtherObject` (injeção de componente customizado) está marcado
explicitamente como **Não Disponível** no Smart X — "não é possível injetar objetos
legados ou customizados arbitrários no frontend PO-UI via backend". A arquitetura é
stateless/contrato-JSON gerado no backend, sem essa porta de escape.

Decisão: **tela clássica ADVPL** (`MsDialog`/`TGet`/`TCombobox`/`TCheckBox`/`GetFile`),
montada dinamicamente em loop a partir da resposta da API — técnica antiga mas
comprovada, e a única que suporta tipo de campo genuinamente variável em runtime.

A tela de manutenção da ZC1, ao contrário, tem campos fixos (não varia por provedor) —
mesma categoria de problema que a política de cobrança (ZB1) do projeto irmão, então
**Smart X normal** se aplica sem ressalvas.

## Estrutura do projeto

```
central-integracoes/
  Classes/
    IntegrationPlatformClient.tlpp  → classe TLPP, cliente REST único da API
  Central de Integracoes/
    CTIA001.tlpp                    → tela dinâmica (categoria→provedor→credencial→salvar)
  Cadastros/
    ZC1A001.model.tlpp              → Smart X — model
    ZC1A001.interface.tlpp          → Smart X — interface
    ZC1A001.tlpp                    → Smart X — launcher (User Function ZC1A001)
  Dicionario/
    ZC1-campos.md                   → referência de campos p/ cadastro manual via Configurador
  docs/superpowers/specs/           → specs de design (este arquivo)
  README.md
```

Repositório git próprio (mesmo padrão do projeto irmão `integ_santander_lanchero`),
remoto: `https://github.com/pivetoo/central-integracoes-protheus`.

## Cliente REST — `IntegrationPlatformClient`

Classe TLPP única, reaproveitada pelas duas telas (formulário de conector e manutenção
ZC1). Um método por operação necessária:

| Método | Endpoint |
|---|---|
| `GetActiveCategories()` | `GET /api/integrationcategories/active` |
| `GetIntegrationsByCategory(nCategoryId)` | `GET /api/integrations/category/{categoryId}` |
| `GetAttributesByIntegration(nIntegrationId)` | `GET /api/integrationattributes/integration/{integrationId}` |
| `GetActiveConnectors()` | `GET /api/connectors/active` |
| `CreateConnector(oData)` | `POST /api/connectors` |
| `UpdateConnector(nId, oData)` | `PUT /api/connectors/{id}` |
| `SaveConnectorAttributeValue(oData)` | `POST /api/connectorattributevalues` |
| `GetConnectorAttributeValuesByConnector(nConnectorId)` | `GET /api/connectorattributevalues/connector/{connectorId}` |

Todos os 8 endpoints acima foram conferidos linha a linha contra o código-fonte atual
da IntegrationPlatform (`ConnectorsController.cs`, `IntegrationAttributesController.cs`,
`IntegrationCategoriesController.cs`, `IntegrationsController.cs`,
`ConnectorAttributeValuesController.cs`) em 2026-08-17 — rotas e verbos batem 1:1.

### Autenticação

Header simples: `X-Api-Key: <chave>` (confirmado em
`Archon.Api.Attributes.RequireAccessAttribute` — a API resolve o tenant só pela chave,
sem Basic Auth com tenant). Guardada via dois parâmetros novos, por filial, nunca
hardcoded:

| Parâmetro | Descrição |
|---|---|
| `ZZ_CTIURL` | URL base da IntegrationPlatform (ex: `https://api.integrationplatform.exemplo.com/`) |
| `ZZ_CTIKEY` | API Key (`X-Api-Key`) do ambiente/cliente |

### Tratamento de erro

Respostas 400/401/404 da API sobem como mensagem legível via `MsgAlert()` com o texto
retornado pela API (os controllers já retornam mensagens localizadas via
`IStringLocalizer`). Sem retry automático — é preenchimento manual de formulário, não
um job em background.

## Tela Central de Integrações (`CTIA001`)

Implementada em dois diálogos, decisão tomada na implementação: o diálogo 1 só tem
widgets fixos, então usa sintaxe de tempo de compilação (`@ ... COMBOBOX`), que é o
caminho batido e de baixo risco; **só o formulário de credencial é montado
dinamicamente**, reduzindo a superfície da parte arriscada.

Diálogo 1 — seleção:

1. Combo de categoria, populado via `GetActiveCategories()`.
2. Ao escolher categoria, combo de provedor recarrega via
   `GetIntegrationsByCategory(nCategoryId)`.
3. Ao escolher provedor, combo de conector recarrega via
   `GetConnectorsByIntegration(nIntegrationId)`, com `<Novo conector>` na primeira
   posição — escolher um conector existente é o que liga o modo de edição.
4. Nome do conector (`TGet`), preenchido automaticamente ao escolher um existente.

Diálogo 2 — credencial (dinâmico):

5. `GetAttributesByIntegration(nIntegrationId)` e um widget por atributo, conforme o
   `FieldType`. Atributos com `isHidden` não entram. Na edição, os valores vêm
   pré-carregados de `GetConnectorAttributeValuesByConnector()`.
6. Salvar: `CreateConnector()` (ou `UpdateConnector()` na edição) e, pra cada atributo
   preenchido, `SaveConnectorAttributeValue()` — tudo string, igual ao frontend React.
   Atributo vazio não é enviado, porque a API rejeita `Value` em branco.

Dois detalhes de implementação que não são óbvios e custam caro se esquecidos:

- Os campos são criados **dentro do `bInit`** do diálogo. `TGet` instanciado antes da
  janela existir em memória não renderiza.
- Cada bloco `bSetGet` é produzido por uma função auxiliar (`ValueBlock(aValues, nIdx)`),
  não inline no laço. Codeblock em ADVPL captura o *local* por referência de
  armazenamento — inline, todos os campos acabariam apontando para o índice da última
  iteração. Cada chamada da auxiliar cria um armazenamento próprio.

### Mapeamento de tipo de campo (`FieldType`, confirmado em
`IntegrationPlatform.Domain.ValueObjects.FieldType` — Text=1, LongText=2, Number=3,
Decimal=4, Boolean=5, Date=6, DateTime=7, List=8, File=9)

| FieldType (enum) | Widget ADVPL |
|---|---|
| `Text` (1) | `TGet` texto |
| `LongText` (2) | `TGet` texto (largo) |
| `Number` (3) | `TGet` numérico |
| `Decimal` (4) | `TGet` numérico com casas decimais |
| `Boolean` (5) | `TCheckBox` |
| `Date` (6) | `TGet` com picture de data |
| `DateTime` (7) | `TGet` texto |
| `List` (8) | `TGet` texto (mesma simplificação que o frontend React já usa — lista separada por vírgula) |
| `File` (9) | botão que abre `cGetFile()`, converte pra base64 antes do POST |

`LongText` ficou em `TGet` largo em vez de `TMultiGet`: com o compilador indisponível
pra validar, preferi restringir a superfície aos widgets clássicos de assinatura
conhecida. Trocar por `TMultiGet` depois é local, mexe só em `BuildOne()`.

Campo sensível (`isSensitive`) → `TGet` com `lPassword`. Valor é convertido pra string
na gravação conforme o tipo (`true`/`false` para lógico, ISO `YYYY-MM-DD` para data,
base64 do conteúdo para arquivo).

### Formulário de altura variável

O número de atributos varia bastante por provedor (de poucos campos a mais de uma
dezena). Os campos ficam sempre dentro de um `TScrollBox`, cuja altura é calculada pelo
número de campos com um teto fixo (`FORM_MAXH`) — passado o teto, rola. Evita diálogo
gigante ou campos cortados fora da tela.

## ZC1 — Referência de Conector por Finalidade

O Protheus só referencia o conector, não duplica a credencial — usado pelas automações
futuras (ex: Régua de Cobrança sabe qual conector WhatsApp usar pela finalidade
`"cobranca-whatsapp"`).

| Campo | Descrição |
|---|---|
| ZC1_FILIAL | Filial |
| ZC1_CODIGO | Código da finalidade (ex: "cobranca-whatsapp") |
| ZC1_DESC | Descrição |
| ZC1_CATEG | Identificador da categoria na IntegrationPlatform (ex: "whatsapp") |
| ZC1_CONECT | Id do conector escolhido (retornado pela IntegrationPlatform) |
| ZC1_CONNM | Nome do conector (cache pra exibição, evita round-trip) |
| ZC1_ATIVO | Ativo (S/N) |

> A Central de Integrações em si não precisa de tabela própria pra listar
> categorias/provedores/conectores — isso é sempre consultado ao vivo na
> IntegrationPlatform, que é a fonte da verdade. ZC1 existe só pro Protheus saber
> "qual conector usar pra qual finalidade".

### Tela de manutenção ZC1 (`ZC1A001`)

Smart X simples (browse + cadastro): campos fixos, sem a limitação de runtime que
descartou o Smart X na tela principal. Namespace `custom.cti.zc1a001`, seguindo o
padrão oficial de Model/Interface genéricos (referência: exemplo `FINA050SM` da
documentação TOTVS). `ZC1_CONNM` é somente-leitura no Model — preenchido via gatilho
`onChange` de `ZC1_CATEG`, que chama uma função-ponte (`custom.cti.zc1a001.buscaConector`)
hoje com stub, documentada como ponto de extensão para quando a função `U_CTIBUSCACON`
(busca real de conectores via `GetActiveConnectors()`) existir.

## Integração ao menu

**Módulo: Configurador (SIGACFG)**, decidido em 17/08/2026. A Central é configuração de
ambiente, transversal — a régua de cobrança vai consumi-la, mas qualquer automação
futura também; prendê-la a SIGAFIN amarraria uma fundação genérica a um módulo. E como
a tela digita token/senha de provedor, o acesso restrito do Configurador é desejável.

Estrutura sugerida, com as duas rotinas na mesma pasta:

```
Configurador
└── Central de Integrações
    ├── Conectores                 → U_CTIA001
    └── Referência por Finalidade  → U_ZC1A001
```

Cadastro em Configurador → Ambiente → Cadastros → Menu, manual no ambiente de destino —
não altero tabela de menu ativa como parte deste projeto.

**Rodar pelo menu não é conveniência, é requisito.** Execução direta pelo SmartClient
(`-P=U_CTIA001`) pula o login e não monta empresa/filial; a primeira leitura de
parâmetro quebra com `variable does not exist CFILANT` dentro do `SuperGetMV`. Passar a
filial explicitamente no 4º argumento **não** resolve — foi testado, o `SuperGetMV`
consulta `cFilAnt` de qualquer forma. O login do módulo é o que prepara o ambiente.

### Nome e namespace do ponto de entrada

`CTIA001.tlpp` **não declara `namespace`**, de propósito: `User Function` dentro de
namespace não se registra como `U_NOME` global e o SmartClient não consegue chamá-la
(sintoma: `INVALID FUNCTION CALL`, mesmo com o fonte presente no RPO — confirmado no
Inspetor de Objetos). O launcher oficial da TOTVS (`FINA050SM`) também não declara
namespace, pelo mesmo motivo.

Consequência: sem namespace valem os limites clássicos do ADVPL — 8 caracteres para
`User Function` (daí `CTIA001`, e não `CENTINTEG`, que tem 9) e 10 para
`Static Function`. A classe `IntegrationPlatformClient` mantém seu namespace
normalmente e é referenciada pelo nome qualificado completo.

## Testes

Fora de escopo automação ProBat nesta fase (fica pro roadmap original, fase 5). Teste
manual: exercitar o fluxo completo (categoria → provedor → formulário → salvar → editar)
contra uma instância real da IntegrationPlatform, cobrindo pelo menos um provedor de
cada `FieldType` presente no catálogo atual (ex: WhatsApp Cloud tem token — sensível;
SMTP tem porta — numérico; assinatura digital tem certificado — arquivo).

### Pontos que a primeira compilação precisa validar

Nada aqui passou pelo compilador ainda. Dois trechos foram escritos a partir de
documentação, não de verificação direta, e estão marcados com `TODO` no fonte:

- `IntegrationPlatformClient:DoRequest()` — se o retorno lógico de
  `FWRest:Get/Post/Put` já distingue 2xx de 4xx/5xx, e se `cResult` é mesmo a
  propriedade do corpo da resposta nesta build.
- `CTIA001:BuildOne()` — posição de `lPixel` nos construtores de `TCheckBox` e
  `TButton`, e a propriedade `oGet:lPassword`. `TGet` (com `lPixel` na posição 14),
  `TSay` e `TScrollBox` seguem assinatura conferida na documentação.
