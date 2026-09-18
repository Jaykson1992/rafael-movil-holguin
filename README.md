## V36 — cierre de sesión remoto
- Al cerrar sesión, la app intenta revocar el token también en el servidor.
- El almacenamiento cifrado local se borra aunque el teléfono esté sin conexión.
- Se añadió una comprobación reutilizable de validez de sesión contra `/v1/me`.
- Si no hay red, cerrar sesión localmente nunca queda bloqueado.

# Rafael Móvil – Transporte Holguín

Aplicación Flutter para transporte en Holguín con tres roles: Cliente, Conductor y Administrador.

## V1.0 FINAL — paquete listo para despliegue
- Versión de aplicación: `1.0.0+72`.
- El flujo de release exige un servidor público HTTPS operativo antes de producir el APK de distribución.
- El APK release no se genera en modo demostración por accidente.
- El pipeline valida preflight, smoke test del servidor, análisis Flutter, pruebas Flutter, `/health` y `/ready` antes de compilar.
- Para uso real entre teléfonos, `RAFAEL_API_URL` debe apuntar al backend desplegado y persistente.

### Único requisito externo pendiente
El proyecto contiene el código de la app y del backend, pero necesita una dirección pública HTTPS. Hay que desplegar `server/` en un host accesible desde Cuba y configurar `RAFAEL_API_URL`; después el workflow genera `app-release.apk`.
