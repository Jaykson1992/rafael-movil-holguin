import 'package:flutter/material.dart';

import '../services/live_trip_tracking_service.dart';

/// Control visible para que el conductor sepa si está compartiendo GPS.
/// Solo se usa durante un viaje asignado/en camino/en curso.
class DriverGpsSharingPanel extends StatefulWidget {
  const DriverGpsSharingPanel({
    super.key,
    required this.tracking,
    required this.driverId,
    required this.tripId,
  });

  final LiveTripTrackingService tracking;
  final String driverId;
  final String tripId;

  @override
  State<DriverGpsSharingPanel> createState() => _DriverGpsSharingPanelState();
}

class _DriverGpsSharingPanelState extends State<DriverGpsSharingPanel> {
  bool sharing = false;
  bool busy = false;
  String message = 'GPS detenido';

  Future<void> _toggle() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (sharing) {
        await widget.tracking.stopDriverSharing();
        if (mounted) setState(() { sharing = false; message = 'GPS detenido'; });
      } else {
        await widget.tracking.startDriverSharing(driverId: widget.driverId, tripId: widget.tripId);
        if (mounted) setState(() { sharing = true; message = 'Compartiendo ubicación con el cliente'; });
      }
    } catch (_) {
      if (mounted) setState(() => message = 'No se pudo activar el GPS. Revisa permiso y conexión.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    widget.tracking.stopDriverSharing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(sharing ? Icons.gps_fixed : Icons.gps_off),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: busy ? null : _toggle,
                icon: Icon(sharing ? Icons.stop_circle_outlined : Icons.my_location),
                label: Text(sharing ? 'Detener ubicación' : 'Compartir ubicación'),
              ),
            ],
          ),
        ),
      );
}
