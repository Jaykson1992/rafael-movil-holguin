from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
required=[
 'pubspec.yaml','lib/main.dart','lib/services/rest_backend_service.dart',
 'server/server.js','server/package.json','server/smoke-test.js',
 '.github/workflows/build-apk.yml','test/app_state_test.dart'
]
missing=[x for x in required if not (root/x).exists()]
if missing:
 print('FALTAN ARCHIVOS CRITICOS:', ', '.join(missing)); sys.exit(1)
pub=(root/'pubspec.yaml').read_text()
if 'version: 1.0.0+72' not in pub:
 print('VERSION INCORRECTA: se esperaba 1.0.0+72'); sys.exit(1)
server=(root/'server/server.js').read_text()
for marker in ['/health','/ready','/v1/auth/login','/v1/auth/register','/v1/trips','/v1/admin/dashboard','/v1/driver/subscription-payment']:
 if marker not in server:
  print('CONTRATO DE SERVIDOR INCOMPLETO:', marker); sys.exit(1)
print('Rafael Movil FINAL: verificacion previa OK')
