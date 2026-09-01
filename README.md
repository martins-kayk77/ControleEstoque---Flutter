# Controle de Estoque

Base Flutter + Firebase para um sistema de controle de estoque voltado a pequenos negócios, com foco inicial em cosméticos e produtos de beleza.

## Plataformas

- Android
- Web

## Primeira etapa

Esta etapa cria a fundação do projeto:

- Projeto Flutter com Android e Web.
- Dependências Firebase para Auth, Firestore e Storage.
- Bootstrap Firebase por `--dart-define`.
- Roteamento com `go_router`.
- Injeção de dependências com Riverpod.
- Telas centralizadas em `lib/screens`.
- Features separadas para domínio, serviços e repositórios.
- Modelos iniciais para empresa, usuário, produto, categoria, movimentação, contagem, venda, canal e precificação.
- Repositórios e serviços iniciais para Firestore.
- Dashboard provisório e shell responsivo.
- Regras iniciais de Firestore e Storage com isolamento multiempresa.

Os pacotes Firebase foram pinados na linha FlutterFire compatível com o Flutter local (`3.32.2` / Dart `3.8.1`).

## Rodando sem Firebase

O app abre mesmo sem credenciais Firebase reais. Nesse modo, a tela mostra `Firebase pendente`.

```bash
flutter run -d chrome
```

## Rodando com Firebase

Copie `config/firebase.example.json` para `config/firebase.dev.json`, preencha com os valores reais do projeto Firebase e rode:

```bash
flutter run -d chrome --dart-define-from-file=config/firebase.dev.json
```

Para Android:

```bash
flutter run -d android --dart-define-from-file=config/firebase.dev.json
```

## Documentação

- `docs/architecture.md`
- `docs/firebase_setup.md`
"# ControleEstoque---Flutter" 
