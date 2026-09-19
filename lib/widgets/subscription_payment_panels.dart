import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class DriverSubscriptionPaymentPanel extends StatefulWidget {
  const DriverSubscriptionPaymentPanel({super.key, required this.backend, required this.amountCup, required this.card});
  final RestRafaelBackend backend; final int amountCup; final String card;
  @override State<DriverSubscriptionPaymentPanel> createState()=>_DriverSubscriptionPaymentPanelState();
}
class _DriverSubscriptionPaymentPanelState extends State<DriverSubscriptionPaymentPanel>{
 String paymentStatus(dynamic value){switch(value?.toString()){case 'pending':return 'Pendiente';case 'approved':return 'Aprobado';case 'rejected':return 'Rechazado';default:return value?.toString()??'';}}
 final ref=TextEditingController(); bool busy=false; List<Map<String,dynamic>> history=[];
 int? serverAmountCup; String? serverCard;
 @override void initState(){super.initState();load();} @override void dispose(){ref.dispose();super.dispose();}
 Future<void> load() async {
  try{
   final results=await Future.wait([widget.backend.driverSubscriptionPayments(),widget.backend.settings()]);
   final payments=results[0] as List<Map<String,dynamic>>;
   final settings=results[1] as Map<String,dynamic>;
   if(mounted)setState((){history=payments;serverAmountCup=(settings['monthlyFeeCup'] as num?)?.toInt();serverCard=settings['transfermovilCard']?.toString();});
  }catch(_){
   try{final x=await widget.backend.driverSubscriptionPayments();if(mounted)setState(()=>history=x);}catch(_){}
  }
 }
 Future<void> send() async {if(ref.text.trim().length<4)return;setState(()=>busy=true);try{await widget.backend.submitSubscriptionPayment(ref.text.trim());ref.clear();await load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Pago reportado. Esperando revisión de Rafael.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo reportar el pago. Puede existir uno pendiente.')));}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Text('Mensualidad por Transfermóvil',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
  Text('${serverAmountCup??widget.amountCup} CUP · tarjeta: ${(serverCard??widget.card).isEmpty?'Pendiente de configurar':(serverCard??widget.card)}'),
  const Text('Los datos se actualizan desde el servidor de Rafael.',style:TextStyle(fontSize:12)),const SizedBox(height:8),
  TextField(controller:ref,decoration:const InputDecoration(labelText:'Referencia de la transferencia')),const SizedBox(height:8),FilledButton(onPressed:busy?null:send,child:Text(busy?'Enviando…':'Reportar pago')),
  if(history.isNotEmpty)...[const Divider(),...history.take(5).map((p){final receipt=p['receiptNumber']?.toString();final approved=p['status']?.toString()=='approved';return ListTile(dense:true,leading:Icon(approved?Icons.receipt_long:Icons.payments_outlined),title:Text("${p['amountCup']} CUP · ${paymentStatus(p['status'])}"),subtitle:Text(receipt!=null&&receipt.isNotEmpty?'Ref. ${p['reference']}\nRecibo: $receipt':'Ref. ${p['reference']}'),isThreeLine:receipt!=null&&receipt.isNotEmpty,trailing:approved?const Icon(Icons.verified):null);})]
 ])));
}

class AdminSubscriptionPaymentsPanel extends StatefulWidget{
 const AdminSubscriptionPaymentsPanel({super.key,required this.backend}); final RestRafaelBackend backend;
 @override State<AdminSubscriptionPaymentsPanel> createState()=>_AdminSubscriptionPaymentsPanelState();
}
class _AdminSubscriptionPaymentsPanelState extends State<AdminSubscriptionPaymentsPanel>{
 bool busy=false; List<Map<String,dynamic>> pending=[];
 @override void initState(){super.initState();load();}
 Future<void> load() async {setState(()=>busy=true);try{final x=await widget.backend.adminSubscriptionPayments();if(mounted)setState(()=>pending=x);}catch(_){}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> review(String id,String decision) async {try{await widget.backend.reviewSubscriptionPayment(id,decision);await load();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo revisar el pago.')));}}
 @override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[const Expanded(child:Text('Pagos pendientes',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18))),IconButton(onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),
  if(busy)const LinearProgressIndicator() else if(pending.isEmpty)const Text('No hay pagos pendientes.') else ...pending.map((p)=>ListTile(contentPadding:EdgeInsets.zero,title:Text('${p['amountCup']} CUP · Ref. ${p['reference']}'),subtitle:Text("Conductor: ${p['driverName']??p['driverId']}\nRef. ${p['reference']}"),isThreeLine:true,trailing:Wrap(spacing:4,children:[IconButton(tooltip:'Aprobar',onPressed:()=>review('${p['id']}','approved'),icon:const Icon(Icons.check_circle)),IconButton(tooltip:'Rechazar',onPressed:()=>review('${p['id']}','rejected'),icon:const Icon(Icons.cancel))])))
 ])));
}
