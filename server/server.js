const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const app = express();
if(process.env.TRUST_PROXY==='1') app.set('trust proxy',1);
const allowedOrigins=String(process.env.CORS_ORIGINS||'').split(',').map(x=>x.trim()).filter(Boolean);
app.use(cors({origin:(origin,cb)=>{if(!origin||allowedOrigins.length===0||allowedOrigins.includes(origin))return cb(null,true);return cb(new Error('cors_not_allowed'));}}));
app.use((req,res,next)=>{res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Frame-Options','DENY');res.setHeader('Referrer-Policy','no-referrer');res.setHeader('Cache-Control','no-store');req.requestId=req.headers['x-request-id']||crypto.randomUUID();res.setHeader('X-Request-Id',req.requestId);next();});
app.use(express.json({limit:'512kb'}));
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname,'data.json');
const TOKEN_TTL_MS = 30*24*60*60*1000;
const VEHICLES = new Set(['auto','moto','bicitaxi','triciclo']);
const authAttempts = new Map();
function authRateKey(req){ return `${req.ip}|${String(req.body?.identity||'')}`; }
function authRateLimited(req){ const k=authRateKey(req), t=Date.now(), a=(authAttempts.get(k)||[]).filter(x=>t-x<15*60*1000); authAttempts.set(k,a); return a.length>=8; }
function recordAuthFailure(req){ const k=authRateKey(req), a=authAttempts.get(k)||[]; a.push(Date.now()); authAttempts.set(k,a); }
function clearAuthFailures(req){ authAttempts.delete(authRateKey(req)); }
function pruneSessions(){ const t=Date.now(); for(const [k,v] of Object.entries(db.sessions)) if(Date.parse(v.expiresAt)<t) delete db.sessions[k]; }
function fresh(){return {users:{},sessions:{},trips:{},locations:{},drivers:{},paymentRequests:{},audit:[],settings:{monthlyFeeCup:1000,transfermovilCard:'',subscriptionDays:30}}}
let db=fresh();
try { if(fs.existsSync(DATA_FILE)) db={...fresh(),...JSON.parse(fs.readFileSync(DATA_FILE,'utf8'))}; } catch(e){ console.error('data load failed',e.message); }
function save(){ fs.mkdirSync(path.dirname(DATA_FILE),{recursive:true}); const tmp=DATA_FILE+'.tmp'; fs.writeFileSync(tmp,JSON.stringify(db,null,2)); fs.renameSync(tmp,DATA_FILE); }
function audit(actor,action,details={}){db.audit=db.audit||[];db.audit.push({id:crypto.randomUUID(),at:now(),actorId:actor?.id||null,role:actor?.role||'system',action,details});if(db.audit.length>1000)db.audit=db.audit.slice(-1000);}
const now=()=>new Date().toISOString();
const hash=(s)=>crypto.createHash('sha256').update(String(s)).digest('hex');
function hashPin(pin,salt=crypto.randomBytes(16).toString('hex')){const digest=crypto.pbkdf2Sync(String(pin),salt,120000,32,'sha256').toString('hex');return `pbkdf2$${salt}$${digest}`;}
function verifyPin(pin,stored){if(!stored)return false;if(stored.startsWith('pbkdf2$')){const [,salt,digest]=stored.split('$');const got=crypto.pbkdf2Sync(String(pin),salt,120000,32,'sha256').toString('hex');return crypto.timingSafeEqual(Buffer.from(got,'hex'),Buffer.from(digest,'hex'));}return stored===hash(pin);}
function validPin(pin){return /^\d{6}$/.test(String(pin||''));}
function driverCanWork(id){const d=db.drivers[id];return !!d&&d.active!==false&&!!d.paidUntil&&Date.parse(d.paidUntil)>Date.now();}
function driverBusy(id){return Object.values(db.trips).some(t=>t.driverId===id&&['assigned','arriving','inProgress'].includes(t.status));}
function freshLocation(loc){return !!loc&&Date.now()-Date.parse(loc.updatedAt||loc.capturedAt||0)<=2*60*1000;}
function normVehicle(v){return String(v||'').toLowerCase().replace(/\s+/g,'');}
function validLocation(lat,lng){return Number.isFinite(lat)&&Number.isFinite(lng)&&lat>=-90&&lat<=90&&lng>=-180&&lng<=180;}
function bootstrapAdmin(){const identity=process.env.ADMIN_IDENTITY,pin=process.env.ADMIN_PIN;if(!identity||!pin||!validPin(pin))return;if(Object.values(db.users).some(u=>u.role==='admin'))return;const id=crypto.randomUUID();db.users[id]={id,name:process.env.ADMIN_NAME||'Rafael',identity,role:'admin',vehicle:null,pinHash:hashPin(pin),active:true,createdAt:now()};save();console.log('Admin inicial creado');}
function auth(req,res,next){const h=req.headers.authorization||'';const token=h.startsWith('Bearer ')?h.slice(7):'';const s=db.sessions[hash(token)];if(!s||Date.parse(s.expiresAt)<Date.now())return res.status(401).json({error:'unauthorized'});req.user=db.users[s.userId];if(!req.user)return res.status(401).json({error:'unauthorized'});if(req.user.active===false)return res.status(403).json({error:'account_paused'});req.user.lastSeenAt=now();next();}
function role(...roles){return (req,res,next)=>roles.includes(req.user.role)?next():res.status(403).json({error:'forbidden'});}
function publicUser(u){const {pinHash,...safe}=u;return safe;}
app.get('/health',(_,res)=>res.json({ok:true,service:'rafael-movil-api',time:now()}));
app.get('/ready',(_,res)=>{try{fs.mkdirSync(path.dirname(DATA_FILE),{recursive:true});fs.accessSync(path.dirname(DATA_FILE),fs.constants.W_OK);res.json({ok:true});}catch(e){res.status(503).json({ok:false,error:'storage_not_writable'});}});
app.post('/v1/auth/register',(req,res)=>{const {name,identity,phone,role:requestedRole,vehicle,pin}=req.body;const r=requestedRole||'client';const normalizedVehicle=normVehicle(vehicle);if(!name||!identity||!validPin(pin)||!['client','driver'].includes(r)||(r==='driver'&&!VEHICLES.has(normalizedVehicle)))return res.status(400).json({error:'invalid_fields'});if(Object.values(db.users).some(u=>u.identity===identity))return res.status(409).json({error:'identity_exists'});const id=crypto.randomUUID();const u={id,name,identity,phone:String(phone||'').trim().slice(0,30),role:r,vehicle:r==='driver'?normalizedVehicle:null,pinHash:hashPin(pin),active:true,createdAt:now(),lastSeenAt:now()};db.users[id]=u;if(r==='driver')db.drivers[id]={id,active:true,paidUntil:null};save();res.status(201).json(publicUser(u));});
app.post('/v1/auth/login',(req,res)=>{if(authRateLimited(req))return res.status(429).json({error:'too_many_attempts'});const {identity,pin}=req.body;const u=Object.values(db.users).find(x=>x.identity===identity);if(!u||!verifyPin(pin,u.pinHash)){recordAuthFailure(req);return res.status(401).json({error:'invalid_credentials'});}if(u.active===false)return res.status(403).json({error:'account_paused'});clearAuthFailures(req);pruneSessions();const token=crypto.randomBytes(32).toString('hex');db.sessions[hash(token)]={userId:u.id,expiresAt:new Date(Date.now()+TOKEN_TTL_MS).toISOString()};save();res.json({token,user:publicUser(u)});});
app.get('/v1/me',auth,(req,res)=>res.json(publicUser(req.user)));
app.patch('/v1/me/profile-photo',auth,(req,res)=>{const photo=String(req.body.photoData||'');if(photo&&!/^data:image\/(jpeg|png|webp);base64,/.test(photo))return res.status(400).json({error:'invalid_photo'});if(photo.length>450000)return res.status(413).json({error:'photo_too_large'});req.user.photoUrl=photo.slice(0,450000);audit(req.user,'profile_photo_updated');save();res.json(publicUser(req.user));});
app.post('/v1/auth/logout',auth,(req,res)=>{const h=req.headers.authorization||'';const token=h.startsWith('Bearer ')?h.slice(7):'';delete db.sessions[hash(token)];save();res.status(204).end();});
app.get('/v1/settings',auth,(req,res)=>res.json(db.settings));
app.put('/v1/settings',auth,role('admin'),(req,res)=>{const before={...db.settings};const next={...db.settings};if(Number.isFinite(Number(req.body.monthlyFeeCup))&&Number(req.body.monthlyFeeCup)>0)next.monthlyFeeCup=Math.round(Number(req.body.monthlyFeeCup));if(Number.isInteger(Number(req.body.subscriptionDays))&&Number(req.body.subscriptionDays)>=1&&Number(req.body.subscriptionDays)<=365)next.subscriptionDays=Number(req.body.subscriptionDays);if(typeof req.body.transfermovilCard==='string')next.transfermovilCard=req.body.transfermovilCard.trim().slice(0,80);db.settings=next;audit(req.user,'settings_updated',{before,after:next});save();res.json(db.settings);});
app.post('/v1/drivers/:id/subscription',auth,role('admin'),(req,res)=>{const id=req.params.id;if(!db.drivers[id])return res.status(404).json({error:'not_found'});db.drivers[id]={...db.drivers[id],active:true,paidUntil:new Date(Date.now()+db.settings.subscriptionDays*86400000).toISOString()};audit(req.user,'subscription_renewed',{driverId:id,paidUntil:db.drivers[id].paidUntil});save();res.json(db.drivers[id]);});
app.post('/v1/driver/subscription-payment',auth,role('driver'),(req,res)=>{
  const reference=String(req.body.reference||'').trim().slice(0,100);
  if(reference.length<4)return res.status(400).json({error:'invalid_reference'});
  const payments=Object.values(db.paymentRequests||{});
  const pending=payments.find(p=>p.driverId===req.user.id&&p.status==='pending');
  if(pending)return res.status(409).json({error:'payment_already_pending',payment:pending});
  const duplicate=payments.find(p=>String(p.reference||'').toLowerCase()===reference.toLowerCase());
  if(duplicate)return res.status(409).json({error:'payment_reference_used'});
  const id=crypto.randomUUID();
  const payment={id,driverId:req.user.id,reference,amountCup:db.settings.monthlyFeeCup,subscriptionDays:db.settings.subscriptionDays,status:'pending',createdAt:now(),reviewedAt:null,reviewedBy:null};
  db.paymentRequests[id]=payment;audit(req.user,'subscription_payment_submitted',{paymentId:id,reference});save();res.status(201).json(payment);
});
app.get('/v1/driver/subscription-payment',auth,role('driver'),(req,res)=>{
  const data=Object.values(db.paymentRequests||{}).filter(p=>p.driverId===req.user.id).sort((a,b)=>String(b.createdAt).localeCompare(String(a.createdAt)));res.json(data.slice(0,20));
});
app.get('/v1/admin/subscription-payments',auth,role('admin'),(req,res)=>{
  let data=Object.values(db.paymentRequests||{});const status=String(req.query.status||'').trim();if(status)data=data.filter(p=>p.status===status);
  res.json(data.sort((a,b)=>String(b.createdAt).localeCompare(String(a.createdAt))).slice(0,100).map(p=>({...p,driverName:db.users[p.driverId]?.name||'Conductor'})));
});
app.post('/v1/admin/subscription-payments/:id/review',auth,role('admin'),(req,res)=>{
  const p=db.paymentRequests?.[req.params.id];if(!p)return res.status(404).json({error:'not_found'});if(p.status!=='pending')return res.status(409).json({error:'already_reviewed'});
  const decision=String(req.body.decision||'');if(!['approved','rejected'].includes(decision))return res.status(400).json({error:'invalid_decision'});
  p.status=decision;p.reviewedAt=now();p.reviewedBy=req.user.id;if(decision==='approved'&&!p.receiptNumber)p.receiptNumber='RMH-'+new Date().toISOString().slice(0,10).replace(/-/g,'')+'-'+p.id.replace(/-/g,'').slice(0,8).toUpperCase();
  if(decision==='approved'){const current=db.drivers[p.driverId]||{id:p.driverId};const base=current.paidUntil&&Date.parse(current.paidUntil)>Date.now()?Date.parse(current.paidUntil):Date.now();current.active=true;current.paidUntil=new Date(base+(Number(p.subscriptionDays)||db.settings.subscriptionDays)*86400000).toISOString();db.drivers[p.driverId]=current;}
  audit(req.user,'subscription_payment_reviewed',{paymentId:p.id,driverId:p.driverId,decision});save();res.json({payment:p,subscription:db.drivers[p.driverId]||null});
});
app.patch('/v1/drivers/:id',auth,role('admin'),(req,res)=>{const id=req.params.id;if(!db.drivers[id])return res.status(404).json({error:'not_found'});const allowed={};if(typeof req.body.active==='boolean')allowed.active=req.body.active;db.drivers[id]={...db.drivers[id],...allowed,id};audit(req.user,'driver_updated',{driverId:id,changes:allowed});save();res.json(db.drivers[id]);});
app.post('/v1/trips',auth,role('client'),(req,res)=>{const {origin,destination,vehicle,offer,requestId}=req.body;const v=normVehicle(vehicle);const nOffer=Number(offer);if(!origin||!destination||!VEHICLES.has(v)||!Number.isFinite(nOffer)||nOffer<=0||nOffer>1000000)return res.status(400).json({error:'missing_fields'});if(requestId){const prior=Object.values(db.trips).find(t=>t.clientId===req.user.id&&t.requestId===String(requestId));if(prior)return res.status(200).json(prior);}const t={id:crypto.randomUUID(),requestId:requestId?String(requestId).slice(0,100):null,origin,destination,vehicle:v,offer:nOffer,clientId:req.user.id,status:'searching',counterOffer:null,driverId:null,createdAt:now(),updatedAt:now()};db.trips[t.id]=t;save();res.status(201).json(t);});
app.get('/v1/trips',auth,(req,res)=>{
  let trips=Object.values(db.trips);
  if(req.user.role==='client') trips=trips.filter(t=>t.clientId===req.user.id);
  else if(req.user.role==='driver') trips=trips.filter(t=>t.driverId===req.user.id);
  const status=String(req.query.status||'').trim();
  if(status) trips=trips.filter(t=>t.status===status);
  const limit=Math.min(Math.max(Number(req.query.limit)||50,1),100);
  trips.sort((a,b)=>String(b.updatedAt||b.createdAt).localeCompare(String(a.updatedAt||a.createdAt)));
  res.json(trips.slice(0,limit));
});

app.get('/v1/trips/:id',auth,(req,res)=>{const t=db.trips[req.params.id];if(!t)return res.status(404).json({error:'not_found'});if(req.user.role==='client'&&t.clientId!==req.user.id)return res.status(403).json({error:'forbidden'});if(req.user.role==='driver'&&t.driverId&&t.driverId!==req.user.id)return res.status(403).json({error:'forbidden'});res.json(t);});
app.post('/v1/trips/:id/counter-offer',auth,role('driver'),(req,res)=>{if(!driverCanWork(req.user.id))return res.status(403).json({error:'subscription_required'});const t=db.trips[req.params.id];if(!t)return res.status(404).json({error:'not_found'});if(t.status!=='searching'&&!(t.status==='countered'&&t.driverId===req.user.id))return res.status(409).json({error:'trip_unavailable'});if(driverBusy(req.user.id)&&t.driverId!==req.user.id)return res.status(409).json({error:'driver_busy'});if(normVehicle(req.user.vehicle)!==t.vehicle)return res.status(409).json({error:'vehicle_mismatch'});const cup=Number(req.body.cup);if(!Number.isFinite(cup)||cup<=0)return res.status(400).json({error:'invalid_offer'});return updateTrip(req,res,{status:'countered',counterOffer:cup,driverId:req.user.id});});
app.post('/v1/trips/:id/accept',auth,role('driver'),(req,res)=>{if(!driverCanWork(req.user.id))return res.status(403).json({error:'subscription_required'});const t=db.trips[req.params.id];if(!t)return res.status(404).json({error:'not_found'});if(t.status!=='searching')return res.status(409).json({error:'trip_unavailable'});if(driverBusy(req.user.id))return res.status(409).json({error:'driver_busy'});if(normVehicle(req.user.vehicle)!==t.vehicle)return res.status(409).json({error:'vehicle_mismatch'});return updateTrip(req,res,{status:'assigned',driverId:req.user.id});});
app.post('/v1/trips/:id/accept-counter',auth,role('client'),(req,res)=>{const t=db.trips[req.params.id];if(!t||t.clientId!==req.user.id)return res.status(t?403:404).json({error:t?'forbidden':'not_found'});if(t.status!=='countered'||!t.driverId||!t.counterOffer)return res.status(409).json({error:'no_counter_offer'});return updateTrip(req,res,{status:'assigned',offer:t.counterOffer,counterOffer:null});});
app.post('/v1/trips/:id/reject-counter',auth,role('client'),(req,res)=>{const t=db.trips[req.params.id];if(!t||t.clientId!==req.user.id)return res.status(t?403:404).json({error:t?'forbidden':'not_found'});if(t.status!=='countered')return res.status(409).json({error:'no_counter_offer'});return updateTrip(req,res,{status:'searching',counterOffer:null,driverId:null});});
app.patch('/v1/trips/:id',auth,(req,res)=>{
  const t=db.trips[req.params.id]; if(!t)return res.status(404).json({error:'not_found'});
  const target=String(req.body.status||'');
  const cancelReason=typeof req.body.cancelReason==='string'?req.body.cancelReason.trim().slice(0,160):null;
  const allowed={
    client:{searching:['cancelled'],countered:['cancelled'],assigned:['cancelled'],arriving:['cancelled']},
    driver:{assigned:['arriving','cancelled'],arriving:['inProgress','cancelled'],inProgress:['completed']},
    admin:{searching:['cancelled'],countered:['cancelled'],assigned:['cancelled'],arriving:['cancelled'],inProgress:['cancelled']}
  };
  if(req.user.role==='client'&&t.clientId!==req.user.id)return res.status(403).json({error:'forbidden'});
  if(req.user.role==='driver'&&t.driverId!==req.user.id)return res.status(403).json({error:'forbidden'});
  if(!(allowed[req.user.role]?.[t.status]||[]).includes(target))return res.status(409).json({error:'invalid_transition',from:t.status,to:target});
  if(target==='completed'){
    return updateTrip(req,res,{status:target,finalPrice:Number(t.offer)||0,completedAt:now()});
  }
  if(target==='cancelled'){
    const who=req.user.role==='admin'?'el administrador':req.user.role==='driver'?'el conductor':'el cliente';
    const reason=cancelReason||(`Cancelado por ${who}`);
    const oldDriverId=t.driverId;
    const response=updateTrip(req,res,{status:target,cancelReason:reason,counterOffer:null,driverId:null});
    if(oldDriverId&&db.locations[oldDriverId]?.tripId===t.id){delete db.locations[oldDriverId];save();}
    return response;
  }
  return updateTrip(req,res,{status:target});
});
function updateTrip(req,res,patch){const t=db.trips[req.params.id];if(!t)return res.status(404).json({error:'not_found'});if(req.user.role==='client'&&t.clientId!==req.user.id)return res.status(403).json({error:'forbidden'});if(req.user.role==='driver'&&t.driverId&&t.driverId!==req.user.id)return res.status(403).json({error:'forbidden'});const next={...t,...patch,updatedAt:now()};db.trips[t.id]=next;audit(req.user,'trip_updated',{tripId:t.id,from:t.status,to:next.status,driverId:next.driverId||null});save();res.json(next);}
app.post('/v1/drivers/:id/location',auth,role('driver'),(req,res)=>{if(req.params.id!==req.user.id)return res.status(403).json({error:'forbidden'});const {latitude,longitude,tripId,capturedAt}=req.body;if(!validLocation(latitude,longitude))return res.status(400).json({error:'invalid_location'});if(tripId){const t=db.trips[tripId];if(!t||t.driverId!==req.user.id||!['assigned','arriving','inProgress'].includes(t.status))return res.status(409).json({error:'trip_not_active'});}const loc={userId:req.user.id,latitude,longitude,tripId:tripId||null,capturedAt:capturedAt||now(),updatedAt:now()};db.locations[req.user.id]=loc;save();res.status(201).json(loc);});
app.get('/v1/drivers/:id/location',auth,(req,res)=>{
  const driverId=req.params.id; const loc=db.locations[driverId];
  if(!loc)return res.status(404).json({error:'not_found'});
  if(!freshLocation(loc))return res.status(410).json({error:'location_stale'});
  if(req.user.role==='driver'&&req.user.id!==driverId)return res.status(403).json({error:'forbidden'});
  if(req.user.role==='client'){
    const trip=loc.tripId?db.trips[loc.tripId]:null;
    if(!trip||trip.clientId!==req.user.id||trip.driverId!==driverId||!['assigned','arriving','inProgress'].includes(trip.status))return res.status(403).json({error:'forbidden'});
  }
  res.json(loc);
});
app.get('/v1/drivers/available',auth,role('client','admin'),(req,res)=>{
  const vehicle=normVehicle(req.query.vehicle||'');
  const users=Object.values(db.users).filter(u=>u.role==='driver'&&u.active!==false&&driverCanWork(u.id)&&!driverBusy(u.id));
  const data=users.filter(u=>!vehicle||u.vehicle===vehicle).map(u=>({id:u.id,name:u.name,vehicle:u.vehicle,location:freshLocation(db.locations[u.id])?db.locations[u.id]:null}));
  res.json(data);
});
app.get('/v1/driver/inbox',auth,role('driver'),(req,res)=>{
  if(!driverCanWork(req.user.id))return res.status(403).json({error:'subscription_required'});
  if(driverBusy(req.user.id))return res.json(Object.values(db.trips).filter(t=>t.driverId===req.user.id&&!['completed','cancelled'].includes(t.status)));
  const data=Object.values(db.trips).filter(t=>t.vehicle===normVehicle(req.user.vehicle)&&(t.status==='searching'||t.driverId===req.user.id));
  res.json(data);
});
app.get('/v1/admin/drivers',auth,role('admin'),(req,res)=>{
  const data=Object.values(db.users).filter(u=>u.role==='driver').map(u=>{const loc=db.locations[u.id];const online=freshLocation(loc);return {...publicUser(u),subscription:db.drivers[u.id]||null,busy:driverBusy(u.id),online,availability:online?(driverBusy(u.id)?'busy':'available'):'offline',location:online?loc:null};});
  res.json(data);
});
app.get('/v1/admin/clients',auth,role('admin'),(req,res)=>{
  const q=String(req.query.q||'').trim().toLowerCase().slice(0,80);
  let data=Object.values(db.users).filter(u=>u.role==='client').map(u=>{const seen=Date.parse(u.lastSeenAt||0);const online=Number.isFinite(seen)&&Date.now()-seen<=2*60*1000;return {...publicUser(u),online,trips:Object.values(db.trips).filter(t=>t.clientId===u.id).length};});
  if(q)data=data.filter(u=>String(u.name||'').toLowerCase().includes(q)||String(u.identity||'').toLowerCase().includes(q));
  res.json(data.slice(0,100));
});
app.patch('/v1/admin/clients/:id',auth,role('admin'),(req,res)=>{
  const u=db.users[req.params.id];if(!u||u.role!=='client')return res.status(404).json({error:'not_found'});
  if(typeof req.body.active!=='boolean')return res.status(400).json({error:'invalid_fields'});
  u.active=req.body.active;audit(req.user,'client_updated',{clientId:u.id,active:u.active});save();res.json(publicUser(u));
});
app.delete('/v1/admin/trips/:id',auth,role('admin'),(req,res)=>{
  const t=db.trips[req.params.id];
  if(!t)return res.status(404).json({error:'not_found'});
  if(!['completed','cancelled'].includes(t.status))return res.status(409).json({error:'trip_active'});
  const snapshot={tripId:t.id,status:t.status,clientId:t.clientId,driverId:t.driverId||null,createdAt:t.createdAt,updatedAt:t.updatedAt};
  delete db.trips[t.id];
  audit(req.user,'trip_deleted',snapshot);
  save();
  res.json({ok:true,id:req.params.id});
});
app.get('/v1/admin/audit',auth,role('admin'),(req,res)=>{
  const limit=Math.min(Math.max(Number(req.query.limit)||50,1),200);
  const action=String(req.query.action||'').trim();
  const actorRole=String(req.query.role||'').trim();
  const q=String(req.query.q||'').trim().toLowerCase().slice(0,80);
  let rows=(db.audit||[]);
  if(action) rows=rows.filter(e=>e.action===action);
  if(actorRole) rows=rows.filter(e=>e.role===actorRole);
  if(q) rows=rows.filter(e=>JSON.stringify(e).toLowerCase().includes(q));
  res.json(rows.slice(-limit).reverse());
});
app.get('/v1/changes',auth,(req,res)=>{
  const sinceRaw=String(req.query.since||'').trim();
  const since=sinceRaw&&Number.isFinite(Date.parse(sinceRaw))?Date.parse(sinceRaw):0;
  let trips=Object.values(db.trips).filter(t=>Date.parse(t.updatedAt||t.createdAt)>since);
  if(req.user.role==='client') trips=trips.filter(t=>t.clientId===req.user.id);
  else if(req.user.role==='driver') trips=trips.filter(t=>t.driverId===req.user.id||(t.status==='searching'&&t.vehicle===normVehicle(req.user.vehicle)));
  const payload={serverTime:now(),trips:trips.slice(-50)};
  if(req.user.role==='driver'){
    const loc=db.locations[req.user.id];
    payload.subscription=db.drivers[req.user.id]||null;
    payload.locationFresh=freshLocation(loc);
  }
  res.json(payload);
});

app.get('/v1/admin/dashboard',auth,role('admin'),(_,res)=>{
  const trips=Object.values(db.trips), drivers=Object.values(db.drivers), users=Object.values(db.users);
  const completed=trips.filter(t=>t.status==='completed');
  const grossCup=completed.reduce((sum,t)=>sum+Number(t.finalPrice??t.offer??0),0);
  const pendingPayments=Object.values(db.paymentRequests||{}).filter(p=>p.status==='pending').length;
  const activeTrips=trips.filter(t=>!['completed','cancelled'].includes(t.status)).length;
  res.json({clients:users.filter(u=>u.role==='client').length,drivers:users.filter(u=>u.role==='driver').length,activeDrivers:drivers.filter(d=>d.active!==false&&d.paidUntil&&Date.parse(d.paidUntil)>Date.now()).length,trips:trips.length,activeTrips,completedTrips:completed.length,grossCup,pendingPayments,monthlyFeeCup:db.settings.monthlyFeeCup});
});
bootstrapAdmin();
const port=process.env.PORT||8080;
const server=app.listen(port,()=>console.log(`Rafael Movil API on :${port}`));
function shutdown(signal){console.log(`${signal}: cerrando servidor`);server.close(()=>process.exit(0));setTimeout(()=>process.exit(1),10000).unref();}
process.on('SIGTERM',()=>shutdown('SIGTERM'));
process.on('SIGINT',()=>shutdown('SIGINT'));

