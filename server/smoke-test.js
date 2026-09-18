const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const port = 18080;
const base = `http://127.0.0.1:${port}`;
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'rafael-movil-test-'));
const dataFile = path.join(tmp, 'data.json');
const adminIdentity = 'admin-test';
const adminPin = '246810';
const child = spawn(process.execPath, ['server.js'], {
  cwd: __dirname,
  env: {...process.env, PORT:String(port), DATA_FILE:dataFile, ADMIN_IDENTITY:adminIdentity, ADMIN_PIN:adminPin, ADMIN_NAME:'Rafael Test'},
  stdio: ['ignore','pipe','pipe']
});
child.stdout.on('data', d => process.stdout.write(d));
child.stderr.on('data', d => process.stderr.write(d));

async function req(method, route, body, token, expected=[200]) {
  const r = await fetch(base+route, {method, headers:{'content-type':'application/json', ...(token?{authorization:`Bearer ${token}`}:{})}, body:body===undefined?undefined:JSON.stringify(body)});
  const text = await r.text();
  let json = null; try { json = text ? JSON.parse(text) : null; } catch {}
  if (!expected.includes(r.status)) throw new Error(`${method} ${route}: ${r.status} ${text}`);
  return json;
}
async function waitReady(){for(let i=0;i<40;i++){try{const r=await fetch(base+'/ready');if(r.ok)return;}catch{} await new Promise(r=>setTimeout(r,100));}throw new Error('server_not_ready');}
async function login(identity,pin){return (await req('POST','/v1/auth/login',{identity,pin},null,[200])).token;}

(async()=>{
  try {
    await waitReady();
    await req('POST','/v1/auth/register',{name:'Cliente Test',identity:'client-test',role:'client',pin:'111111'},null,[201]);
    const driver = await req('POST','/v1/auth/register',{name:'Conductor Test',identity:'driver-test',role:'driver',vehicle:'auto',pin:'222222'},null,[201]);
    const adminToken=await login(adminIdentity,adminPin), clientToken=await login('client-test','111111'), driverToken=await login('driver-test','222222');
    await req('POST',`/v1/drivers/${driver.id}/subscription`,{},adminToken,[200]);
    const pay=await req('POST','/v1/driver/subscription-payment',{reference:'TX-UNICA-001'},driverToken,[201]);
    if(pay.amountCup!==1000 || pay.subscriptionDays!==30) throw new Error('payment_snapshot_failed');
    await req('POST',`/v1/admin/subscription-payments/${pay.id}/review`,{decision:'rejected'},adminToken,[200]);
    await req('POST','/v1/driver/subscription-payment',{reference:'TX-UNICA-001'},driverToken,[409]);
    const trip=await req('POST','/v1/trips',{origin:'Centro',destination:'Loma de la Cruz',vehicle:'auto',offer:500,requestId:'smoke-1'},clientToken,[201]);
    await req('POST',`/v1/trips/${trip.id}/counter-offer`,{cup:600},driverToken,[200]);
    await req('POST',`/v1/trips/${trip.id}/accept-counter`,{},clientToken,[200]);
    await req('PATCH',`/v1/trips/${trip.id}`,{status:'arriving'},driverToken,[200]);
    await req('POST',`/v1/drivers/${driver.id}/location`,{tripId:trip.id,latitude:20.8872,longitude:-76.2631},driverToken,[201]);
    const loc=await req('GET',`/v1/drivers/${driver.id}/location?tripId=${trip.id}`,undefined,clientToken,[200]);
    if (!loc || loc.stale === true) throw new Error('gps_not_fresh');
    await req('PATCH',`/v1/trips/${trip.id}`,{status:'inProgress'},driverToken,[200]);
    await req('PATCH',`/v1/trips/${trip.id}`,{status:'completed'},driverToken,[200]);
    const cancelTrip=await req('POST','/v1/trips',{origin:'Parque Calixto García',destination:'Hospital',vehicle:'auto',offer:450,requestId:'smoke-cancel'},clientToken,[201]);
    await req('POST',`/v1/trips/${cancelTrip.id}/accept`,{driverId:driver.id},driverToken,[200]);
    await req('POST',`/v1/drivers/${driver.id}/location`,{tripId:cancelTrip.id,latitude:20.8872,longitude:-76.2631},driverToken,[201]);
    const cancelled=await req('PATCH',`/v1/trips/${cancelTrip.id}`,{status:'cancelled',cancelReason:'Cambio de planes'},clientToken,[200]);
    if(cancelled.driverId!==null || cancelled.counterOffer!==null || cancelled.cancelReason!=='Cambio de planes') throw new Error('cancel_cleanup_failed');
    await req('GET',`/v1/drivers/${driver.id}/location?tripId=${cancelTrip.id}`,undefined,clientToken,[404]);
    const dash=await req('GET','/v1/admin/dashboard',undefined,adminToken,[200]);
    if (dash.completedTrips !== 1) throw new Error('dashboard_completed_trip_mismatch');
    console.log('SMOKE TEST OK: auth, subscription, payment reference protection, negotiation, trip, GPS, cancellation cleanup and admin dashboard');
  } finally {
    child.kill('SIGTERM');
    setTimeout(()=>{try{fs.rmSync(tmp,{recursive:true,force:true});}catch{}},200);
  }
})().catch(e=>{console.error('SMOKE TEST FAILED:',e);child.kill('SIGTERM');process.exitCode=1;});
