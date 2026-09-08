import 'package:controle_estoque/app/app.dart';
import 'package:controle_estoque/app/bootstrap/firebase_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre a tela de login sem usuário autenticado', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseBootstrapProvider.overrideWithValue(
            const FirebaseBootstrapResult.notConfigured(),
          ),
        ],
        child: const InventoryApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Firebase pendente'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });
}
