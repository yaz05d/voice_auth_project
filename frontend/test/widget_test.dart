import 'package:flutter_test/flutter_test.dart';
import 'package:voice_auth_app/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceGuardApp());
    expect(find.byType(VoiceGuardApp), findsOneWidget);
  });
}