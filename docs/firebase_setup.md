# Configuração Firebase

O app já possui dependências para:

- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Firebase Storage

As versões FlutterFire estão pinadas na linha compatível com Flutter `3.32.2` / Dart `3.8.1`, porque a linha mais recente do `firebase_core_web` exige APIs que quebraram o build Web nesta instalação local.

As credenciais reais não foram gravadas no repositório. O arquivo `lib/firebase_options.dart` lê valores por `--dart-define`.

## Passos sugeridos

1. Crie um projeto no Firebase Console.
2. Ative Authentication com e-mail/senha.
3. Crie o banco Cloud Firestore.
4. Ative Storage somente quando precisar armazenar imagens/arquivos.
5. Copie `config/firebase.example.json` para `config/firebase.dev.json`.
6. Preencha os valores reais do projeto.
7. Rode:

```bash
flutter run -d chrome --dart-define-from-file=config/firebase.dev.json
```

Para Android:

```bash
flutter run -d android --dart-define-from-file=config/firebase.dev.json
```

Se preferir usar FlutterFire CLI, rode `flutterfire configure` e substitua o `lib/firebase_options.dart` gerado por ele ou adapte os valores para o padrão atual do projeto.

## Regras

Os arquivos iniciais são:

- `firestore.rules`
- `storage.rules`
- `firestore.indexes.json`
- `firebase.json`

Para publicar regras após configurar o projeto:

```bash
firebase deploy --only firestore:rules,storage
```

## Observação de segurança

As regras iniciais bloqueiam acesso público e usam `users/{uid}.companyIds` como vínculo de empresa. Na etapa de usuários por empresa, vale adicionar papéis como `owner`, `admin` e `member` para controlar escrita por coleção.
