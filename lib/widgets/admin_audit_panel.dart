import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class AdminAuditPanel extends StatefulWidget {
  const AdminAuditPanel({super.key, required this.backend});
  final RestRafaelBackend backend;
  @override State<AdminAuditPanel> createState()=>_AdminAuditPanelState();
}
class _AdminAuditPanelState extends State<AdminAuditPanel>{
  List<Map<String,dynamic>> rows=const[]; bool loading=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{if(loading)return;setState(()=>loading=true);try{final v=await widget.backend.adminAudit();if(mounted)setState(()=>rows=v);}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Text('Auditoría',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:loading?null:_load,icon:const Icon(Icons.refresh))]),
    if(loading)const LinearProgressIndicator(),
    if(!loading&&rows.isEmpty)const Text('Sin eventos de auditoría.'),
    ...rows.take(50).map((e)=>ListTile(dense:true,leading:const Icon(Icons.history),title:Text(e['action']?.toString()??'Evento'),subtitle:Text('${e['actorName']??e['actorId']??''} · ${e['at']??''}'))),
  ])));
}
