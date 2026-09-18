import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class DriverSubscriptionPanel extends StatefulWidget{
 const DriverSubscriptionPanel({super.key,required this.backend}); final RestRafaelBackend backend;
 @override State<DriverSubscriptionPanel> createState()=>_DriverSubscriptionPanelState();
}
class _DriverSubscriptionPanelState extends State<DriverSubscriptionPanel>{
 Map<String,dynamic>? data; bool loading=false;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{setState(()=>loading=true);try{final v=await widget.backend.subscriptionStatus();if(mounted)setState(()=>data=v);}finally{if(mounted)setState(()=>loading=false);}}
 Future<void> _report()async{try{await widget.backend.reportSubscriptionPayment();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Pago reportado al administrador.')));await _load();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo reportar el pago.')));}}
 @override Widget build(BuildContext context){final d=data??const{};return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  const Text('Mensualidad del conductor',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  if(loading)const LinearProgressIndicator(),
  Text('Precio: ${d['monthlyFeeCup']??1000} CUP'),
  Text('Estado: ${d['valid']==true?'Activa':'Pendiente o vencida'}'),
  if((d['paymentMethod']??'').toString().isNotEmpty)Text('Pago: ${d['paymentMethod']}'),
  FilledButton.icon(onPressed:loading?null:_report,icon:const Icon(Icons.send),label:const Text('Ya pagué por Transfermóvil')),
 ])));}
}
