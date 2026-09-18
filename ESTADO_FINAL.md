# Rafael Móvil Holguín — Estado final

Versión: 1.0.0+72

El código fuente queda cerrado para release. El APK real conectado requiere un backend público HTTPS. El proyecto bloquea la compilación de distribución si falta RAFAEL_API_URL o si /health y /ready no responden.

## Para producir el APK
1. Desplegar la carpeta server/ en un host HTTPS persistente.
2. Definir ADMIN_IDENTITY, ADMIN_PIN, ADMIN_NAME y almacenamiento persistente en el servidor.
3. Configurar RAFAEL_API_URL con la URL HTTPS del backend.
4. Ejecutar el workflow Generar APK Rafael Movil.
5. Instalar el APK en al menos un cliente y un conductor y validar un viaje real antes de distribuirlo ampliamente.
