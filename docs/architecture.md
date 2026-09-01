# Arquitetura

Este projeto nasce como uma base Flutter para Android e Web com backend Firebase. A prioridade da primeira etapa é estrutural: separar responsabilidades, preparar multiempresa e deixar os módulos prontos para serem implementados por fases.

## Camadas

- `lib/app`: composição da aplicação, tema, navegação e bootstrap.
- `lib/core`: utilitários compartilhados, integração Firebase e breakpoints.
- `lib/screens`: telas da aplicação em uma pasta única.
- `lib/shared`: widgets reutilizáveis e sem regra de negócio.
- `lib/features/*/domain`: entidades e regras independentes da interface.
- `lib/features/*/application`: casos de uso e lógica de negócio.
- `lib/features/*/data`: repositórios e mapeamento Firestore.

## Features iniciais

- `auth`: autenticação por Firebase Authentication e perfil do usuário.
- `inventory`: produtos, categorias, movimentações, contagens, vendas e canais.
- `pricing`: plataformas, taxas e motor determinístico de cálculo.

## Telas iniciais

Todas as telas ficam centralizadas em `lib/screens`:

- `dashboard_page.dart`: indicadores provisórios de estoque.
- `inventory_placeholder_page.dart`: telas provisórias de produtos, estoque e contagens.
- `pricing_page.dart`: tela provisória da calculadora.
- `settings_page.dart`: ponto inicial para empresa, usuários, canais e configuração.
- `login_page.dart`: tela inicial de autenticação.

## Firestore

A modelagem inicial usa subcoleções por empresa:

```text
companies/{companyId}
  members/{userId}
  products/{productId}
  categories/{categoryId}
  movements/{movementId}
  stockCounts/{stockCountId}
  sales/{saleId}
  salesChannels/{channelId}
  pricingPlatforms/{platformId}

users/{userId}
```

O documento `users/{userId}` deve conter `companyIds` e `activeCompanyId`. As regras usam `companyIds` para isolar dados entre empresas.

## Fluxo de estoque

A alteração de estoque deve passar pela camada `application`, especialmente por `InventoryService`. O serviço atualiza o saldo do produto e cria uma movimentação na mesma transação do Firestore, mantendo histórico para entrada, venda, ajuste, perda, dano, uso próprio, devolução, brinde e outros motivos.

## Precificação

`PricingCalculator` calcula preço recomendado, lucro, margem e preço mínimo com fórmulas determinísticas. Taxas ficam em `pricingPlatforms` e podem ser fixas ou percentuais sobre o preço final de venda.

## Responsividade

O shell usa menu lateral em layouts médios/desktop e drawer em telas compactas. A lógica de negócio é compartilhada entre Android e Web; o que muda é apenas a apresentação.
