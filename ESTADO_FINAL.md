# Rafael Móvil Holguín — Estado final

Versión actual: 1.0.0+81

El código fuente queda cerrado para release. El APK real conectado requiere un backend público HTTPS. El proyecto bloquea la compilación de distribución si falta RAFAEL_API_URL o si /health y /ready no responden.

## Para producir el APK
1. Desplegar la carpeta server/ en un host HTTPS persistente.
2. Definir ADMIN_IDENTITY, ADMIN_PIN, ADMIN_NAME y almacenamiento persistente en el servidor.
3. Configurar RAFAEL_API_URL con la URL HTTPS del backend.
4. Ejecutar el workflow Generar APK Rafael Movil.
5. Instalar el APK en al menos un cliente y un conductor y validar un viaje real antes de distribuirlo ampliamente.


## Actualización FINAL v4
- Registro con foto de perfil opcional para clientes y conductores.
- La foto queda disponible únicamente en los paneles autorizados que reciben el perfil.
- Moto permanece incluida como tipo de vehículo.
- Preflight actualizado a build +74.


## FINAL v5 / build 75
- Fotos de perfil de clientes y conductores visibles solamente en sus áreas autorizadas y en el panel de Rafael.
- Vehículos: Auto, Moto, Bicitaxi y Triciclo.
- Mensualidad: el conductor reporta referencia; Rafael aprueba o rechaza; al aprobar se genera recibo RMH y se extiende la vigencia.
- Panel administrativo con bloqueo/reactivación de clientes, activación de conductores y renovación manual.
- Documentación de estado actualizada para no confundir funciones ya implementadas con pendientes de despliegue.
- Build incrementado a 75 y preflight sincronizado.


## FINAL v6 — build 76
- Proyecto alineado a `1.0.0+76`.
- Pipeline de APK mantiene la protección: solo compila distribución con `RAFAEL_API_URL` HTTPS y servidor `/health` + `/ready` operativo.
- Confirmados perfiles con foto para clientes/conductores, vehículo Moto y recibos de mensualidad.
- Documentación del backend corregida para reflejar el almacenamiento persistente y la autenticación actuales.


## FINAL v7 — build 77
- Se añadió `server/DEPLOY_PUBLICO.md` con el procedimiento de publicación HTTPS, secretos y almacenamiento persistente.
- El workflow de GitHub valida `/health` y `/ready` antes de compilar el APK conectado.
- Build sincronizado a `1.0.0+77`.


## FINAL v8 — build 78
- Build sincronizado a `1.0.0+78`.
- Corregido el mensaje de error del preflight para que reporte exactamente la versión esperada.
- Workflow de GitHub alineado a build 78 y mantiene pruebas del servidor, análisis y pruebas Flutter antes de compilar.
- El APK de distribución continúa bloqueado hasta configurar una `RAFAEL_API_URL` HTTPS que responda `/health` y `/ready`.


## FINAL v9 — build 80
- Preflight reforzado: comprueba Moto, fotos de perfil, recibos/referencias de pago, archivos críticos y pipeline HTTPS.
- Protección adicional: el preflight falla si por error se empaqueta `server/.env` con secretos.
- Workflow sincronizado a build 80.
- La compilación release sigue exigiendo servidor HTTPS operativo antes de crear el APK de distribución.


## FINAL v11 — build 81
- Añadido `render.yaml` para desplegar el backend como servicio Docker con disco persistente en `/data`.
- `ADMIN_IDENTITY` y `ADMIN_PIN` quedan como secretos del proveedor y no se incluyen en el APK ni en Git.
- El pipeline mantiene la comprobación HTTPS de `/health` y `/ready` antes de compilar el APK de distribución.
