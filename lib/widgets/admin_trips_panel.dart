import 'package:flutter/material.dart';
import '../services/rest_backend_service.dart';

class AdminTripsPanel extends StatefulWidget {
  const AdminTripsPanel({super.key, required this.backend});
  final RestRafaelBackend backend;
  @override State<AdminTripsPanel> createState() => _AdminTripsPanelState();
}

class _AdminTripsPanelState extends State<AdminTripsPanel> {
  List<Map<String,dynamic>> trips = const [];
  bool loading = false;
  String? error;
  String status = '';

  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(loading)return;
    setState(()=>loading=true);
    try{
      final data=await widget.backend.trips(status:status.isEmpty?null:status,limit:30);
      if(mounted)setState((){trips=data;error=null;});
    }catch(_){if(mounted)setState(()=>error='No se pudieron cargar los viajes.');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  String label(String s)=>switch(s){
    'searching'=>'Buscando','countered'=>'Contraoferta','assigned'=>'Asignado',
    'arriving'=>'En camino','inProgress'=>'En curso','completed'=>'Completado',
    'cancelled'=>'Cancelado',_=>s,
  };
  @override Widget build(BuildContext context)=>Card(child:Padding(
    padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Text('Viajes del servidor',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:loading?null:_load,icon:const Icon(Icons.refresh))]),
      DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Filtrar por estado'),items:const [
        DropdownMenuItem(value:'',child:Text('Todos')),DropdownMenuItem(value:'searching',child:Text('Buscando')),
        DropdownMenuItem(value:'assigned',child:Text('Asignados')),DropdownMenuItem(value:'arriving',child:Text('En camino')),
        DropdownMenuItem(value:'inProgress',child:Text('En curso')),DropdownMenuItem(value:'completed',child:Text('Completados')),
        DropdownMenuItem(value:'cancelled',child:Text('Cancelados')),
      ],onChanged:(v){status=v??'';_load();}),
      if(loading)const LinearProgressIndicator(),if(error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(error!)),
      if(!loading&&trips.isEmpty)const Padding(padding:EdgeInsets.only(top:8),child:Text('No hay viajes para este filtro.')),
      ...trips.map((t)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.route),title:Text('${t['origin']??'Origen'} → ${t['destination']??'Destino'}'),subtitle:Text('${t['vehicle']??'vehículo'} · ${label('${t['status']??''}')}'),trailing:Text('${t['counterOffer']??t['offer']??0} CUP'))),
    ])));
}
