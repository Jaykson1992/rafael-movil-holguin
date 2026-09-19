# Rafael Móvil API
Backend mínimo de prueba para sincronizar viajes, contraofertas, estados, ubicación y mensualidad.

## Ejecutar
`npm install` y luego `npm start`. Por defecto escucha en `http://localhost:8080`.

Los datos se guardan en `DATA_FILE` mediante escritura atómica. En producción, monta almacenamiento persistente para esa ruta y publica el servicio detrás de HTTPS. La autenticación usa PIN de 6 dígitos con PBKDF2 y tokens de sesión; el PIN del administrador se configura por variables de entorno y no se incluye en la APK.

## V11
Para crear el primer administrador sin guardar secretos en el código:
`ADMIN_IDENTITY=<identidad> ADMIN_PIN=<6-digitos> ADMIN_NAME=Rafael npm start`

Los conductores necesitan una suscripción activa antes de aceptar o contraofertar viajes. El administrador la renueva desde `/v1/drivers/:id/subscription`.
