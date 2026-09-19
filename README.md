
## V36 — cierre de sesión remoto
- Al cerrar sesión, la app intenta revocar el token también en el servidor.
- El almacenamiento cifrado local se borra aunque el teléfono esté sin conexión.
- Se añadió una comprobación reutilizable de validez de sesión contra `/v1/me`.
- Si no hay red, cerrar sesión localmente nunca queda bloqueado.

# Rafael Móvil – Transporte Holguín (FINAL v5 / build 75)

Aplicación Flutter para transporte en Holguín con tres roles: Cliente, Conductor y Administrador.

## Incluido en V7
- Registro local de cliente y conductor.
- Auto, bicitaxi y triciclo.
- Solicitud de viaje y oferta en CUP.
- Aceptación y contraoferta.
- Estados del viaje hasta completado.
- Panel administrador protegido por PIN.
- Mensualidad de conductor configurable (1000 CUP / 30 días por defecto).
- Configuración de Transfermóvil.
- Historial y totales de viajes.
- Contrato de backend y modelos de ubicación GPS.
- Cola offline/reintento preparada para conectividad intermitente.
- Servicio de ubicación desacoplado, con ubicación demo de Holguín para mantener la base compilable sin claves privadas.
- Servicio de sesión preparado para autenticación real.
- GitHub Actions para generar APK release.

## Estado actual
El proyecto ya incluye backend REST, autenticación remota por roles, persistencia del servidor, pagos de mensualidad con revisión de Rafael, recibos, fotos de perfil, GPS y cola para conectividad intermitente. Para una entrega pública todavía deben configurarse un servidor HTTPS real, las variables privadas del administrador y hacerse pruebas finales entre varios teléfonos Android. No se incluyen claves privadas.

## APK
Al subir el proyecto a un repositorio GitHub, el workflow `.github/workflows/build-apk.yml` puede compilar `app-release.apk`. También puede compilarse localmente con Flutter.


## V8 — conexión de servidor
Se añadió `RestRafaelBackend`, un cliente REST real para crear viajes, aceptar viajes, enviar contraofertas, cambiar estados y subir ubicación del conductor. Incluye timeout para conexiones débiles y consulta del estado del viaje cada 5 segundos.

La URL del servidor NO se guarda fija en el código. Al compilar se puede indicar con `--dart-define=RAFAEL_API_URL=https://servidor...`. Hasta que exista un servidor real, la app continúa usando la demostración local. No se incluyó ninguna credencial de Zaymara.

### Endpoints esperados
- `POST /v1/trips`
- `GET /v1/trips/{id}`
- `POST /v1/trips/{id}/counter-offer`
- `POST /v1/trips/{id}/accept`
- `PATCH /v1/trips/{id}`
- `POST /v1/drivers/{id}/location`

## V9 — backend de prueba incluido
Se añadió `server/`, una API Node/Express ejecutable con endpoints de salud, viajes, contraofertas, estados, ubicación GPS, mensualidad y configuración de Transfermóvil. Esta API permite empezar las pruebas de sincronización entre teléfonos. En V9 los datos del servidor son temporales (memoria); producción requiere base de datos, HTTPS y autenticación.

## V10 - persistencia y seguridad
- El servidor guarda usuarios, sesiones, viajes, ubicaciones, conductores y ajustes en `server/data.json` (o `DATA_FILE`).
- Registro/login con PIN y token de sesión; los PIN no se guardan en texto claro.
- Permisos por rol: cliente, conductor y administrador.
- Endpoints del servidor alineados con `RestRafaelBackend` bajo `/v1`.
- El archivo `server/data.json` es runtime y no debe subirse a repositorios públicos.

## V11 - seguridad y negociación completa
- PIN obligatorio de 6 dígitos para nuevos usuarios.
- Los PIN nuevos se almacenan con PBKDF2 + salt (compatibilidad de login con datos V10 existentes).
- Administrador inicial Rafael puede crearse de forma segura con `ADMIN_IDENTITY`, `ADMIN_PIN` y opcionalmente `ADMIN_NAME` al arrancar el servidor; no se incluye ningún PIN secreto en el proyecto.
- Un conductor solo puede aceptar o contraofertar si su cuenta está activa y su mensualidad no está vencida.
- El cliente puede aceptar la contraoferta del conductor mediante `POST /v1/trips/{id}/accept-counter`.
- Validación de contraofertas para impedir precios vacíos, negativos o inválidos.

## V12 — seguridad de viajes y GPS
- Estados de viaje validados por rol: el cliente cancela; el conductor avanza asignado → en camino → en curso → completado.
- La ubicación de un conductor ya no se expone a cualquier usuario autenticado: cliente solo puede verla si participa en ese viaje activo; administrador conserva acceso.
- Nuevo resumen `/v1/admin/dashboard` para clientes, conductores activos y viajes.
- Se conserva la cola offline y la API REST de versiones anteriores.


## V13 — seguridad y conexión
- Protección básica contra intentos repetidos de PIN en el login.
- Cierre de sesión del servidor y limpieza de sesiones vencidas.
- Validación estricta de coordenadas GPS y de viajes activos.
- Un conductor solo puede tomar viajes del tipo de vehículo registrado.
- Evita que dos conductores acepten el mismo viaje mediante validación de estado.
- Configuración administrativa limitada a campos permitidos.
- Cliente REST Flutter ampliado con registro, login, logout, perfil y aceptación de contraoferta.

La app sigue necesitando una URL pública HTTPS para el servidor antes de probar dos teléfonos reales.

## V14
- Bandeja de viajes disponibles filtrada por el tipo de vehículo del conductor.
- Endpoint de conductores activos/disponibles para cliente/administrador.
- Solo aparecen conductores con mensualidad vigente y cuenta activa.
- Mantiene protección de ubicación: el GPS detallado del viaje sigue restringido al cliente del viaje y al administrador.


## V15 — disponibilidad real del conductor
- Un conductor no puede aceptar dos viajes activos al mismo tiempo.
- La bandeja del conductor muestra su viaje activo cuando ya está ocupado.
- La lista de conductores disponibles excluye conductores ocupados o con mensualidad vencida.
- Las ubicaciones GPS con más de 2 minutos se consideran antiguas y no se muestran como ubicación actual.
- Se conserva el modo de bajo consumo de datos con polling moderado y cola offline.

## V16
- Registro de auditoría para cambios sensibles (viajes, mensualidades y configuración).
- Rafael puede consultar la lista administrativa de conductores con estado de mensualidad, ocupado/libre y última ubicación válida.
- Endpoint de auditoría limitado y exclusivo del administrador.
- Se restringió la edición administrativa del conductor para evitar modificar campos internos arbitrarios.
- Se limpiaron archivos temporales y copias antiguas del servidor antes de empaquetar.

## V17 — tolerancia a conexión débil
- La creación de viajes acepta `requestId` para evitar viajes duplicados cuando el teléfono reintenta después de perder Internet.
- El servidor devuelve el viaje ya creado si recibe de nuevo el mismo `requestId` del mismo cliente.
- Esto complementa la cola offline y hace más seguro reintentar solicitudes en redes inestables.

## V18 — historial y cancelaciones
- Nuevo `GET /v1/trips` para historial del usuario autenticado: cliente ve solo sus viajes, conductor solo los asignados a él y administrador puede consultar el conjunto completo.
- El historial acepta filtro por estado y límite de resultados para reducir consumo de datos.
- Las cancelaciones del cliente pueden guardar un motivo breve (`cancelReason`) para que Rafael tenga mejor trazabilidad.
- Se mantiene la protección por roles: un usuario no obtiene el historial privado de otro.

## V19 — sincronización ligera
- Se corrigió una ruta duplicada de historial de viajes que podía saltarse filtros y límites.
- Nuevo endpoint `GET /v1/changes?since=<ISO>` para descargar solo cambios recientes y gastar menos datos móviles.
- Cliente, conductor y administrador reciben únicamente cambios compatibles con su rol.
- El conductor recibe además estado de mensualidad y frescura de su GPS en la sincronización ligera.


## V20 – conexión débil y recuperación automática
- El seguimiento de viajes ya no se rompe por un corte temporal de Internet.
- Reintentos con espera progresiva de 4 a 30 segundos para no gastar datos ni batería innecesariamente.
- Al volver la conexión, el seguimiento regresa automáticamente al intervalo normal.
- Cliente REST preparado para sincronización incremental mediante `/v1/changes`.
- La cola offline evita duplicados idénticos antes de enviarlos al servidor.

## V21 — cola offline persistente
- Las acciones pendientes pueden guardarse en JSON local mediante `OfflineSyncService(persistencePath: ...)`.
- Al reiniciar la app, `load()` recupera las acciones que todavía no llegaron al servidor.
- Cada envío confirmado se elimina y se persiste inmediatamente para reducir duplicados después de cierres inesperados.
- La detección de duplicados ahora usa JSON canónico, evitando depender del orden de las claves del mapa.
- La escritura usa archivo temporal y reemplazo para reducir el riesgo de dejar la cola corrupta si se interrumpe una escritura.

## V22 — servidor listo para despliegue de prueba
- Configuración de CORS por variable `CORS_ORIGINS` para limitar orígenes cuando se publique la API.
- Cabeceras básicas de seguridad, respuestas `no-store` y un `X-Request-Id` por petición para diagnóstico.
- Nuevo `/ready` comprueba que el almacenamiento persistente sea escribible.
- El servidor crea de forma segura el directorio de datos antes de guardar.
- Cierre ordenado ante SIGTERM/SIGINT para reducir riesgo de corrupción al reiniciar el servidor.
- Se añadió `server/.env.example` sin secretos y `server/docker-compose.yml` con volumen persistente y healthcheck.
- Los secretos reales del administrador NO están incluidos en el ZIP.


## V23 — prueba automática antes de generar APK

Se añadió `server/smoke-test.js`, una prueba de integración que levanta una base temporal y comprueba el flujo crítico completo: registro/login, renovación de mensualidad, creación del viaje, contraoferta, aceptación del cliente, estados del viaje, envío/lectura de GPS y panel del administrador. El workflow de GitHub ejecuta esta prueba antes de compilar el APK; si falla el servidor, no publica un APK como si estuviera correcto.

Comando de prueba del servidor: `cd server && npm ci && npm run smoke`.

## V24 — GPS Android real
- Se agregó `geolocator` y `AndroidLocationTrackingService` para obtener coordenadas reales del teléfono.
- Solicita permiso de ubicación al usuario y detecta si el GPS está apagado.
- Seguimiento configurado con alta precisión y actualización al desplazarse ~20 m para limitar consumo de datos/batería.
- El flujo de compilación agrega automáticamente permisos `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` e `INTERNET` al AndroidManifest.
- No requiere una clave de Google Maps para obtener coordenadas; la visualización cartográfica queda desacoplada.

## V25 — seguimiento GPS conectado
- Corregido el modelo `DriverLocationUpdate` para que coincida con el contrato REST (`tripId` + `capturedAt`).
- Añadida lectura autorizada de la ubicación del conductor desde el servidor.
- Añadido `LiveTripTrackingService`: transmite GPS físico del conductor durante un viaje activo y permite al cliente observar esa posición.
- Reintentos tolerantes a cortes de red sin bloquear la interfaz.
- El servidor mantiene la regla de privacidad: el cliente solo puede consultar al conductor asignado a su viaje activo.


## V26 — seguimiento visual del conductor
Se añadió `DriverTrackingPanel`, una pantalla liviana para el cliente que consume el GPS autorizado del viaje, muestra estado de conexión, coordenadas y distancia aproximada al conductor sin depender de Google Maps ni de una API key. El stream conserva el reintento tolerante a conexiones débiles ya implementado en el backend.


## V27 — seguimiento conectado en la pantalla Cliente
- La pantalla Cliente ya usa `DriverTrackingPanel` cuando existe servidor real, tripId y driverId.
- El panel consume la ubicación autorizada del backend, muestra estado de conexión y distancia aproximada.
- Sin servidor configurado mantiene un fallback claro y no rompe el flujo local.
- URL del backend se inyecta con `--dart-define=RAFAEL_API_URL=https://...`; no se guarda un secreto dentro de la app.


## V28 — GPS del conductor integrado
- Añade control visible para iniciar/detener el envío de ubicación durante un viaje activo.
- El GPS se detiene al salir del panel para evitar compartir ubicación fuera del viaje.
- El control solo aparece con servidor configurado y un viaje real con ID.
- Mantiene la recepción protegida de ubicación para cliente/administrador.


## V29 — compilación conectable a producción
- La URL del servidor ya no queda fija en el código: se inyecta al compilar con `RAFAEL_API_URL`.
- La app valida que la URL sea HTTP/HTTPS y no activa funciones remotas si la configuración está vacía.
- GitHub Actions usa automáticamente la variable de repositorio `RAFAEL_API_URL` al crear el APK.
- Si todavía no existe servidor público, el mismo flujo genera una APK de demostración sin fingir que tiene GPS remoto conectado.
- Versión: 0.29.0+29.

## V30 — validación antes de APK

Se añadieron pruebas automáticas Flutter para el flujo de viaje, contraoferta, finalización, mensualidad de 30 días y registro del conductor. El flujo de GitHub Actions ahora ejecuta `flutter analyze` y `flutter test` antes de compilar: si una prueba falla, no publica el APK como artefacto. Versión del proyecto: `0.30.0+30`.

## V31 — diagnóstico de conexión
- Añadida comprobación `/health` desde la app para saber si el servidor configurado está realmente accesible.
- El panel de Rafael distingue claramente entre modo demostración/local y servidor conectado.
- Muestra latencia aproximada cuando el servidor responde y permite reintentar manualmente.
- Versión Flutter actualizada a `0.31.0+31`.


## V32 — acceso administrador de producción
- El acceso de Rafael cambia automáticamente a autenticación contra el servidor cuando `RAFAEL_API_URL` está configurada.
- El PIN real del administrador no se almacena en la APK de producción.
- El servidor verifica identidad + PIN, aplica su limitación de intentos y confirma que la cuenta tenga rol `admin`.
- El PIN local queda únicamente para el modo demostración sin servidor.
- Versión Flutter: `0.32.0+32`.


## V33 — cuentas conectadas al servidor
- Cliente y conductor crean un PIN de 6 dígitos cuando la APK usa servidor de producción.
- El registro se envía al backend y se inicia sesión inmediatamente.
- La sesión autenticada se reutiliza para el GPS del conductor y el seguimiento del cliente.
- En modo demostración se conserva el flujo local sin exigir servidor.

Nota: la sesión todavía vive en memoria durante esta fase; el siguiente endurecimiento será almacenamiento seguro y reingreso tras reiniciar la app.


## V34 — sesión segura persistente
- Tokens de Cliente/Conductor se guardan con `flutter_secure_storage` (almacenamiento cifrado de Android).
- La sesión se restaura al reiniciar la app cuando hay servidor de producción.
- Nombre, identidad, rol y vehículo necesarios para reconstruir la sesión se guardan junto al token.
- Se añadió una operación de cierre de sesión que limpia el almacén seguro.
- El PIN no se persiste en el dispositivo.


## V35 — validación segura de sesión
- La sesión guardada en Android ya no se acepta automáticamente al abrir la app.
- El token se valida contra `GET /v1/me` antes de restaurar Cliente o Conductor.
- Si el servidor confirma que la sesión fue revocada, venció o pertenece a otra identidad/rol, la app no concede acceso.
- Si solo falta Internet, no se borra el token cifrado: la app arranca cerrada y podrá validarlo cuando vuelva la conexión.


## V37 — ingreso para usuarios existentes
- Cliente y Conductor ahora pueden elegir entre crear una cuenta nueva o entrar a una cuenta ya registrada.
- El ingreso usa carnet de identidad + PIN de 6 dígitos contra el servidor.
- La app verifica que el rol devuelto por el servidor coincida con Cliente o Conductor antes de conceder acceso.
- Después del ingreso, el token se guarda en el almacenamiento seguro ya incorporado y se reutiliza al reiniciar la app.
- Versión Flutter: `0.37.0+37`.


## V38
- El login del administrador conserva el token real de sesión mientras el panel está abierto.
- El panel de Rafael consulta `/v1/admin/dashboard` cuando hay servidor de producción.
- La mensualidad y tarjeta Transfermóvil pueden guardarse directamente en `/v1/settings` con permisos de administrador.
- En modo demostración se mantiene el comportamiento local anterior.


## V39 — Solicitudes de pago de mensualidad
El conductor puede reportar una referencia de Transfermóvil. Rafael puede revisar la solicitud y aprobarla o rechazarla. Solo una aprobación extiende la mensualidad; el servidor conserva auditoría y evita solicitudes pendientes duplicadas.


## V40 — pagos visibles en la app
- Se reparó `pubspec.yaml`, que había quedado corrupto en una versión previa, y se restablecieron las dependencias Flutter necesarias.
- El conductor ya tiene panel visible para reportar la referencia de Transfermóvil y consultar sus últimos estados de pago.
- Rafael ya tiene panel visible para revisar pagos pendientes y aprobarlos o rechazarlos.
- La aprobación sigue siendo la única acción que extiende la mensualidad en el servidor.
- Versión Flutter: `0.40.0+40`.


## V41 — configuración de pago sincronizada
- El panel del conductor consulta al servidor la mensualidad y la tarjeta Transfermóvil vigentes, evitando mostrar valores locales desactualizados.
- Rafael puede cerrar su sesión de administrador desde el panel; el token se invalida en el servidor cuando hay conexión.
- Se mantiene fallback tolerante a conexión débil para consultar el historial de pagos.


## V42 — gestión real de conductores
- Rafael puede consultar desde la app la lista de conductores registrada en el servidor.
- El panel muestra vehículo, estado ocupado/disponible/pausado y vigencia de mensualidad.
- Rafael puede pausar/reactivar una cuenta y renovar su mensualidad desde el panel.
- Corregido el cliente REST de `/v1/admin/drivers`: el endpoint devuelve una lista y ahora se decodifica como lista, evitando un fallo de tipo en producción.
- Versión Flutter: `0.42.0+42`.


## V43 — Historial operativo del administrador
- Rafael puede consultar desde la app los últimos viajes guardados en el servidor.
- Filtros por buscando, asignado, en camino, en curso, completado y cancelado.
- Cada fila muestra origen, destino, vehículo, estado y precio/oferta final.
- El panel limita la consulta para ahorrar datos móviles.

## V44 — Registro de seguridad visible
- Rafael puede consultar desde su panel los 50 eventos administrativos más recientes.
- El registro muestra cambios de viajes, pagos, mensualidades, cuentas de conductores y configuración.
- Los datos provienen del endpoint protegido `/v1/admin/audit`; un cliente o conductor no puede consultarlos.


## V45 — Registro de seguridad con filtros
- Rafael puede buscar eventos del registro de seguridad.
- Filtros por rol (administrador, conductor, cliente) y tipo de evento.
- El servidor filtra antes de enviar resultados para ahorrar datos móviles.
- Hasta 100 eventos visibles en el panel y límite de servidor protegido.


## V46 — Resumen operativo ampliado
- El dashboard del administrador ahora devuelve viajes activos y completados por separado.
- Añadido total bruto en CUP de viajes completados, usando el precio final negociado cuando existe.
- Añadido contador de solicitudes de mensualidad pendientes de revisión.
- Estos indicadores se calculan en el servidor para evitar descargar historiales completos al teléfono.
- Versión Flutter: `0.46.0+46`.

## V47
- Panel de clientes del administrador: búsqueda por nombre/carnet, total de viajes y bloqueo/reactivación.
- El servidor impide usar una sesión si la cuenta del cliente está bloqueada.
- El panel de conductores y clientes queda más cerca del diseño visual aprobado.

## V48 — Panel administrativo visual
- Resumen administrativo adaptable a teléfonos y pantallas grandes.
- Tarjetas separadas para clientes, conductores, viajes, viajes activos, pagos pendientes y CUP de viajes completados.
- Mantiene los paneles de conductores y clientes conectados al servidor y las acciones de pausar/reactivar/bloquear.

## V49 — reparación del flujo de compilación APK
- Se detectó que GitHub Actions usaba `npm ci`, pero el proyecto no incluye `package-lock.json`; eso habría detenido la compilación antes de llegar a Flutter.
- El workflow ahora instala las dependencias del servidor con `npm install --no-audit --no-fund` y después ejecuta la prueba de integración.
- Se corrigió la versión Flutter, que todavía figuraba como 0.46.0+46 pese a los avances V47/V48. Ahora es `0.49.0+49`.
- Se mantiene la regla de no publicar el artefacto APK si falla la prueba del servidor, `flutter analyze` o `flutter test`.


## V50 — paquete de distribución directa para Cuba
- La versión Flutter avanza a `0.50.0+50`.
- Se añade una guía específica para distribuir el APK directamente, sin Google Play.
- Se documenta la diferencia entre APK demostrativa y APK conectada: para que Cliente, Conductor y Administrador se sincronicen entre teléfonos, la APK debe compilarse con `RAFAEL_API_URL` apuntando a un servidor HTTPS accesible desde Cuba.
- Se añade un verificador de integridad del proyecto antes de compilar, para detectar archivos críticos faltantes y evitar entregar un ZIP incompleto.
- Se conserva todo el trabajo de V49: autenticación, mensualidades, Transfermóvil, GPS, auditoría, paneles administrativos y pruebas automáticas.


## V53 — verificación de entrega y flujo conectado
- V53 queda como nueva base del proyecto.
- El preflight exige la versión 0.53.0+53 y los archivos críticos antes de compilar.
- GitHub Actions ejecuta el smoke test del servidor antes de compilar Android.
- El smoke test comprueba autenticación, mensualidad, negociación cliente/conductor, estados del viaje, GPS y dashboard del administrador.
- Se conserva la compilación con `RAFAEL_API_URL` para conectar el APK al servidor real, y el modo demostración cuando esa variable no está configurada.


## V53
- Base actualizada desde V52 sin reiniciar el proyecto.
- Preflight actualizado a 0.53.0+53.
- Verificación de sintaxis del servidor y smoke test local incluidos antes de entregar.
- Se conserva distribución directa por APK para Cuba.


## V54
- Base actualizada a 0.54.0+54.
- Preflight actualizado para impedir compilar una versión equivocada.
- Verificación de sintaxis del servidor incluida en la preparación de esta entrega.
- Se mantiene la distribución directa del APK para Cuba sin depender de Google Play.


## V55 — consistencia de entrega
- Base actualizada a `0.55.0+55` sin reiniciar el proyecto.
- Corregida la etiqueta del workflow de GitHub, que todavía decía V52 aunque la base ya era V54.
- El preflight y la versión del proyecto quedan alineados en V55 para evitar confusión al generar el APK.
- Se conservan autenticación, mensualidades, Transfermóvil, negociación de viajes, GPS, paneles administrativos, cola offline y distribución directa por APK.


## V56 — cuentas pausadas bloqueadas desde el ingreso
- Base actualizada a `0.56.0+56`.
- Una cuenta pausada/bloqueada ya no recibe un token nuevo aunque presente el PIN correcto: el servidor responde `account_paused` desde el propio login.
- Las sesiones existentes continúan protegidas por la misma comprobación de cuenta activa en cada petición.
- Preflight y workflow de compilación quedan alineados en V56.
- Se conserva distribución directa por APK, GPS, negociación, mensualidades, Transfermóvil y paneles de Rafael.


## V58 — mensajes claros de acceso y cuentas pausadas
- Base actualizada a `0.58.0+58`.
- El cliente REST conserva ahora el código de error que devuelve el servidor en respuestas fallidas.
- Cliente y conductor ven un mensaje específico cuando Rafael ha pausado su cuenta, en lugar de confundirlo con un PIN incorrecto o un fallo de Internet.
- También se distinguen credenciales incorrectas y bloqueo temporal por demasiados intentos.
- Preflight alineado en V58.


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

## Cambios V67 — cierre y pruebas integrales
- Se entra en fase de cierre: prioridad a estabilidad y pruebas, sin añadir funciones nuevas salvo correcciones necesarias.
- El preflight ahora valida también los archivos de pruebas de Flutter y del servidor antes de compilar.
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


## V1.0 FINAL — paquete listo para despliegue
- Versión de aplicación: `1.0.0+72`.
- El flujo de release exige un servidor público HTTPS operativo antes de producir el APK de distribución.
- El APK release no se genera en modo demostración por accidente.
- El pipeline valida preflight, smoke test del servidor, análisis Flutter, pruebas Flutter, `/health` y `/ready` antes de compilar.
- Para uso real entre teléfonos, `RAFAEL_API_URL` debe apuntar al backend desplegado y persistente.

### Único requisito externo pendiente
Este ZIP contiene el código de la app y del backend, pero no puede incluir por sí solo una dirección pública HTTPS. Hay que desplegar `server/` en un host accesible desde Cuba y configurar `RAFAEL_API_URL`; después el workflow genera `app-release.apk`.


## Actualización FINAL v3
- Al aprobar una mensualidad, el servidor genera un número de recibo único RMH.
- El conductor ve el recibo en su historial de pagos y la cuenta queda activa automáticamente por el período configurado.
- Rafael sigue siendo quien valida o rechaza el pago reportado; no se almacenan datos bancarios sensibles en la app.


## Actualización FINAL v4
- Registro con foto de perfil opcional para clientes y conductores.
- La foto queda disponible únicamente en los paneles autorizados que reciben el perfil.
- Moto permanece incluida como tipo de vehículo.
- Preflight actualizado a build +74.


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


### FINAL v9 / build 80
Se reforzó la verificación previa de release para evitar entregar una compilación sin Moto, fotos, recibos de mensualidad o con un archivo `.env` de secretos incluido accidentalmente.


## FINAL v11 — build 81
- Añadido `render.yaml` para desplegar el backend como servicio Docker con disco persistente en `/data`.
- `ADMIN_IDENTITY` y `ADMIN_PIN` quedan como secretos del proveedor y no se incluyen en el APK ni en Git.
- El pipeline mantiene la comprobación HTTPS de `/health` y `/ready` antes de compilar el APK de distribución.
