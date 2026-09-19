import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/sync_models.dart';
import 'services/app_config.dart';
import 'services/live_trip_tracking_service.dart';
import 'services/location_tracking_service.dart';
import 'services/server_health_service.dart';
import 'services/session_service.dart';
import 'services/rest_backend_service.dart';
import 'widgets/driver_tracking_panel.dart';
import 'widgets/driver_gps_sharing_panel.dart';
import 'widgets/subscription_payment_panels.dart';
import 'widgets/admin_drivers_panel.dart';
import 'widgets/admin_clients_panel.dart';
import 'widgets/admin_trips_panel.dart';
import 'widgets/admin_audit_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasProductionServer) {
    try { await appState.restoreSession(); } catch (_) { /* arranca sin sesión si el almacén seguro falla */ }
  }
  runApp(const RafaelMovilApp());
}

enum TripStatus { searching, countered, assigned, arriving, inProgress, completed, cancelled }

class Trip {
  Trip({required this.origin, required this.destination, required this.vehicle, required this.offer});
  final String origin, destination, vehicle;
  String id = '';
  String driverId = '';
  final int offer;
  int? counterOffer;
  TripStatus status = TripStatus.searching;
  String get statusText => switch(status){
    TripStatus.searching=>'Buscando conductor', TripStatus.countered=>'Contraoferta recibida',
    TripStatus.assigned=>'Conductor asignado', TripStatus.arriving=>'Conductor en camino',
    TripStatus.inProgress=>'Viaje en curso', TripStatus.completed=>'Viaje completado', TripStatus.cancelled=>'Cancelado'};
}

Trip tripFromJson(Map<String,dynamic> j) {
  final t=Trip(origin:j['origin']?.toString()??'',destination:j['destination']?.toString()??'',vehicle:j['vehicle']?.toString()??'auto',offer:(j['offer'] as num?)?.toInt()??0);
  t.id=j['id']?.toString()??''; t.driverId=j['driverId']?.toString()??''; t.counterOffer=(j['counterOffer'] as num?)?.toInt();
  t.status=switch(j['status']?.toString()){ 'countered'=>TripStatus.countered,'assigned'=>TripStatus.assigned,'arriving'=>TripStatus.arriving,'inProgress'=>TripStatus.inProgress,'completed'=>TripStatus.completed,'cancelled'=>TripStatus.cancelled,_=>TripStatus.searching};
  return t;
}

class AppState extends ChangeNotifier {
  Trip? trip;
  String clientName = '';
  String clientId = '';
  String driverName = '';
  String driverId = '';
  String driverVehicle = 'Auto';
  String? clientToken;
  String? driverToken;
  String? adminToken;
  final SessionService sessionService = SessionService();
  bool get clientRegistered => clientName.trim().isNotEmpty && clientId.trim().isNotEmpty;
  bool get driverRegistered => driverName.trim().isNotEmpty && driverId.trim().isNotEmpty;
  int monthlyFee = 1000;
  String adminPin = '246810';
  String transfermovilCard = '';
  bool driverActive = true;
  DateTime driverPaidUntil = DateTime.now().add(const Duration(days: 30));
  final List<Trip> history = [];
  int completedTrips = 0;
  int totalCup = 0;
  bool get subscriptionValid => driverActive && driverPaidUntil.isAfter(DateTime.now());
  void requestTrip(Trip t){trip=t;notifyListeners();}
  void counter(int p){if(trip!=null){trip!.counterOffer=p;trip!.status=TripStatus.countered;notifyListeners();}}
  void accept(){if(trip!=null){trip!.status=TripStatus.assigned;notifyListeners();}}
  void onWay(){if(trip!=null){trip!.status=TripStatus.arriving;notifyListeners();}}
  void start(){if(trip!=null){trip!.status=TripStatus.inProgress;notifyListeners();}}
  void finish(){if(trip!=null){trip!.status=TripStatus.completed;history.insert(0,trip!);completedTrips++;totalCup += trip!.counterOffer ?? trip!.offer;notifyListeners();}}
  void cancel(){if(trip!=null){trip!.status=TripStatus.cancelled;history.insert(0,trip!);} trip=null;notifyListeners();}
  void renew(){driverPaidUntil=DateTime.now().add(const Duration(days:30));driverActive=true;notifyListeners();}
  void registerClient(String name,String id){clientName=name.trim();clientId=id.trim();notifyListeners();}
  void registerDriver(String name,String id,String vehicle){driverName=name.trim();driverId=id.trim();driverVehicle=vehicle;notifyListeners();}
  Future<void> restoreSession() async {
    final saved=await sessionService.restore();
    if(saved==null) return;

    // Never trust a token only because it exists on the phone. Validate it with
    // /v1/me first so expired/revoked sessions cannot silently reopen the app.
    try {
      final backend=RestRafaelBackend(baseUrl:AppConfig.apiUrl,bearerToken:saved.token);
      final me=await backend.me();
      final serverRole=me['role']?.toString();
      final serverIdentity=me['identity']?.toString();
      if(serverRole!=saved.role || serverIdentity!=saved.identity) {
        await sessionService.clear();
        return;
      }
      if(saved.role=='driver'){
        driverName=me['name']?.toString()??saved.name;
        driverId=saved.identity;
        driverVehicle=me['vehicle']?.toString()??saved.vehicle??'Auto';
        driverToken=saved.token;
      }
      if(saved.role=='client'){
        clientName=me['name']?.toString()??saved.name;
        clientId=saved.identity;
        clientToken=saved.token;
      }
      notifyListeners();
    } catch (_) {
      // A network failure must not erase a potentially valid session. It stays
      // stored and will be validated again next launch/login. We simply start
      // signed-out for this run instead of granting access without validation.
    }
  }
  Future<void> persistClientSession() async { if(clientToken!=null) await sessionService.save(role:'client',token:clientToken!,name:clientName,identity:clientId); }
  Future<void> persistDriverSession() async { if(driverToken!=null) await sessionService.save(role:'driver',token:driverToken!,name:driverName,identity:driverId,vehicle:driverVehicle); }
  Future<void> signOut() async {
    // Revoke the active server session before deleting the local encrypted copy.
    // If the phone is offline we still clear local access immediately; the token
    // will expire server-side according to the configured session TTL.
    final token = clientToken ?? driverToken;
    if (AppConfig.hasProductionServer && token != null && token.isNotEmpty) {
      try {
        await RestRafaelBackend(baseUrl: AppConfig.apiUrl, bearerToken: token).logout();
      } catch (_) {
        // Offline/server failure must never prevent local sign-out.
      }
    }
    clientToken=null;driverToken=null;clientName='';clientId='';driverName='';driverId='';
    await sessionService.clear();
    notifyListeners();
  }
  RestRafaelBackend clientBackend()=>RestRafaelBackend(baseUrl:AppConfig.apiUrl,bearerToken:clientToken);
  RestRafaelBackend driverBackend()=>RestRafaelBackend(baseUrl:AppConfig.apiUrl,bearerToken:driverToken);
  RestRafaelBackend adminBackend()=>RestRafaelBackend(baseUrl:AppConfig.apiUrl,bearerToken:adminToken);
  Future<void> syncPaymentSettings(RestRafaelBackend backend) async {
    final settings=await backend.settings();
    monthlyFee=(settings['monthlyFeeCup'] as num?)?.toInt()??monthlyFee;
    transfermovilCard=settings['transfermovilCard']?.toString()??transfermovilCard;
    notifyListeners();
  }
}
final appState=AppState();

class RafaelMovilApp extends StatelessWidget {const RafaelMovilApp({super.key});
 @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Rafael Móvil',theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff1565c0)),useMaterial3:true,inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder())),home:const RoleScreen());}

class ConnectionStatusCard extends StatefulWidget {const ConnectionStatusCard({super.key});@override State<ConnectionStatusCard> createState()=>_ConnectionStatusCardState();}
class _ConnectionStatusCardState extends State<ConnectionStatusCard>{ServerHealth? health;bool loading=false;@override void initState(){super.initState();check();}Future<void> check() async{setState(()=>loading=true);final h=await ServerHealthService(AppConfig.apiUrl).check();if(mounted)setState((){health=h;loading=false;});}@override Widget build(BuildContext c){final h=health;return Card(child:ListTile(leading:Icon(h?.online==true?Icons.cloud_done:Icons.cloud_off),title:Text(h?.online==true?'Servidor conectado':'Modo local / sin servidor'),subtitle:Text(loading?'Comprobando conexión…':(h?.message??'Sin comprobar')),trailing:h?.latencyMs==null?IconButton(onPressed:loading?null:check,icon:const Icon(Icons.refresh)):Text('${h!.latencyMs} ms')));}}

class RoleScreen extends StatelessWidget {const RoleScreen({super.key});
 @override Widget build(BuildContext c)=>Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Spacer(),Image.asset('assets/rafael_logo.jpg',height:120,fit:BoxFit.contain),const Text('Rafael Móvil',textAlign:TextAlign.center,style:TextStyle(fontSize:34,fontWeight:FontWeight.bold)),const Text('TRANSPORTE HOLGUÍN',textAlign:TextAlign.center,style:TextStyle(letterSpacing:2,fontWeight:FontWeight.w600)),const SizedBox(height:5),const Text('Tu viaje, tu precio',textAlign:TextAlign.center),const Spacer(),go(c,'Cliente',Icons.person,appState.clientRegistered?const ClientHome():const AccountEntryScreen(role:'Cliente')),const SizedBox(height:10),go(c,'Conductor',Icons.local_taxi,appState.driverRegistered?const DriverHome():const AccountEntryScreen(role:'Conductor')),const SizedBox(height:10),go(c,'Administrador',Icons.admin_panel_settings,const AdminPinScreen()),const Spacer()] ))));
 static Widget go(BuildContext c,String s,IconData i,Widget p)=>FilledButton.icon(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>p)),icon:Icon(i),label:Padding(padding:const EdgeInsets.all(14),child:Text(s)));}


class AdminPinScreen extends StatefulWidget {const AdminPinScreen({super.key});@override State<AdminPinScreen> createState()=>_AdminPinScreenState();}
class _AdminPinScreenState extends State<AdminPinScreen>{
 final identity=TextEditingController();final pin=TextEditingController();int tries=0;bool loading=false;String? error;
 @override void dispose(){identity.dispose();pin.dispose();super.dispose();}
 Future<void> enter() async {
   if(pin.text.length!=6){setState(()=>error='El PIN debe tener 6 dígitos.');return;}
   if(!AppConfig.hasProductionServer){
     if(pin.text==appState.adminPin){if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const AdminHome()));}
     else {setState((){tries++;error='PIN incorrecto en modo demostración.';});pin.clear();}
     return;
   }
   if(identity.text.trim().isEmpty){setState(()=>error='Escribe la identidad del administrador.');return;}
   setState((){loading=true;error=null;});
   try{
     final backend=RestRafaelBackend(baseUrl:AppConfig.apiUrl);
     final result=await backend.login(identity:identity.text.trim(),pin:pin.text);
     final user=result['user'];
     if(user is! Map || user['role']!='admin'){await backend.logout();throw Exception('Esta cuenta no es administrador.');}
     appState.adminToken=result['token']?.toString();
     if(appState.adminToken==null||appState.adminToken!.isEmpty) throw Exception('Falta sesión de administrador.');
     if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const AdminHome()));
   }catch(e){if(mounted)setState((){tries++;error='No se pudo iniciar sesión. Verifica los datos o la conexión.';});}
   finally{if(mounted)setState(()=>loading=false);}
 }
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Acceso administrador')),body:ListView(padding:const EdgeInsets.all(24),children:[
   const Icon(Icons.lock,size:72),const SizedBox(height:16),const Text('Panel privado de Rafael',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:8),
   Text(AppConfig.hasProductionServer?'Acceso protegido por el servidor. El PIN real no está guardado dentro de la APK.':'Modo demostración: este acceso es solo para pruebas locales.'),const SizedBox(height:16),
   if(AppConfig.hasProductionServer)...[TextField(controller:identity,decoration:const InputDecoration(labelText:'Identidad del administrador',prefixIcon:Icon(Icons.badge))),const SizedBox(height:10)],
   TextField(controller:pin,keyboardType:TextInputType.number,maxLength:6,obscureText:true,decoration:const InputDecoration(labelText:'PIN de 6 dígitos',prefixIcon:Icon(Icons.password))),
   if(error!=null)Padding(padding:const EdgeInsets.only(bottom:10),child:Text(error!,style:TextStyle(color:Theme.of(c).colorScheme.error))),
   FilledButton(onPressed:loading?null:enter,child:Text(loading?'Conectando…':'Entrar')),
   if(tries>=3&&!AppConfig.hasProductionServer)const Padding(padding:EdgeInsets.only(top:12),child:Text('Modo demostración: reinicia esta pantalla para volver a probar.'))
 ]));}

class AccountEntryScreen extends StatelessWidget {
  const AccountEntryScreen({super.key, required this.role});
  final String role;
  @override Widget build(BuildContext context) {
    if (!AppConfig.hasProductionServer) return RegistrationScreen(role: role);
    return Scaffold(
      appBar: AppBar(title: Text(role)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Icon(role == 'Conductor' ? Icons.local_taxi : Icons.person, size: 72),
        const SizedBox(height: 16),
        Text('Acceso de $role', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Si ya tienes cuenta, usa tu acceso guardado en este teléfono. El carnet se solicita al registrar o vincular la cuenta.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(role: role))),
          icon: const Icon(Icons.login), label: const Padding(padding: EdgeInsets.all(12), child: Text('Ya tengo cuenta')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegistrationScreen(role: role))),
          icon: const Icon(Icons.person_add), label: const Padding(padding: EdgeInsets.all(12), child: Text('Crear cuenta nueva')),
        ),
      ]),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});
  final String role;
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final identity = TextEditingController();
  final pin = TextEditingController();
  bool loading = false;
  bool checkingIdentity = true;
  String? rememberedIdentity;
  String? error;
  @override void initState(){super.initState();_loadRememberedIdentity();}
  Future<void> _loadRememberedIdentity() async {
    final role=widget.role=='Conductor'?'driver':'client';
    final saved=await appState.sessionService.rememberedIdentity(role);
    if(!mounted)return;
    setState((){rememberedIdentity=saved;checkingIdentity=false;});
  }
  @override void dispose(){identity.dispose();pin.dispose();super.dispose();}
  Future<void> submit() async {
    final loginIdentity=(rememberedIdentity??identity.text).trim();
    if(loginIdentity.length < 5 || pin.text.length != 6 || int.tryParse(pin.text) == null){
      setState(()=>error=rememberedIdentity==null?'Escribe tu carnet y PIN de 6 dígitos.':'Escribe tu PIN de 6 dígitos.'); return;
    }
    setState((){loading=true;error=null;});
    try {
      final backend=RestRafaelBackend(baseUrl:AppConfig.apiUrl);
      final result=await backend.login(identity:identity.text.trim(),pin:pin.text);
      final user=result['user'];
      if(user is! Map) throw Exception('Respuesta inválida');
      final expected=widget.role=='Conductor'?'driver':'client';
      if(user['role']!=expected){await backend.logout();throw Exception('Rol incorrecto');}
      final token=result['token']?.toString();
      if(token==null||token.isEmpty) throw Exception('Falta sesión');
      final name=user['name']?.toString()??'';
      if(expected=='driver'){
        final vehicle=user['vehicle']?.toString()??'Auto';
        appState.registerDriver(name,loginIdentity,vehicle);
        appState.driverToken=token;
        await appState.persistDriverSession();
        if(mounted) Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const DriverHome()),(r)=>r.isFirst);
      } else {
        appState.registerClient(name,loginIdentity);
        appState.clientToken=token;
        await appState.persistClientSession();
        if(mounted) Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const ClientHome()),(r)=>r.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is RafaelApiException && e.code == 'account_paused') {
        setState(()=>error='Tu cuenta está pausada por el administrador. Contacta a Rafael para reactivarla.');
      } else if (e is RafaelApiException && e.code == 'too_many_attempts') {
        setState(()=>error='Demasiados intentos. Espera unos minutos antes de volver a intentar.');
      } else if (e is RafaelApiException && e.code == 'invalid_credentials') {
        setState(()=>error='Carnet o PIN incorrecto.');
      } else {
        setState(()=>error='No se pudo iniciar sesión. Revisa los datos o la conexión.');
      }
    } finally {if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text('Entrar como ${widget.role}')),
    body:ListView(padding:const EdgeInsets.all(24),children:[
      if(checkingIdentity) const Center(child:CircularProgressIndicator()) else if(rememberedIdentity!=null) ...[
        const Icon(Icons.verified_user,size:54),
        const SizedBox(height:8),
        Text('Cuenta vinculada en este teléfono',textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:6),
        const Text('Entra solamente con tu PIN. No necesitas volver a escribir el carnet.',textAlign:TextAlign.center),
      ] else ...[
        TextField(controller:identity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Carnet de identidad',prefixIcon:Icon(Icons.badge))),
        const SizedBox(height:10),
      ],
      TextField(controller:pin,keyboardType:TextInputType.number,maxLength:6,obscureText:true,decoration:const InputDecoration(labelText:'PIN de 6 dígitos',prefixIcon:Icon(Icons.password))),
      if(error!=null)Padding(padding:const EdgeInsets.only(bottom:10),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      FilledButton(onPressed:loading?null:submit,child:Text(loading?'Entrando…':'Entrar')),
    ]),
  );
}

class RegistrationScreen extends StatefulWidget {const RegistrationScreen({super.key,required this.role});final String role;@override State<RegistrationScreen> createState()=>_RegistrationScreenState();}
class _RegistrationScreenState extends State<RegistrationScreen>{
 final name=TextEditingController();final id=TextEditingController();final pin=TextEditingController();String vehicle='Auto';bool loading=false;XFile? photo;
 Future<void> pickPhoto() async {final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:35,maxWidth:480,maxHeight:480);if(x!=null&&mounted)setState(()=>photo=x);}
 @override void dispose(){name.dispose();id.dispose();pin.dispose();super.dispose();}
 Future<void> submit() async {
   final driver=widget.role=='Conductor';
   if(name.text.trim().length<3||id.text.trim().length<5){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Completa nombre y carnet de identidad.')));return;}
   if(AppConfig.hasProductionServer && (pin.text.length!=6 || int.tryParse(pin.text)==null)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Crea un PIN de 6 dígitos.')));return;}
   setState(()=>loading=true);
   try{
     String? token;
     if(AppConfig.hasProductionServer){
       final backend=RestRafaelBackend(baseUrl:AppConfig.apiUrl);
       await backend.register(name:name.text.trim(),identity:id.text.trim(),role:driver?'driver':'client',pin:pin.text,vehicle:driver?vehicle:null);
       final login=await backend.login(identity:id.text.trim(),pin:pin.text);
       token=login['token']?.toString();
       if(token==null||token.isEmpty)throw Exception('No se recibió sesión');
       if(photo!=null){final bytes=await photo!.readAsBytes();final ext=photo!.name.toLowerCase().endsWith('.png')?'png':'jpeg';final data='data:image/$ext;base64,${base64Encode(bytes)}';await backend.updateProfilePhoto(data);}
     }
     if(driver){appState.registerDriver(name.text,id.text,vehicle);appState.driverToken=token;if(token!=null)await appState.persistDriverSession();if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const DriverHome()));}
     else{appState.registerClient(name.text,id.text);appState.clientToken=token;if(token!=null)await appState.persistClientSession();if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const ClientHome()));}
   }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo crear la cuenta. Revisa la conexión o si el carnet ya está registrado.')));}
   finally{if(mounted)setState(()=>loading=false);}
 }
 @override Widget build(BuildContext c){final driver=widget.role=='Conductor';return Scaffold(appBar:AppBar(title:Text('Registro de ${widget.role}')),body:ListView(padding:const EdgeInsets.all(20),children:[const Text('Tus datos se usan para identificar tu cuenta y mejorar la seguridad del servicio.'),const SizedBox(height:16),Center(child:Column(children:[CircleAvatar(radius:42,child:photo==null?const Icon(Icons.person,size:44):FutureBuilder<List<int>>(future:photo!.readAsBytes(),builder:(c,s)=>s.hasData?ClipOval(child:Image.memory(Uint8List.fromList(s.data!),width:84,height:84,fit:BoxFit.cover)):const Icon(Icons.person,size:44))),TextButton.icon(onPressed:pickPhoto,icon:const Icon(Icons.add_a_photo),label:Text(photo==null?'Agregar foto de perfil':'Cambiar foto'))])),const SizedBox(height:10),TextField(controller:name,decoration:const InputDecoration(labelText:'Nombre y apellidos')),const SizedBox(height:10),TextField(controller:id,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Carnet de identidad')),if(AppConfig.hasProductionServer)...[const SizedBox(height:10),TextField(controller:pin,keyboardType:TextInputType.number,maxLength:6,obscureText:true,decoration:const InputDecoration(labelText:'Crea un PIN de 6 dígitos',prefixIcon:Icon(Icons.password)))],if(driver)...[const SizedBox(height:10),DropdownButtonFormField(value:vehicle,items:['Auto','Moto','Bicitaxi','Triciclo'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>vehicle=v!),decoration:const InputDecoration(labelText:'Tipo de vehículo'))],const SizedBox(height:14),FilledButton(onPressed:loading?null:submit,child:Text(loading?'Creando cuenta…':'Registrarme'))]));}}

class TripCard extends StatelessWidget {const TripCard({super.key,required this.t});final Trip t;
 @override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t.statusText,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Divider(),Text('${t.origin} → ${t.destination}'),Text('${t.vehicle} · Oferta ${t.offer} CUP'),if(t.counterOffer!=null)Text('Contraoferta ${t.counterOffer} CUP')])));}

class ClientHome extends StatefulWidget {const ClientHome({super.key});@override State<ClientHome> createState()=>_ClientHomeState();}
class _ClientHomeState extends State<ClientHome>{String vehicle='Auto';final origin=TextEditingController(text:'Mi ubicación');final dest=TextEditingController();final price=TextEditingController();Timer? poll;bool busy=false;
 @override void initState(){super.initState();appState.addListener(refresh);if(AppConfig.hasProductionServer)poll=Timer.periodic(const Duration(seconds:5),(_)=>syncTrip());}
 @override void dispose(){poll?.cancel();appState.removeListener(refresh);origin.dispose();dest.dispose();price.dispose();super.dispose();}void refresh(){if(mounted)setState((){});}
 Future<void> syncTrip() async {final t=appState.trip;if(t==null||t.id.isEmpty||appState.clientToken==null)return;try{final j=await appState.clientBackend().trip(t.id);appState.trip=tripFromJson(j);appState.notifyListeners();}catch(_){}}
 Future<void> request() async {final p=int.tryParse(price.text);if(dest.text.trim().isEmpty||p==null||p<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Escribe destino y precio.')));return;}final t=Trip(origin:origin.text,destination:dest.text.trim(),vehicle:vehicle,offer:p);if(!AppConfig.hasProductionServer){appState.requestTrip(t);return;}setState(()=>busy=true);try{final id=await appState.clientBackend().createTrip({'origin':t.origin,'destination':t.destination,'vehicle':t.vehicle.toLowerCase().replaceAll(' ',''),'offer':t.offer,'requestId':'${DateTime.now().microsecondsSinceEpoch}'});t.id=id;appState.requestTrip(t);}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo enviar la solicitud. Revisa la conexión.')));}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> acceptCounter() async {final t=appState.trip;if(t==null)return;if(AppConfig.hasProductionServer&&t.id.isNotEmpty){try{await appState.clientBackend().acceptCounterOffer(t.id);await syncTrip();}catch(_){return;}}else appState.accept();}
 Future<void> rejectCounter() async {final t=appState.trip;if(t==null)return;if(AppConfig.hasProductionServer&&t.id.isNotEmpty){try{await appState.clientBackend().rejectCounterOffer(t.id);await syncTrip();}catch(_){return;}}else{t.status=TripStatus.searching;t.counterOffer=null;appState.notifyListeners();}}
 Future<void> cancelTrip() async {final t=appState.trip;if(t!=null&&AppConfig.hasProductionServer&&t.id.isNotEmpty){try{await appState.clientBackend().updateTripStatus(t.id,'cancelled');}catch(_){}}appState.cancel();}
 @override Widget build(BuildContext c){final t=appState.trip;return Scaffold(appBar:AppBar(title:const Text('Cliente')),body:ListView(padding:const EdgeInsets.all(20),children:[const Text('¿A dónde vamos?',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:14),TextField(controller:origin,decoration:const InputDecoration(labelText:'Origen',prefixIcon:Icon(Icons.my_location))),const SizedBox(height:10),TextField(controller:dest,decoration:const InputDecoration(labelText:'Destino',prefixIcon:Icon(Icons.place))),const SizedBox(height:10),DropdownButtonFormField(value:vehicle,items:['Auto','Moto','Bicitaxi','Triciclo'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>vehicle=v!),decoration:const InputDecoration(labelText:'Transporte')),const SizedBox(height:10),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Tu oferta (CUP)',prefixIcon:Icon(Icons.payments))),const SizedBox(height:12),FilledButton(onPressed:busy?null:request,child:Text(busy?'Enviando…':'Buscar conductor')),if(t!=null)...[const SizedBox(height:14),TripCard(t:t),if(t.status==TripStatus.countered)...[FilledButton(onPressed:acceptCounter,child:Text('Aceptar ${t.counterOffer} CUP')),OutlinedButton(onPressed:rejectCounter,child:const Text('Rechazar y seguir buscando'))],if(t.status==TripStatus.arriving||t.status==TripStatus.assigned||t.status==TripStatus.inProgress)
  AppConfig.hasProductionServer && t.id.isNotEmpty && t.driverId.isNotEmpty
    ? DriverTrackingPanel(tracking:LiveTripTrackingService(backend:appState.clientBackend(),location:AndroidLocationTrackingService()),driverId:t.driverId,tripId:t.id)
    : const Card(child:Padding(padding:EdgeInsets.all(18),child:Column(children:[Icon(Icons.map,size:60),Text('Seguimiento del conductor'),Text('El GPS en vivo se activará al conectar el servidor de producción.')]))),if([TripStatus.searching,TripStatus.countered,TripStatus.assigned,TripStatus.arriving].contains(t.status))TextButton(onPressed:cancelTrip,child:const Text('Cancelar viaje'))]]) );}}

class DriverHome extends StatefulWidget {const DriverHome({super.key});@override State<DriverHome> createState()=>_DriverHomeState();}
class _DriverHomeState extends State<DriverHome>{final counter=TextEditingController();Timer? poll;bool syncing=false;@override void initState(){super.initState();appState.addListener(refresh);if(AppConfig.hasProductionServer){appState.syncPaymentSettings(appState.driverBackend()).catchError((_){ });loadInbox();poll=Timer.periodic(const Duration(seconds:5),(_)=>loadInbox());}}@override void dispose(){poll?.cancel();appState.removeListener(refresh);counter.dispose();super.dispose();}void refresh(){if(mounted)setState((){});}
 Future<void> loadInbox() async {if(syncing||appState.driverToken==null)return;syncing=true;try{final rows=await appState.driverBackend().driverInbox();if(rows.isNotEmpty){appState.trip=tripFromJson(rows.first);appState.notifyListeners();}else if(appState.trip?.status!=TripStatus.completed){appState.trip=null;appState.notifyListeners();}}catch(_){}finally{syncing=false;}}
 Future<void> acceptTrip() async {final t=appState.trip;if(t==null)return;if(AppConfig.hasProductionServer&&t.id.isNotEmpty){try{await appState.driverBackend().acceptTrip(t.id,appState.driverId);await loadInbox();}catch(_){}}else appState.accept();}
 Future<void> counterTrip() async {final t=appState.trip;final p=int.tryParse(counter.text);if(t==null||p==null||p<=0)return;if(AppConfig.hasProductionServer&&t.id.isNotEmpty){try{await appState.driverBackend().sendCounterOffer(t.id,p);await loadInbox();}catch(_){}}else appState.counter(p);}
 Future<void> status(String value) async {final t=appState.trip;if(t==null)return;if(AppConfig.hasProductionServer&&t.id.isNotEmpty){try{await appState.driverBackend().updateTripStatus(t.id,value);await loadInbox();}catch(_){}}else{if(value=='arriving')appState.onWay();if(value=='inProgress')appState.start();if(value=='completed')appState.finish();}}
 @override Widget build(BuildContext c){final t=appState.trip;return Scaffold(appBar:AppBar(title:const Text('Conductor')),body:ListView(padding:const EdgeInsets.all(20),children:[const Text('Panel del conductor',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),if(appState.driverRegistered)Card(child:ListTile(leading:const Icon(Icons.person),title:Text(appState.driverName),subtitle:Text('${appState.driverVehicle} · cuenta identificada'))),Card(child:ListTile(leading:Icon(appState.subscriptionValid?Icons.verified:Icons.block),title:Text(AppConfig.hasProductionServer?'Mensualidad controlada por Rafael':(appState.subscriptionValid?'Cuenta activa':'Cuenta pausada')),subtitle:Text('${appState.monthlyFee} CUP / 30 días'))),if(AppConfig.hasProductionServer) DriverSubscriptionPaymentPanel(backend:appState.driverBackend(),amountCup:appState.monthlyFee,card:appState.transfermovilCard),if(!AppConfig.hasProductionServer&&!appState.subscriptionValid)const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Renueva la mensualidad para recibir viajes.')))else if(t==null)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Esperando solicitudes…')))else ...[TripCard(t:t),if(t.status==TripStatus.searching||t.status==TripStatus.countered)...[FilledButton(onPressed:acceptTrip,child:Text('Aceptar ${t.offer} CUP')),const SizedBox(height:8),TextField(controller:counter,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Contraoferta (CUP)')),OutlinedButton(onPressed:counterTrip,child:const Text('Enviar contraoferta'))],if((t.status==TripStatus.assigned||t.status==TripStatus.arriving||t.status==TripStatus.inProgress) && AppConfig.hasProductionServer && t.id.isNotEmpty && appState.driverId.isNotEmpty) DriverGpsSharingPanel(tracking:LiveTripTrackingService(backend:appState.driverBackend(),location:AndroidLocationTrackingService()),driverId:appState.driverId,tripId:t.id),if(t.status==TripStatus.assigned)FilledButton(onPressed:()=>status('arriving'),child:const Text('Voy hacia el cliente')),if(t.status==TripStatus.arriving)FilledButton(onPressed:()=>status('inProgress'),child:const Text('Iniciar viaje')),if(t.status==TripStatus.assigned||t.status==TripStatus.arriving)TextButton(onPressed:()=>status('cancelled'),child:const Text('No puedo realizar este viaje')),if(t.status==TripStatus.inProgress)FilledButton(onPressed:()=>status('completed'),child:const Text('Finalizar viaje'))]]) );}}

class _AdminSummaryGrid extends StatelessWidget {
 const _AdminSummaryGrid({required this.clients,required this.drivers,required this.trips,required this.activeTrips,required this.pendingPayments,required this.grossCup});
 final dynamic clients,drivers,trips,activeTrips,pendingPayments,grossCup;
 Widget tile(IconData icon,String value,String label)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[Icon(icon,size:30),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Text(label)]))])));
 @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,c){final w=c.maxWidth;final columns=w>850?3:w>520?2:1;final item=(w-(columns-1)*8)/columns;final cards=[tile(Icons.people,'$clients','Clientes'),tile(Icons.local_taxi,'$drivers','Conductores'),tile(Icons.route,'$trips','Viajes totales'),tile(Icons.navigation,'$activeTrips','Viajes activos'),tile(Icons.pending_actions,'$pendingPayments','Pagos pendientes'),tile(Icons.payments,'$grossCup CUP','Viajes completados')];return Wrap(spacing:8,runSpacing:8,children:cards.map((x)=>SizedBox(width:item,child:x)).toList());});
}
class AdminHome extends StatefulWidget {const AdminHome({super.key});@override State<AdminHome> createState()=>_AdminHomeState();}
class _AdminHomeState extends State<AdminHome>{
 late final fee=TextEditingController(text:'${appState.monthlyFee}');
 late final card=TextEditingController(text:appState.transfermovilCard);
 Map<String,dynamic>? remoteDashboard; bool loadingRemote=false; String? remoteError;
 @override void initState(){super.initState();appState.addListener(refresh);if(AppConfig.hasProductionServer)loadRemote();}
 @override void dispose(){appState.removeListener(refresh);fee.dispose();card.dispose();super.dispose();}
 void refresh(){if(mounted)setState((){});}
 Future<void> loadRemote() async {if(appState.adminToken==null)return;setState(()=>loadingRemote=true);try{final d=await appState.adminBackend().adminDashboard();if(mounted)setState((){remoteDashboard=d;remoteError=null;});}catch(_){if(mounted)setState(()=>remoteError='No se pudo actualizar el panel del servidor.');}finally{if(mounted)setState(()=>loadingRemote=false);}}
 Future<void> saveRemote() async {final f=int.tryParse(fee.text);if(f==null||f<=0)return;try{if(AppConfig.hasProductionServer){await appState.adminBackend().updateSettings(monthlyFeeCup:f,transfermovilCard:card.text.trim());appState.monthlyFee=f;appState.transfermovilCard=card.text.trim();appState.notifyListeners();await loadRemote();}else{appState.monthlyFee=f;appState.transfermovilCard=card.text.trim();appState.notifyListeners();}if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Configuración guardada.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo guardar en el servidor.')));}}
 @override Widget build(BuildContext c){
  final d=remoteDashboard; final clients=d?['clients']??(appState.clientRegistered?1:0); final drivers=d?['drivers']??(appState.driverRegistered?1:0); final trips=d?['trips']??appState.completedTrips;
  return Scaffold(appBar:AppBar(title:const Text('Administrador'),actions:[if(AppConfig.hasProductionServer)IconButton(tooltip:'Actualizar',onPressed:loadingRemote?null:loadRemote,icon:const Icon(Icons.refresh)),if(AppConfig.hasProductionServer)IconButton(tooltip:'Cerrar sesión',onPressed:() async {try{await appState.adminBackend().logout();}catch(_){}appState.adminToken=null;if(c.mounted)Navigator.of(c).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const RoleScreen()),(r)=>false);},icon:const Icon(Icons.logout))]),body:ListView(padding:const EdgeInsets.all(20),children:[
   const Text('Panel de Rafael',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
   if(AppConfig.hasProductionServer)Card(child:ListTile(leading:Icon(remoteError==null?Icons.cloud_done:Icons.cloud_off),title:Text(remoteError??'Datos del servidor real'),subtitle:Text(loadingRemote?'Actualizando…':'Sesión de administrador protegida'))),
   _AdminSummaryGrid(clients:clients,drivers:drivers,trips:trips,activeTrips:d?['activeTrips']??0,pendingPayments:d?['pendingPayments']??0,grossCup:d?['grossCup']??appState.totalCup),
   if(!AppConfig.hasProductionServer)SwitchListTile(value:appState.driverActive,onChanged:(v){appState.driverActive=v;appState.notifyListeners();},title:const Text('Conductor activo'),subtitle:const Text('Rafael puede pausar la cuenta')),
   TextField(controller:fee,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Mensualidad (CUP)')),const SizedBox(height:8),TextField(controller:card,decoration:const InputDecoration(labelText:'Tarjeta Transfermóvil')),const SizedBox(height:8),FilledButton(onPressed:saveRemote,child:const Text('Guardar')),
   if(!AppConfig.hasProductionServer)OutlinedButton(onPressed:appState.renew,child:const Text('Registrar pago: +30 días')),if(AppConfig.hasProductionServer) AdminSubscriptionPaymentsPanel(backend:appState.adminBackend()),
   if(AppConfig.hasProductionServer) AdminDriversPanel(backend:appState.adminBackend()),
   if(AppConfig.hasProductionServer) AdminClientsPanel(backend:appState.adminBackend()),
   if(AppConfig.hasProductionServer) AdminTripsPanel(backend:appState.adminBackend()),
   if(AppConfig.hasProductionServer) AdminAuditPanel(backend:appState.adminBackend()),
   Card(child:ListTile(leading:const Icon(Icons.payments_outlined),title:Text('${appState.totalCup} CUP'),subtitle:const Text('Valor acumulado local de viajes completados'))),const SizedBox(height:16),
   Text('Historial local (${appState.history.length})',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),if(appState.history.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Aún no hay viajes terminados en este teléfono.')))else ...appState.history.map((t)=>TripCard(t:t)),const SizedBox(height:12),const ConnectionStatusCard(),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Text(AppConfig.hasProductionServer?'Panel conectado: los totales principales se consultan al servidor con la sesión de Rafael.':'Modo local: para sincronizar teléfonos reales debe configurarse RAFAEL_API_URL.')))
  ]));
 }
}

