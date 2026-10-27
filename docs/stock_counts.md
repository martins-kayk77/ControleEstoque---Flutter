# Contagens semanais

A rota `/counts` utiliza o tema e os componentes compartilhados do Prumo.

## Fluxo

1. Selecionar os produtos ativos e iniciar a conferência.
2. Informar as quantidades físicas; um campo vazio permanece pendente e zero
   significa que o produto foi conferido e não foi encontrado.
3. Usar **Salvar progresso** para guardar o preenchimento e recolher a contagem
   em um resumo compacto com código, progresso, data e responsável. Ao voltar à
   tela, contagens em andamento também aparecem recolhidas. Clicar no resumo ou
   em **Continuar contagem** reabre os campos salvos; novas contagens já abrem
   para preenchimento. Se o salvamento falhar, o formulário permanece aberto.
4. Confirmar para gerar um relatório, sem alterar o estoque.
5. Ao abrir **Ver relatório**, revisar e, se desejar, usar **Ajustar estoque**
   no rodapé da janela. Confirmar a intenção e depois informar a senha de acesso.
   O sistema valida a senha pelo Firebase Authentication antes de aplicar as
   diferenças, como na exclusão de produtos. Cancelamento ou senha incorreta não
   alteram saldos nem geram movimentações. Erros mantêm a janela aberta para revisão.

A rotina semanal é indicada pela última conclusão, sem bloquear conferências
extras. Uma empresa mantém uma contagem em andamento por vez. Cada contagem
suporta até 200 produtos para manter os ajustes dos produtos e movimentações em
uma única transação; catálogos maiores podem ser conferidos em grupos. Para
ajustar um grupo, revise seu relatório antes de iniciar a próxima contagem.

## Persistência e consistência

Contagens novas recebem uma numeração sequencial por empresa (`CT-0001`,
`CT-0002`, ...). O campo `number` é reservado na mesma transação de criação,
usando `lastStockCountNumber` na empresa. Salvar progresso ou concluir não muda
o código; cancelar não reutiliza o número. As regras locais verificam o incremento
e impedem edição posterior do número. Registros antigos sem `number` continuam
identificados por data, sem migração automática ou alteração dos dados históricos.

O código aparece no histórico, busca, comparação, contagem aberta e título do
relatório. Ajustes guardam `stockCountId` e `stockCountNumber`; a referência
`Contagem CT-0001` abre o relatório pela identificação interna, independentemente
do texto exibido. Os estornos preservam esse vínculo. Referências e observações
manuais não são convertidas em referências de contagem.

Os documentos ficam no caminho existente `companies/{companyId}/stockCounts`.
Cada item preserva ID, nome, unidade, custo, quantidade esperada, quantidade
contada, observação e data de atualização do produto no início da conferência.
Rascunhos possuem revisão para detectar salvamentos concorrentes.

A conclusão lê novamente todos os produtos antes de escrever. Se um saldo ou
cadastro mudou desde o início, a conferência é bloqueada sem ajuste parcial.
O usuário pode salvar as anotações, cancelar e iniciar nova conferência física.

Os ajustes usam `companies/{companyId}/movements`, com o tipo `adjustment`,
referência à contagem e numeração de operação já utilizada pelo estoque.
Concluir salva apenas o relatório e libera a empresa para a próxima contagem.
O ajuste opcional escreve saldos, movimentações, contador da empresa e metadados
de aplicação na mesma transação. Os dados físicos do relatório não são editados.
Relatórios sem diferenças não oferecem ajuste. Cancelar não altera saldos.

O ajuste lê novamente as referências armazenadas e bloqueia a aplicação se o
estoque/cadastro mudou desde a contagem, se existe contagem em andamento ou se
outro relatório mais recente foi concluído. A empresa guarda
`lastCompletedStockCountId` para impedir aplicação de relatórios superados.

Relatórios ajustados recebem `operationId`, `adjustedAt`, `adjustedByUserId` e
`adjustedByName`. Repetir a ação não gera novos ajustes. Relatórios antigos com
`operationId` já eram ajustados ao concluir e são reconhecidos como aplicados,
mesmo sem os novos campos. Nenhum ajuste antigo é revertido ou reaplicado.

`activeStockCountId` na empresa impede inícios simultâneos. Concluir ou cancelar
libera a empresa para a próxima conferência.

As regras locais de Firestore impedem edição dos dados físicos e exclusão de
contagens encerradas. Permitem apenas registrar os metadados do primeiro ajuste.
Elas precisam ser publicadas para aplicar essa proteção no servidor e permitir
o ajuste posterior caso a versão anterior das regras já tenha sido publicada.
Não foi executado deploy nem escrita no Firebase real durante o desenvolvimento.

## Histórico e comparação

Todos os relatórios concluídos aparecem na parte inferior da tela, com busca
por data/responsável e exibição progressiva. Os detalhes são lidos do snapshot,
sem depender de produtos que possam ter sido renomeados ou removidos depois.

A comparação é acessada pelo botão **Comparar** dentro de **Ver relatório**,
na rota `/counts/{countId}/compare`. O relatório aberto permanece como origem;
o usuário escolhe o segundo relatório, sem poder compará-lo consigo mesmo.
A tela organiza os dois cronologicamente, mesmo quando o relatório aberto é o
mais recente, e oferece retorno à tela anterior (ou ao histórico no acesso direto).
Não há comparação embutida na tela principal de contagens. Relatórios ausentes,
apenas uma conferência disponível e falhas de carregamento têm estados próprios.

A comparação usa IDs dos produtos e mostra versões anterior e recente lado a
lado, com filtro para apenas diferenças. As quantidades são separadas em:

- Variação física: encontrado recente menos encontrado anterior.
- Variação registrada: esperado recente menos encontrado anterior.
- Divergência física: encontrado menos esperado em cada conferência.

Variação registrada não é classificada automaticamente como perda ou venda.
Produtos que não participam de um relatório são identificados como ausentes,
sem assumir saldo zero. Unidades diferentes não são comparadas numericamente.

## Validação

Testes cobrem o repositório real com transações simuladas em memória (sem rede),
repetição de conclusão, conflitos de estoque/revisão, contagem parcial, zero,
referências adulteradas, histórico, comparação e interfaces compacta/ampla.
As regras não foram executadas contra um emulador Firebase nesta sessão.
