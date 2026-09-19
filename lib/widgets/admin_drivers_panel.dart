import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class AdminDriversPanel extends StatefulWidget {
  const AdminDriversPanel({super.key, required this.backend});
  final RestRafaelBackend backend;
  @override State<AdminDriversPanel> createState() => _AdminDriversPanelState();
}

class _AdminDriversPanelState extends State<AdminDriversPanel> {
  List<Map<String,dynamic>> drivers = const [];
  bool loading = false; String? error;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {if(loading)return;setState(()=>loading=true);try{final data=await widget.backend.adminDrivers();if(mounted)setState((){drivers=data;error=null;});}catch(_){if(mounted)setState(()=>error='No se pudieron cargar los conductores.');}finally{if(mounted)setState(()=>loading=false);}}
  Future<void> _active(String id,bool value) async {try{await widget.backend.setDriverActive(id,value);await _load();}catch(_){_msg('No se pudo cambiar la cuenta.');}}
  Future<void> _renew(String id) async {try{await widget.backend.renewDriver(id);await _load();_msg('Mensualidad renovada.');}catch(_){_msg('No se pudo renovar.');}}
  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  IconData _vehicleIcon(String v){switch(v.toLowerCase()){case'moto':return Icons.two_wheeler;case'bicitaxi':return Icons.pedal_bike;case'triciclo':return Icons.electric_rickshaw;default:return Icons.directions_car;}}
  Widget _avatar(Map<String,dynamic>d){final url=d['photoUrl']?.toString()??'';return CircleAvatar(radius:27,backgroundImage:url.startsWith('http')?NetworkImage(url):(url.startsWith('data:image')?MemoryImage(base64Decode(url.split(',').last)):null),child:(url.startsWith('http')||url.startsWith('data:image'))?null:const Icon(Icons.person,size:30));}
  @override Widget build(BuildContext context){return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Text('Conductores',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),IconButton(onPressed:loading?null:_load,icon:const Icon(Icons.refresh))]),
    const Text('Rafael puede revisar identidad, vehículo, mensualidad y estado de cada conductor.'),const SizedBox(height:8),
    if(loading)const LinearProgressIndicator(),if(error!=null)Text(error!),if(!loading&&drivers.isEmpty)const Text('No hay conductores registrados.'),
    ...drivers.map((d){final sub=Map<String,dynamic>.from((d['subscription'] as Map?)??const{});final active=(sub['active']??true)==true;final busy=d['busy']==true;final paid=sub['paidUntil']?.toString();final paidDate=paid==null?null:DateTime.tryParse(paid)?.toLocal();final valid=paidDate!=null&&paidDate.isAfter(DateTime.now());final id=d['id']?.toString()??'';final vehicle=d['vehicle']?.toString()??'Auto';return Card(margin:const EdgeInsets.symmetric(vertical:6),child:ExpansionTile(
      leading:_avatar(d),title:Text(d['name']?.toString()??'Conductor',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Row(children:[Icon(_vehicleIcon(vehicle),size:16),const SizedBox(width:5),Expanded(child:Text('$vehicle · ${busy?'ocupado':(active&&valid?'disponible':'pausado')}'))]),
      trailing:Icon(active&&valid?Icons.verified:Icons.pause_circle_outline),children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('Carnet: ${d['identity']??'-'}'),const SizedBox(height:4),Text(valid?'Mensualidad hasta ${paidDate.month}/${paidDate.day}/${paidDate.year}':'Mensualidad vencida o pendiente'),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:id.isEmpty?null:(v)=>_active(id,v),title:const Text('Cuenta activa')),OutlinedButton.icon(onPressed:id.isEmpty?null:()=>_renew(id),icon:const Icon(Icons.receipt_long),label:const Text('Renovar mensualidad y registrar acceso')),
      ]))]));}),
  ]))));}
}
