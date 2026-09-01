import 'package:controle_estoque/app/app.dart';
import 'package:controle_estoque/app/bootstrap/firebase_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre o dashboard provisório', (tester) async {
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

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Produtos'), findsWidgets);
    expect(find.text('Firebase pendente'), findsOneWidget);
  });
}
