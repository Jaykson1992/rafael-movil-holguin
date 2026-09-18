# Rafael Móvil V50 — distribución directa en Cuba

La aplicación puede entregarse como APK directamente a Rafael y a sus usuarios; Google Play no es obligatorio.

## Dos modos de compilación

1. **Demostración/local**: `flutter build apk --release`
   - Sirve para revisar pantallas y flujo local.
   - No sincroniza teléfonos diferentes por Internet.

2. **Conectada**: `flutter build apk --release --dart-define=RAFAEL_API_URL=https://TU-SERVIDOR`
   - Cliente, Conductor y Administrador usan el mismo servidor.
   - Habilita autenticación remota, viajes, pagos, administración y GPS compartido.

## Antes de distribuir

- Publicar la carpeta `server/` en un servidor HTTPS estable.
- Configurar `ADMIN_IDENTITY`, `ADMIN_PIN` y `ADMIN_NAME` en el servidor; no poner el PIN real dentro de la APK.
- Mantener almacenamiento persistente para `DATA_FILE`.
- Compilar la APK con la URL HTTPS pública del servidor.
- Probar al menos con dos teléfonos Android en redes diferentes antes de distribución general.

## Instalación directa

Rafael puede compartir `app-release.apk` por el medio que prefiera. En Android, cada usuario debe autorizar la instalación desde la aplicación que abrió el APK cuando el sistema lo solicite.
