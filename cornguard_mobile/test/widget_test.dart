import 'package:flutter_test/flutter_test.dart';
import 'package:cornguard_mobile/main.dart';

void main() {
  testWidgets('Belum login menampilkan halaman Login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));

    expect(find.text('CornGuard'), findsOneWidget);
    expect(find.text('Masuk ke Beranda'), findsOneWidget);
  });
}