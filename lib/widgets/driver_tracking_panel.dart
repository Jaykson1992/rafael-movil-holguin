import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/sync_models.dart';
import '../services/live_trip_tracking_service.dart';

class DriverTrackingPanel extends StatelessWidget {
  const DriverTrackingPanel({super.key, required this.tracking, required this.driverId, required this.tripId, this.clientPosition});
  final LiveTripTrackingService tracking;
  final String driverId;
  final String tripId;
  final GeoPoint? clientPosition;

  @override
  Widget build(BuildContext context) => StreamBuilder<GeoPoint>(
    stream: tracking.watchDriver(driverId: driverId, tripId: tripId),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const _StatusCard(icon: Icons.cloud_off, title: 'Conexión débil', detail: 'El viaje sigue activo. Reintentando ubicación…');
      final point = snapshot.data;
      if (point == null) return const _StatusCard(icon: Icons.location_searching, title: 'Buscando al conductor…', detail: 'Esperando la próxima señal GPS.', loading: true);
      final distance = clientPosition == null ? null : _distanceKm(clientPosition!, point);
      return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children:[Icon(Icons.directions_car_filled),SizedBox(width:8),Text('Conductor en tiempo real',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))]),
        const SizedBox(height:12),
        Container(height:150,width:double.infinity,decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),color:Theme.of(context).colorScheme.surfaceContainerHighest),child:const Stack(children:[Positioned(left:28,top:32,child:Icon(Icons.location_on,size:34)),Positioned(right:36,bottom:30,child:Icon(Icons.local_taxi,size:38)),Center(child:Icon(Icons.route,size:74))])),
        const SizedBox(height:12),
        Text('GPS: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'),
        if(distance!=null) Text('Distancia aproximada: ${distance < 1 ? '${(distance*1000).round()} m' : '${distance.toStringAsFixed(1)} km'}'),
        const Text('La posición se actualiza automáticamente cuando hay conexión.'),
      ])));
    },
  );

  static double _distanceKm(GeoPoint a, GeoPoint b) {
    const earth=6371.0; double rad(double d)=>d*math.pi/180;
    final dLat=rad(b.latitude-a.latitude), dLon=rad(b.longitude-a.longitude), lat1=rad(a.latitude), lat2=rad(b.latitude);
    final h=math.sin(dLat/2)*math.sin(dLat/2)+math.cos(lat1)*math.cos(lat2)*math.sin(dLon/2)*math.sin(dLon/2);
    return earth*2*math.atan2(math.sqrt(h),math.sqrt(1-h));
  }
}
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon,required this.title,required this.detail,this.loading=false});
  final IconData icon; final String title,detail; final bool loading;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[Icon(icon,size:34),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),Text(detail)])),if(loading)const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))])));
}
