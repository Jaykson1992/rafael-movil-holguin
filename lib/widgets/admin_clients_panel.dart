import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class AdminClientsPanel extends StatefulWidget {
  const AdminClientsPanel({super.key, required this.backend});
  final RestRafaelBackend backend;
  @override State<AdminClientsPanel> createState()=>_AdminClientsPanelState();
}
class _AdminClientsPanelState extends State<AdminClientsPanel>{
  List<Map<String,dynamic>> clients=const[]; bool loading=false; String? error; final search=TextEditingController();
  @override void initState(){super.initState();_load();}
  @override void dispose(){search.dispose();super.dispose();}
  Future<void> _load() async{if(loading)return;setState(()=>loading=true);try{final rows=await widget.backend.adminClients(query:search.text);if(mounted)setState((){clients=rows;error=null;});}catch(_){if(mounted)setState(()=>error='No se pudieron cargar los clientes.');}finally{if(mounted)setState(()=>loading=false);}}
  Future<void> _active(String id,bool active) async{try{await widget.backend.setClientActive(id,active);await _load();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo cambiar la cuenta.')));}}
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Text('Clientes',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:loading?null:_load,icon:const Icon(Icons.refresh))]),
    TextField(controller:search,onSubmitted:(_)=>_load(),decoration:InputDecoration(labelText:'Buscar cliente',hintText:'Nombre o carnet',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:_load,icon:const Icon(Icons.arrow_forward)))),
    if(loading)const LinearProgressIndicator(),if(error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(error!)),
    if(!loading&&clients.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('No hay clientes para mostrar.')),
    ...clients.map((u){final active=u['active']!=false;final id=u['id']?.toString()??'';return ListTile(leading:CircleAvatar(child:Icon(active?Icons.person:Icons.person_off)),title:Text(u['name']?.toString()??'Cliente'),subtitle:Text('Carnet: ${u['identity']??'-'} · ${u['trips']??0} viajes'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='toggle')_active(id,!active);},itemBuilder:(_)=>[PopupMenuItem(value:'toggle',child:Text(active?'Bloquear cuenta':'Reactivar cuenta'))]));}),
  ])));
}
