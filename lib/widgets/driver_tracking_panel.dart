import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class DriverTrackingPanel extends StatefulWidget{
 const DriverTrackingPanel({super.key,required this.backend,required this.tripId}); final RestRafaelBackend backend; final String tripId;
 @override State<DriverTrackingPanel> createState()=>_DriverTrackingPanelState();
}
class _DriverTrackingPanelState extends State<DriverTrackingPanel>{
 Map<String,dynamic>? trip; bool loading=false;
 Future<void> _refresh()async{if(loading)return;setState(()=>loading=true);try{final t=await widget.backend.trip(widget.tripId);if(mounted)setState(()=>trip=t);}finally{if(mounted)setState(()=>loading=false);}}
 @override void initState(){super.initState();_refresh();}
 @override Widget build(BuildContext context){final t=trip??const{};return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Row(children:[const Expanded(child:Text('Viaje activo',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),
  Text('${t['origin']??'-'} → ${t['destination']??'-'}'),Text('Estado: ${t['status']??'cargando'}'),
  if(t['agreedPrice']!=null)Text('Precio acordado: ${t['agreedPrice']} CUP'),
 ])));}
}
