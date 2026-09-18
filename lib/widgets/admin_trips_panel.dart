import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class AdminTripsPanel extends StatefulWidget{
 const AdminTripsPanel({super.key,required this.backend}); final RestRafaelBackend backend;
 @override State<AdminTripsPanel> createState()=>_AdminTripsPanelState();
}
class _AdminTripsPanelState extends State<AdminTripsPanel>{
 List<Map<String,dynamic>> trips=const[]; bool loading=false;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{if(loading)return;setState(()=>loading=true);try{final v=await widget.backend.adminTrips();if(mounted)setState(()=>trips=v);}finally{if(mounted)setState(()=>loading=false);}}
 @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[const Expanded(child:Text('Viajes',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:loading?null:_load,icon:const Icon(Icons.refresh))]),
  if(loading)const LinearProgressIndicator(),
  if(!loading&&trips.isEmpty)const Text('Todavía no hay viajes.'),
  ...trips.take(100).map((t)=>ListTile(leading:const Icon(Icons.route),title:Text('${t['origin']??'-'} → ${t['destination']??'-'}'),subtitle:Text('${t['status']??''} · ${t['vehicle']??''} · ${t['agreedPrice']??t['offer']??'-'} CUP'))),
 ])));
}
