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


### V54
Esta entrega corresponde a Rafael Móvil Holguín 0.54.0+54. Conservar el ZIP como fuente y distribuir a usuarios finales únicamente el APK release generado por el flujo de compilación.


### V55
Entrega de continuidad 0.55.0+55. El flujo automático verifica V55 antes de ejecutar las pruebas y compilar el APK.


### Seguridad V56
Las cuentas que Rafael pause o bloquee no pueden iniciar una sesión nueva hasta que él las reactive. Esto aplica tanto a clientes como a conductores y evita entregar tokens nuevos a cuentas suspendidas.


### V58
Las cuentas pausadas por Rafael quedan bloqueadas desde el login y la app informa claramente al usuario que debe contactar al administrador para reactivación.


## Cambios V58
- El panel del conductor carga del servidor el precio vigente de la mensualidad y la tarjeta de Transfermóvil.
- Cuando Rafael cambia el precio o la tarjeta en Administración, el estado local se actualiza inmediatamente.
- Esto evita mostrar datos de pago antiguos al conductor después de una modificación administrativa.


## Cambios V60
- Base actualizada a `0.61.0+61`.
- El cliente ahora puede rechazar una contraoferta del conductor sin cancelar el viaje.
- Al rechazarla, la solicitud vuelve a estado de búsqueda y queda disponible nuevamente para conductores compatibles.
- Se mantiene la opción de aceptar la contraoferta y asignar el viaje.
- Preflight actualizado para V60.


## Cambios V60
- El cliente puede cancelar correctamente un viaje mientras busca conductor, durante una contraoferta, cuando ya fue asignado o mientras el conductor va en camino.
- Una vez iniciado el viaje, se oculta la cancelación normal para evitar que el teléfono muestre un estado distinto al servidor.
- Se corrigió la coherencia entre la interfaz y las reglas del backend para cancelaciones.


## Cambios V61
- Al cancelar un viaje se libera inmediatamente el conductor asignado.
- Se limpia la ubicación GPS asociada al viaje cancelado para evitar seguimiento residual.
- Se conserva el motivo de cancelación y se elimina cualquier contraoferta pendiente.
- Smoke test ampliado para comprobar la limpieza de cancelaciones.


## Cambios V62 — pagos más seguros
- Cada referencia de transferencia solo puede reportarse una vez, evitando reutilizar el mismo comprobante.
- Al reportar el pago se guarda una copia del precio y de los días de mensualidad vigentes en ese momento.
- Si Rafael cambia después el precio o la duración, una solicitud ya enviada conserva las condiciones con las que fue reportada.
- Smoke test ampliado para comprobar la protección contra referencias repetidas.


## Cambios V63 — cancelación del conductor antes de iniciar
- El conductor puede cancelar un viaje que ya aceptó mientras todavía está asignado o va camino al cliente.
- Al cancelar, el servidor libera el viaje y elimina el GPS asociado para evitar seguimiento residual.
- Una vez iniciado el viaje, el conductor debe finalizarlo normalmente; la cancelación administrativa sigue disponible para incidencias.


## Cambios V64
- Los viajes completados guardan `finalPrice` y `completedAt` en el servidor.
- El panel del administrador calcula correctamente el total CUP de viajes completados, incluyendo viajes antiguos que solo tengan `offer`.
- Versión interna: 0.64.0+64.


## Cambios V65 — verificación de compilación alineada
- Se corrigió el preflight que todavía esperaba V63.
- El preflight ahora exige la versión interna 0.65.0+65 antes de compilar.
- Se mantiene la comprobación de archivos críticos y del contrato básico del servidor.
- Esto evita generar un APK desde una versión equivocada por una validación desactualizada.


## Cambios V66 — pagos más claros para Rafael

- El panel de administración muestra el nombre del conductor en cada solicitud de mensualidad cuando está disponible.
- El historial del conductor muestra los estados del pago en español: Pendiente, Aprobado o Rechazado.
- Se mantiene la referencia de Transfermóvil y el importe registrado para facilitar la revisión.
- Versión interna actualizada a 0.66.0+66.

## Cambios V67 — preparación final
- Esta versión inicia la fase final de estabilización antes del APK de distribución.
- Se refuerza la verificación previa para exigir las pruebas principales del cliente y del servidor.
- Versión interna actualizada a 0.67.0+67.


## Cambios V68 — estabilización final
- Versión interna 0.68.0+68.
- Preflight reforzado: valida endpoints críticos de salud, autenticación, viajes, panel administrativo y mensualidades antes de preparar el APK.
- Se mantiene el smoke test integral para autenticación, pagos, negociación, GPS, cancelación y panel administrativo.
- Esta versión continúa la fase de cierre: prioridad en pruebas y correcciones, sin añadir funciones innecesarias.


## Cambios V69 — cierre del pipeline Android
- Versión interna 0.69.0+69.
- El workflow de compilación quedó alineado con V69 (ya no muestra V56 en la verificación).
- El preflight exige V69 y valida archivos críticos y rutas principales del servidor antes de compilar.
- Se mantiene la compilación release con pruebas Flutter y smoke test del servidor en GitHub Actions.

## Cambios V70 — protección del APK final
- Versión interna 0.70.0+70.
- El pipeline ya no genera por accidente un APK de demostración cuando falta el servidor.
- Para una compilación de distribución, RAFAEL_API_URL es obligatoria; si falta, la compilación se detiene con un mensaje claro.
- Esto evita entregar a Rafael un APK que abra pero no conecte clientes, conductores y administración entre teléfonos.


## Cambios V71 — validación del servidor antes del APK
- Versión interna 0.71.0+71.
- La compilación de distribución exige que `RAFAEL_API_URL` use HTTPS.
- Antes de compilar, GitHub Actions comprueba `/health` y `/ready`; si el servidor no responde o el almacenamiento no está listo, el APK no se genera.
- Esto reduce el riesgo de entregar a Rafael un APK que instale correctamente pero no pueda sincronizar Cliente, Conductor y Administrador.


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


## FINAL v11 — build 81
- Añadido `render.yaml` para desplegar el backend como servicio Docker con disco persistente en `/data`.
- `ADMIN_IDENTITY` y `ADMIN_PIN` quedan como secretos del proveedor y no se incluyen en el APK ni en Git.
- El pipeline mantiene la comprobación HTTPS de `/health` y `/ready` antes de compilar el APK de distribución.
