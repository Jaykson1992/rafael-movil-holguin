import 'package:flutter_test/flutter_test.dart';
import 'package:rafael_movil_holguin/main.dart';

void main(){
  testWidgets('abre Rafael Movil',(tester) async{
    await tester.pumpWidget(const App());
    expect(find.text('Rafael Móvil'),findsOneWidget);
    expect(find.text('Cliente'),findsOneWidget);
    expect(find.text('Conductor'),findsOneWidget);
    expect(find.text('Administrador'),findsOneWidget);
  });
}
