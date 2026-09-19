from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
required=[
 'pubspec.yaml','lib/main.dart','lib/services/rest_backend_service.dart',
 'lib/widgets/admin_drivers_panel.dart','lib/widgets/admin_clients_panel.dart',
 'server/server.js','server/package.json','server/smoke-test.js','server/DEPLOY_PUBLICO.md','render.yaml',
 '.github/workflows/build-apk.yml','test/app_state_test.dart'
]
missing=[x for x in required if not (root/x).exists()]
if missing:
 print('FALTAN ARCHIVOS CRITICOS:', ', '.join(missing)); sys.exit(1)
pub=(root/'pubspec.yaml').read_text()
if 'version: 1.0.0+83' not in pub:
 print('VERSION INCORRECTA: se esperaba 1.0.0+83'); sys.exit(1)
server=(root/'server/server.js').read_text()
for marker in ['/health','/ready','/v1/auth/login','/v1/auth/register','/v1/trips','/v1/admin/dashboard','/v1/driver/subscription-payment']:
 if marker not in server:
  print('CONTRATO DE SERVIDOR INCOMPLETO:', marker); sys.exit(1)
for marker in ["'moto'", 'profile-photo', 'receiptNumber', 'payment_reference_used']:
 if marker not in server:
  print('FUNCION FINAL FALTANTE:', marker); sys.exit(1)
main=(root/'lib/main.dart').read_text()
for marker in ["'Moto'", 'ImagePicker', 'Panel privado de Rafael']:
 if marker not in main:
  print('INTERFAZ FINAL FALTANTE:', marker); sys.exit(1)
workflow=(root/'.github/workflows/build-apk.yml').read_text()
for marker in ['RAFAEL_API_URL', 'https://*', 'flutter analyze', 'flutter test']:
 if marker not in workflow:
  print('PIPELINE FINAL INCOMPLETO:', marker); sys.exit(1)
if (root/'server/.env').exists():
 print('SEGURIDAD: no incluyas server/.env dentro del paquete final'); sys.exit(1)
print('Rafael Movil FINAL build 83: verificacion previa OK')
