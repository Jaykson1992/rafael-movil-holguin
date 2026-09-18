import 'package:flutter/material.dart';
import '../services/live_trip_tracking_service.dart';

class DriverGpsSharingPanel extends StatefulWidget{
 const DriverGpsSharingPanel({super.key,required this.tracking,required this.driverId,required this.tripId});
 final LiveTripTrackingService tracking; final String driverId; final String tripId;
 @override State<DriverGpsSharingPanel> createState()=>_DriverGpsSharingPanelState();
}
class _DriverGpsSharingPanelState extends State<DriverGpsSharingPanel>{
 bool sharing=false,busy=false;
 Future<void> _toggle()async{if(busy)return;setState(()=>busy=true);if(sharing){await widget.tracking.stop();if(mounted)setState(()=>sharing=false);}else{final ok=await widget.tracking.start(driverId:widget.driverId,tripId:widget.tripId);if(mounted){setState(()=>sharing=ok);if(!ok)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Activa la ubicación del teléfono y concede permiso.')));}}if(mounted)setState(()=>busy=false);}
 @override void dispose(){widget.tracking.stop();super.dispose();}
 @override Widget build(BuildContext context)=>Card(child:SwitchListTile(value:sharing,onChanged:busy?null:(_)=>_toggle(),secondary:Icon(sharing?Icons.gps_fixed:Icons.gps_off),title:const Text('Compartir ubicación'),subtitle:Text(sharing?'El cliente recibe tu posición durante el viaje.':'GPS detenido.')));
}
