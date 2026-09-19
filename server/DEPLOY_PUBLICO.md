# Publicar el backend de Rafael Móvil

El APK de distribución necesita una URL HTTPS pública y persistente. El contenedor ya escucha en `PORT` y expone `/health` y `/ready`.

## Variables obligatorias

- `ADMIN_NAME=Rafael`
- `ADMIN_IDENTITY=<identidad privada del administrador>`
- `ADMIN_PIN=<PIN privado de 6 dígitos>`
- `DATA_FILE=/data/rafael-data.json`
- `TRUST_PROXY=1`

No guardes el PIN en Git ni dentro del APK. Configúralo como secreto del proveedor de hosting.

## Persistencia

Monta un volumen persistente en `/data`. Sin almacenamiento persistente, reiniciar el servicio puede borrar usuarios, viajes, pagos y recibos.

## Verificación antes del APK

Cuando tengas el dominio, comprueba:

```sh
curl https://TU-DOMINIO/health
curl https://TU-DOMINIO/ready
```

Ambos deben responder con `ok: true`. Después configura en GitHub la variable de repositorio `RAFAEL_API_URL=https://TU-DOMINIO` y ejecuta **Generar APK Rafael Movil**.
