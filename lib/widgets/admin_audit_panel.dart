import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class AdminAuditPanel extends StatefulWidget {
  const AdminAuditPanel({super.key, required this.backend});
  final RestRafaelBackend backend;
  @override State<AdminAuditPanel> createState()=>_AdminAuditPanelState();
}
class _AdminAuditPanelState extends State<AdminAuditPanel>{
  bool loading=false; String? error; List<Map<String,dynamic>> rows=[];
  String action=''; String actorRole=''; final search=TextEditingController();
  @override void dispose(){search.dispose();super.dispose();}
  Future<void> load() async {setState(()=>loading=true);try{final r=await widget.backend.adminAudit(limit:100,action:action,role:actorRole,query:search.text);if(mounted)setState((){rows=r;error=null;});}catch(_){if(mounted)setState(()=>error='No se pudo cargar el registro.');}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context)=>Card(child:ExpansionTile(
    leading:const Icon(Icons.security), title:const Text('Registro de seguridad'),
    subtitle:Text(rows.isEmpty?'Cambios de viajes, pagos y cuentas':'${rows.length} eventos encontrados'),
    onExpansionChanged:(v){if(v&&rows.isEmpty&&!loading)load();},
    children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,4,16,8),child:Column(children:[
        TextField(controller:search,textInputAction:TextInputAction.search,onSubmitted:(_)=>load(),decoration:InputDecoration(labelText:'Buscar',hintText:'Viaje, conductor, pago…',suffixIcon:IconButton(onPressed:load,icon:const Icon(Icons.search)))),
        const SizedBox(height:8),Row(children:[Expanded(child:DropdownButtonFormField<String>(value:actorRole,decoration:const InputDecoration(labelText:'Rol'),items:const [DropdownMenuItem(value:'',child:Text('Todos')),DropdownMenuItem(value:'admin',child:Text('Administrador')),DropdownMenuItem(value:'driver',child:Text('Conductor')),DropdownMenuItem(value:'client',child:Text('Cliente'))],onChanged:(v){setState(()=>actorRole=v??'');load();})),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Evento'),items:const [DropdownMenuItem(value:'',child:Text('Todos')),DropdownMenuItem(value:'trip_updated',child:Text('Viajes')),DropdownMenuItem(value:'subscription_payment_reviewed',child:Text('Pagos revisados')),DropdownMenuItem(value:'driver_updated',child:Text('Conductores')),DropdownMenuItem(value:'settings_updated',child:Text('Configuración'))],onChanged:(v){setState(()=>action=v??'');load();}))]),
      ])),
      if(loading)const Padding(padding:EdgeInsets.all(16),child:CircularProgressIndicator()),
      if(error!=null)ListTile(title:Text(error!),trailing:IconButton(onPressed:load,icon:const Icon(Icons.refresh))),
      if(!loading&&error==null&&rows.isEmpty)const ListTile(leading:Icon(Icons.search_off),title:Text('No hay eventos con esos filtros.')),
      ...rows.take(100).map((e)=>ListTile(dense:true,leading:const Icon(Icons.history),title:Text(_label(e['action']?.toString()??'')),subtitle:Text('${_role(e['role']?.toString())} · ${_date(e['at']?.toString())}'))),
    ],
  ));
  String _label(String a)=>const {'trip_updated':'Viaje actualizado','subscription_renewed':'Mensualidad renovada','subscription_payment_submitted':'Pago reportado','subscription_payment_reviewed':'Pago revisado','driver_updated':'Cuenta de conductor modificada','settings_updated':'Configuración modificada'}[a]??a.replaceAll('_',' ');
  String _role(String? r)=>const {'admin':'Administrador','driver':'Conductor','client':'Cliente','system':'Sistema'}[r]??(r??'');
  String _date(String? s){final d=DateTime.tryParse(s??'')?.toLocal();return d==null?'': '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';}
}
