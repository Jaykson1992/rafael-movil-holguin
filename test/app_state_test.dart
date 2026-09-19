import 'package:flutter_test/flutter_test.dart';
import 'package:rafael_movil_holguin/main.dart';

void main(){
  test('flujo local de viaje',(){
    final state=S();
    state.trip('Parque','Hospital','Auto',500);
    expect(state.status,'Buscando conductor');
    expect(state.offer,500);
    state.st('Viaje completado');
    expect(state.status,'Viaje completado');
  });
  test('configuracion local',(){
    final state=S();
    state.setFee(1200); state.setActive(false);
    expect(state.fee,1200); expect(state.active,false);
  });
}
