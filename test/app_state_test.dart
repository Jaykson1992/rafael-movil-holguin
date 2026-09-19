import 'package:flutter_test/flutter_test.dart';
import 'package:rafael_movil_holguin/main.dart';

void main() {
  group('Rafael Móvil - reglas principales', () {
    test('un viaje recorre el flujo hasta completado', () {
      final state = AppState();
      final trip = Trip(
        origin: 'Parque Calixto García',
        destination: 'Loma de la Cruz',
        vehicle: 'Auto',
        offer: 500,
      );

      state.requestTrip(trip);
      expect(state.trip?.status, TripStatus.searching);
      state.counter(600);
      expect(state.trip?.counterOffer, 600);
      state.accept();
      state.onWay();
      state.start();
      state.finish();

      expect(state.trip?.status, TripStatus.completed);
      expect(state.completedTrips, 1);
      expect(state.totalCup, 600);
      expect(state.history.length, 1);
    });

    test('renovar activa 30 días de mensualidad', () {
      final state = AppState();
      state.driverActive = false;
      state.driverPaidUntil = DateTime.now().subtract(const Duration(days: 1));
      expect(state.subscriptionValid, isFalse);

      state.renew();
      expect(state.subscriptionValid, isTrue);
      expect(state.driverPaidUntil.isAfter(DateTime.now().add(const Duration(days: 29))), isTrue);
    });

    test('registro conserva rol y vehículo del conductor', () {
      final state = AppState();
      state.registerDriver('Rafael', '12345678901', 'Triciclo');
      expect(state.driverRegistered, isTrue);
      expect(state.driverVehicle, 'Triciclo');
    });
  });
}
