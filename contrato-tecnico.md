---
title: Contrato técnico — estado actual (iOS ↔ Backend ↔ Flutter)
---

# Contrato técnico — +Vida

**Actualizado el 6 oct 2026** (ciclos, monedas y cupones): el podio de La Liga se
**paga el día 9** (el mes se sigue cerrando el día 2) para que las monedas y el cupón
caigan en la season siguiente, y los **cupones duran 3 semanas (21 días)**, los
canjeados y los ganados. La app dice "tus monedas llegan el día 9". Ver "Cierre de La
Liga", "Monedas y seasons" y "Patrocinios".

**Actualizado el 3 oct 2026** (cierre semanal): la semana se cierra el **martes
00:00**, no el lunes: los datos atrasados del domingo tienen **todo el lunes**
para llegar (como StepBet, 24 h). Ya está en el código (A34). El objetivo de la
semana nueva se sigue fijando el lunes 00:00. Ver "Ciclos y cortes" y "Cierre
semanal programado".

**Actualizado el 3 oct 2026** (La Liga): las monedas de La Liga van a **los 3
primeros** del mes, no por percentil. Ver "La Liga y Tus Ligas".

**Actualizado el 3 oct 2026** (La Liga y Tus Ligas, backend): endpoints del
ranking (`GET`/`POST /api/v1/ligas`, `POST /api/v1/ligas/unirse`) y cierre
mensual de La Liga el día 2 a las 00:00 (el día 1 es margen de gracia), que
paga el podio. Montos del podio y
empate total con valores **provisionales**. Ver "Endpoints de La Liga y Tus
Ligas".

**Actualizado el 3 oct 2026** (premios y canje, backend): endpoints de saldo de
monedas, catálogo, canje y cupones. Canjear exige póliza verificada y descuenta
las monedas y crea el cupón en una sola transacción. Ver "Premios, canje y
cupones".

**Actualizado el 3 oct 2026** (sincronización): Swift ya no hace un backfill de
una sola vez: **cada vez que la app se abre** (y al iniciar sesión y al dar el
permiso de Salud) manda **desde el último día enviado hasta hoy**; la primera vez,
los últimos 7 días, con puntos. El envío en **segundo plano** y las
**notificaciones push** quedan decididos pero sin construir. La cola caduca a los
14 días, el `422` de la ventana descarta solo ese día, y una respuesta ilegible
del servidor cuenta como enviada. El wrapper de Dart ya tiene `actualizarSesion`.
Ver "Cuándo se manda cada día" y "Puntos abiertos".

**Actualizado el 3 oct 2026** (objetivo semanal por componente, backend): cada
componente paga sus monedas por separado y la meta de pasos sale de la tabla por
edad. `GET /api/v1/retos/estado` **se renombra** a `GET /api/v1/objetivos/estado`,
con respuesta nueva, y se agrega `GET /api/v1/objetivos/semanas` para la vista
tipo "battle pass". Ver "Respuesta de `GET /api/v1/objetivos/estado`".

**Actualizado el 2 oct 2026** (reunión del equipo): inicio de sesión con Google y
Apple; el objetivo semanal paga monedas **por componente** y su meta de pasos
depende de la **edad**; vista de semanas tipo "battle pass"; **seasons de 13
semanas** que siguen las semanas ISO; **monedas sin tope** que se reinician al
cerrar cada season; **La Liga compite por puntos**, con desempate por pasos y luego workouts;
datos que entrega la aseguradora, póliza y **prima anuales**; puntos anuales,
nivel y cashback **por año de póliza** (no por año calendario); cashback en
quetzales. Lo que cambia en el código quedó marcado **[PENDIENTE]**. Ver
"Puntos abiertos".

**Actualizado el 1 oct 2026** (cierre semanal programado): el cierre del objetivo
semanal ya tiene quién lo corra: el servicio `programador` de Docker Compose
(lunes 00:00 y 12:00, hora de Guatemala), que además se pone al día si un lunes
falló. Ver "Cierre semanal programado".

**Actualizado el 1 oct 2026** (revisión contra el código): se comparó cada
sección con lo que hacen el backend (incluido el de Luis, ya en `dev`), Swift y
Flutter. Donde el código no cumple una regla ya decidida, la regla **no se
cambió**: se marca **[PENDIENTE]** con lo que pasa hoy. Ver "Puntos abiertos".
Decidido en esta revisión: **cualquier workout de cualquier duración cuenta**
(con ritmo cardíaco). Ya cuenta así en el código.

**Actualizado el 1 oct 2026** (cierre de huecos): se documentan
`GET /api/v1/historial`, el campo `monedas_al_cumplir` de `retos/estado` y qué
hace el servidor con datos mal formados o imposibles en `sync`.

**Actualizado el 1 oct 2026** (fuentes, workouts y póliza): la elección de
fuente pasa de "gana el reloj" a **una decisión por bloque** (una hora, o varias si una
muestra larga las cubre; ver "Pasos por bloques") para los pasos; un
workout **necesita ritmo cardíaco** (sin reloj no hay workout, y los workouts
ingresados a mano no cuentan); y se documentan los endpoints de póliza y la
regla de retroactividad. Ver "Elección de fuente", "Qué cuenta como workout" y
"Póliza vinculada".

**Actualizado el 30 sep 2026** (autenticación): quién manda los datos lo decide
el servidor con un **token**, no con un `usuario_id` dentro del JSON. Sección
nueva "Autenticación (token)"; `usuario_id` sale del JSON #1; el MethodChannel
pasa de 2 a 3 métodos (`actualizarSesion`); y Swift conserva los días
pendientes cuando no hay sesión.

**Actualizado el 23 sep 2026** (demo 1): objetivo semanal fijo e igual para
todos, La Liga con un solo grupo y premios por percentil (reemplazados el 3 oct
por monedas al top 3), Tus Ligas sin
póliza y sin premios, duelos 1 contra 1 eliminados. Todo "reto semanal" pasa a
llamarse **objetivo semanal**.

*Este es el documento **vivo** de este dominio. Reemplaza a `contrato-v2.md`,
`contrato-v3_1.md`, `contrato-v3_2.md`, `contrato-v3_4.md` y `contrato-v4.md`
como referencia — esos archivos no se borran, pero dejan de actualizarse: su
contenido (las narrativas "qué cambió de vX a vY") se está consolidando aparte,
en un archivo de bitácora histórica. Cuando el contrato cambie, este archivo se
actualiza in-place — no se crea un v5, v6, etc.*

Define cómo se comunican las tres capas: iOS (Alvaro), backend (Luis) y Flutter
(Daniel). Los tres construyen contra este documento — no contra lo que cada
quien tenga corriendo en su máquina. Si algo no está acá, no existe todavía.

## Principio no negociable

La app de iOS **nunca** manda puntos, edad, ni frecuencia cardíaca máxima
calculada, ni conclusiones derivadas (como "hubo sesión intensa"). Manda datos
crudos de HealthKit — nada más. Los puntos, las sesiones intensas sin workout,
y el total de pasos deduplicado, los calcula Luis en el servidor.

Razón: si el teléfono pudiera mandar puntos o conclusiones ya calculadas,
cualquier iPhone jailbreakeado se acredita lo que quiera sin que el servidor
tenga cómo auditarlo. Todo el poder de decisión vive del lado que controlamos
nosotros. **El mismo principio aplica a `tipo_dispositivo` (ver más abajo):
el teléfono manda los campos crudos de `HKDevice`, nunca la categoría ya
resuelta.**

**Lo mismo aplica a la identidad:** el teléfono nunca dice quién es. Quién manda
los datos lo decide el servidor a partir del token que él mismo entregó al
iniciar sesión — jamás a partir de un `usuario_id` (ni de ningún otro
identificador) que venga dentro de la petición. Razón: un identificador que el
cliente escribe en la petición lo puede cambiar cualquiera, y con él se mandarían
datos (y puntos, y cashback) a nombre de otra persona.

---

## Autenticación (token)

**Quién es el usuario lo decide el servidor, a partir de un token.** No de un
campo dentro del JSON.

### Cómo funciona

1. La persona se registra o inicia sesión desde Flutter, por HTTP (`POST
   /api/v1/registro` o `POST /api/v1/login`). El servidor responde con su
   `token`.
2. Desde ese momento **toda petición a `/api/v1/*`** lleva el encabezado:

   ```
   Authorization: Token <clave>
   ```

   La palabra es `Token` (así la espera django-rest-knox, igual que antes Django REST
   Framework), no `Bearer`.
3. El servidor busca a quién pertenece ese token y trabaja con ese usuario.
   Nunca toma la identidad del cuerpo de la petición.

**No piden token:** `POST /api/v1/registro`, `POST /api/v1/login` y
`GET /api/health/`. Todo lo demás sí.

### Registro y login

| Petición | Cuerpo | Respuesta |
|---|---|---|
| `POST /api/v1/registro` | `{ "username": string, "password": string, "birth_date": "YYYY-MM-DD" }` | `201` `{ "token": string, "expiry": string, "usuario_id": string, "username": string }` |
| `POST /api/v1/login` | `{ "username": string, "password": string }` | `200` `{ "token": string, "expiry": string, "usuario_id": string? }` |

- **Cada login o registro abre una sesión nueva con su propio token** (desde el 4 oct,
  A35): dos teléfonos de la misma persona tienen tokens distintos.
- `expiry` es cuándo vence hoy, en ISO 8601 con zona (`2026-11-04T10:15:00.123456-06:00`).
  Es informativo: cada uso lo corre (ver "Reglas del token"), así que la app no lo
  usa para decidir nada; decide por el `401`.
- `usuario_id` es el mismo del registro. Flutter se lo pasa a Swift en
  `actualizarSesion` para que sepa si cambió la persona. Es `null` solo en una cuenta
  sin perfil (las que crea el admin), que no usa la app.

Errores: `400` con un objeto `{ "<campo>": [mensajes] }` (usuario repetido,
contraseña débil, fecha de nacimiento futura) o `{ "non_field_errors": [...] }`
(credenciales incorrectas en el login). `429` si se pasó el límite de intentos
(ver "Límite de intentos" abajo). El login y el registro no leen el encabezado
`Authorization`: un token viejo o inválido no impide iniciar sesión ni crear la
cuenta.

### Cerrar sesión: `POST /api/v1/logout` y `POST /api/v1/logout/todos` (A35, 4 oct 2026)

Con token, sin cuerpo. Los dos responden `204`; con un token inválido o vencido,
`401`, como el resto.

| Endpoint | Qué cierra |
|---|---|
| `POST /api/v1/logout` | **Solo esta sesión** (este teléfono): borra el token con el que se llamó. Los otros teléfonos de la cuenta siguen adentro |
| `POST /api/v1/logout/todos` | **Todas las sesiones** de la cuenta, en todos sus teléfonos |

La app, al cerrar sesión, manda `logout` **sin esperar la respuesta** y en el momento
borra su copia y le entrega `null` a Swift con `actualizarSesion(null)`: con la red
mala, esperar dejaba la pantalla quieta hasta 5 s. La petición sale con el token
aunque la copia ya se haya borrado. Si no llega (sin red, el token ya había vencido,
o la app se cerró en ese instante), el token queda en el servidor hasta que venza.
`logout/todos` es para "Cerrar sesión en todos los dispositivos" y, más
adelante, para cambiar la contraseña o borrar la cuenta (OWASP; App Store 5.1.1(v)).

### Inicio de sesión con Google y Apple (decidido 2 oct 2026)

Además de usuario y contraseña, la app ofrece **"Continuar con Google"** e
**"Iniciar sesión con Apple"**. Apple no es opcional: la App Store exige
ofrecerlo si se ofrece Google (guía 4.8).

- La app recibe del proveedor una credencial firmada y se la manda al servidor;
  el servidor la verifica con Google o Apple y devuelve **el mismo `token` de
  siempre**. Desde ahí nada cambia: mismo encabezado, mismo `actualizarSesion`,
  mismo `sync`.
- Ni Google ni Apple entregan la fecha de nacimiento. La primera vez se pide en
  un paso aparte y **sin ella no se crea la cuenta**: la edad decide la FCmáx,
  el bono 60+ y la meta semanal de pasos.
- Apple puede ocultar el correo real (entrega uno de reenvío).
- **[PENDIENTE] (Luis y Daniel):** la forma de los endpoints (propuesta:
  `POST /api/v1/login/google` y `POST /api/v1/login/apple` con la credencial
  del proveedor, respuesta `{ "token", "nuevo" }`), qué pasa si ya existe una
  cuenta con ese correo, y normalizar el correo (hoy `Ana` y `ana` son dos
  cuentas distintas).
- **Desde A35:** el login con Google o Apple abre la sesión con
  `sesiones.iniciar_sesion` (no con el `Token` de DRF) y responde también `expiry` y
  `usuario_id`, como el login con contraseña.

### Reglas del token

Desde A35 (4 oct 2026) los tokens son de **django-rest-knox** (antes, el de Django
REST Framework: uno por cuenta, en texto plano y sin tope). Ver
`services/sesiones.py`.

- **Un token por sesión:** cada login o registro crea uno nuevo. Una cuenta tiene
  **como mucho 10 sesiones**; al entrar la undécima se cierra **la que lleva más tiempo
  sin usarse** (nunca la que se acaba de abrir). Como Knox no guarda el último uso, se
  mide por el vencimiento, que cada uso corre; una sesión que ya llegó al tope de 90
  días (se usó después del día 60) cuenta como usada hace poco.
- **Vence a los 30 días SIN uso y cada uso lo renueva:** quien abre la app seguido no
  se topa con el vencimiento. El vencimiento se escribe a lo más **una vez por hora**
  (decidido el 5 oct 2026, como lo tenía Luis antes de A35): sobre 30 días no se nota
  y la base se escribe mucho menos. Se cambia en `REST_KNOX["MIN_REFRESH_INTERVAL"]`.
- **Tope de 90 días:** aunque se use a diario, a los 90 días de iniciar sesión hay que
  volver a entrar. Así un token robado no sirve para siempre.
- Un token vencido responde `401` en **todos** los endpoints (también `sync`) y la
  app vuelve a la pantalla de inicio de sesión. Knox lo borra en ese momento.
- **En la base de datos solo queda un hash** (SHA-512) del token, como con las
  contraseñas: quien vea la base no puede usar los tokens. La clave completa se
  entrega una sola vez, al entrar; no se puede volver a consultar.
- Los días se cambian con `DIAS_DE_VIDA_DEL_TOKEN` (30) y `DIAS_MAXIMOS_DE_SESION` (90,
  en `settings.py`).
- **Al desplegar A35 nadie tiene que volver a entrar:** la migración `users/0006`
  copia a Knox cada token vigente con la misma clave y el mismo vencimiento, y
  borra los de texto plano. El tope de 90 días cuenta desde ese momento.
- Se trata como una contraseña: nunca se escribe en logs ni en mensajes de
  error, y nunca viaja dentro del cuerpo de una petición.
- Flutter guarda su propia copia para sus llamadas HTTP. A Swift se la entrega
  con `actualizarSesion` (ver "MethodChannel"); Swift guarda la suya en su
  Keychain y la usa para enviar el `sync`.

### `usuario_id`

Identificador **público** de la persona: un UUID que genera el servidor al
registrarse y que devuelve en la respuesta del registro y, desde A35, también en
la del login. Sirve para mostrar y compartir (hoy la app lo muestra en Perfil y
lo usa como código para agregar amigos). **No identifica a quien manda datos y no
viaja en ninguna petición al servidor.**

En el teléfono, Swift lo usa para saber si entró otra persona: Flutter se lo pasa
en `actualizarSesion` y Swift lo guarda en `UserDefaults` (clave
`vida.cuentaDeLosEnvios`; no es secreto). Si llega uno distinto, vacía la cola y
la marca de envíos (ver `actualizarSesion`).

No confundir con la columna interna `usuario_id` de las tablas del servidor
(`(usuario_id, external_id)`, `(usuario_id, fecha)`), que es la referencia a la
fila del usuario y no tiene relación con este campo.

### Respuestas de error de autenticación

| Situación | Código | Cuerpo |
|---|---|---|
| Falta el encabezado | `401` | `{ "detail": "..." }` y el encabezado `WWW-Authenticate: Token` |
| Token inválido (también un encabezado con caracteres que no son UTF-8, o un token que se cerró mientras se usaba) | `401` | `{ "detail": "..." }` |
| Token **vencido** (30 días sin uso, o 90 desde que se entró) | `401` | `{ "detail": "..." }` y `WWW-Authenticate: Token`. El mismo texto que un token inválido: la app decide por el código |
| Token válido pero la cuenta no tiene perfil de usuario | `403` | `{ "mensaje": "..." }` |
| Demasiados intentos (registro, login o vincular póliza) | `429` | `{ "error": "demasiados_intentos", "mensaje": "...", "reintentar_en": 42 }` y `Retry-After: 42` |

Los textos pueden salir en inglés (los mensajes estándar de Django REST
Framework, como los de `401` o "This field is required.") o en español (los
propios del proyecto, como el de `403`), y pueden cambiar: los clientes deciden
**siempre por el código de estado**, nunca por el texto.

### Límite de intentos (hecho 4 oct 2026)

Sin límite, quien tiene un número de póliza (son correlativos) puede adivinar la
fecha de nacimiento del titular probando días, y al acertar ve su nombre, plan y
prima. Los intentos fallidos se guardan en la base de datos (no en memoria: valen
igual con varios procesos del servidor y sobreviven a un reinicio). Al pasarse
responde `429` con `reintentar_en` (segundos) y el encabezado `Retry-After`;
mientras esté bloqueado, ni lo correcto pasa.

| Dónde | Qué se cuenta | Límite |
|---|---|---|
| `polizas/vincular` | vinculaciones **rechazadas** de ese número de póliza, sumando todas las cuentas | 5 al día |
| `polizas/vincular` | vinculaciones rechazadas de esa cuenta | 5 por hora |
| `login` | contraseñas malas para ese usuario (existente o no) | 5 por minuto |
| `login` | contraseñas malas desde esa IP | 30 por minuto |
| `registro` | intentos desde esa IP, salgan bien o mal | 30 por hora |

- Solo cuentan los **rechazos** (el registro cuenta todos): quien acierta a la
  primera nunca se topa con el límite. Los datos mal formados (`400`) no cuentan.
- Un usuario que no existe cuenta igual y responde lo mismo, así el límite no sirve
  para saber qué usuarios existen. El usuario y el número de póliza se guardan como
  un hash, nunca en claro.
- **Por qué el login se limita sobre todo por cuenta:** muchas personas pueden llegar
  con la misma IP (redes de celular, o Docker, donde todas las peticiones llegan
  con la misma). Una cuenta bloqueada no deja afuera a las demás.
- Se pueden cambiar sin tocar código con la variable de entorno
  `LIMITES_DE_INTENTOS=login_ip=300/60,registro_ip=300/3600` (máximo/segundos; tipos:
  `vincular_poliza`, `vincular_cuenta`, `login_cuenta`, `login_ip`, `registro_ip`),
  por ejemplo para probar en local. Un formato roto detiene el arranque.
- Detrás de un servidor web, la IP real viene en `X-Forwarded-For`: solo se lee con
  `NUM_PROXIES_CONFIABLES` configurado (cuántos proxies propios hay delante), porque
  cualquiera puede falsear ese encabezado. **Mientras no esté configurado, todas las
  peticiones parecen venir de la IP del proxy** (paquete 7).
- **Costo conocido:** quien conozca un número de póliza puede bloquear a su titular
  durante un día con 5 intentos malos, y quien conozca un usuario, bloquear su login
  por un minuto. Por eso el panel de administración tendrá que poder desbloquear
  (ver `panel-admin.md`).

### Qué hacen las apps (etapa 10)

- **Flutter:** trata **cualquier `401`** como "volver a iniciar sesión" (token
  vencido o inválido), con un `429` muestra el `mensaje` del servidor ("Demasiados
  intentos...", nunca "la contraseña no coincide") y no reintenta antes de
  `reintentar_en`; un `500` en el login o el registro es "algo salió mal", no un
  problema de lo que se escribió. Al cerrar sesión llama a
  `POST /api/v1/logout`. Guarda el `usuario_id` del login o el registro y se lo
  pasa a Swift en `actualizarSesion`.
- **Swift:** el `401` del `sync` ya es "token rechazado" (falla general: se corta la
  vuelta y no se pierde nada). Como cada login trae un token nuevo, Swift ya no
  decide "cambió la cuenta" por el token sino por el `usuario_id` (ver
  `actualizarSesion`).

---

## JSON #1 — Request: iOS → Backend

`POST /api/v1/sync`

Requiere `Authorization: Token <clave>` (ver "Autenticación (token)").

Se manda **el día completo cada vez**, no solo lo nuevo desde el último sync.
La idempotencia por `external_id` (constraint único del lado de Luis) hace
seguro reenviar todo — nunca hay que calcular un delta del lado del teléfono.

```json
{
  "fecha": "2026-09-03",
  "zona_horaria": "America/Guatemala",
  "pasos": [
    {
      "external_id": "3F2A9B10-6C4D-4E1A-9B2F-1D4E5C6A7B80",
      "inicio": "2026-09-03T07:12:00-06:00",
      "fin": "2026-09-03T07:19:00-06:00",
      "cantidad": 412,
      "fuente_bundle": "com.apple.health",
      "fuente_nombre": "iPhone",
      "fuente_version": "18.0",
      "dispositivo_nombre": "iPhone de Alvaro",
      "dispositivo_modelo": "iPhone",
      "dispositivo_fabricante": "Apple Inc."
    },
    {
      "external_id": "9A1B2C3D-4E5F-4061-8A2B-3C4D5E6F7081",
      "inicio": "2026-09-03T07:12:00-06:00",
      "fin": "2026-09-03T07:19:00-06:00",
      "cantidad": 430,
      "fuente_bundle": "com.huami.watch.gt",
      "fuente_nombre": "Zepp",
      "fuente_version": "9.2.1",
      "dispositivo_nombre": "Amazfit GTS",
      "dispositivo_modelo": "GTS",
      "dispositivo_fabricante": "Huami"
    }
  ],
  "sesiones": [
    {
      "external_id": "5C6D7E8F-9012-4A3B-8C4D-5E6F70819203",
      "inicio": "2026-09-03T06:30:00-06:00",
      "fin": "2026-09-03T07:05:00-06:00",
      "duracion_min": 35,
      "tipo_actividad": "running",
      "fc_promedio": 148,
      "fc_maxima": 162,
      "fuente_bundle": "com.apple.health",
      "fuente_nombre": "Apple Watch",
      "dispositivo_nombre": "Apple Watch de Alvaro",
      "dispositivo_modelo": "Watch",
      "dispositivo_fabricante": "Apple Inc."
    }
  ],
  "frecuencia_cardiaca": [
    {
      "external_id": "7E8F9012-3456-4A7B-8C9D-0E1F20314253",
      "inicio": "2026-09-03T06:30:00-06:00",
      "fin": "2026-09-03T06:31:00-06:00",
      "bpm": 140,
      "fuente_bundle": "com.apple.health",
      "fuente_nombre": "Apple Watch",
      "dispositivo_nombre": "Apple Watch de Alvaro",
      "dispositivo_modelo": "Watch",
      "dispositivo_fabricante": "Apple Inc."
    }
  ],
  "sincronizado_en": "2026-09-03T20:15:00-06:00",
  "app_version": "1.0.0"
}
```

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `fecha` | string (YYYY-MM-DD) | sí | día calendario que se está sincronizando. El servidor guarda todas las muestras que llegan y **recalcula ese día** con todo lo guardado, en hora de Guatemala. **Desde el 5 oct 2026 también recalcula los demás días a los que pertenecen las muestras del paquete** (ver "Qué días recalcula un sync") |
| `zona_horaria` | string (IANA) | sí | ej. `America/Guatemala`. El servidor valida que sea una zona IANA real, pero **hoy no la usa**: el día y la semana se cortan siempre en hora de Guatemala (`TIME_ZONE` del servidor). Para el piloto, todo en Guatemala, es lo mismo |
| `pasos[]` | array | sí (puede ir vacío) | una entrada por muestra de `HKQuantitySample` de tipo `.stepCount` **medida por un sensor**: las escritas a mano en Salud no se mandan (ver "Lo escrito a mano no cuenta") |
| `pasos[].external_id` | string (UUID) | sí | el `sample.uuid` de HealthKit — clave de idempotencia |
| `pasos[].inicio` / `.fin` | string (ISO 8601 con offset) | sí | ventana exacta de la muestra |
| `pasos[].cantidad` | int | sí | pasos en esa ventana, nunca un total ya sumado |
| `pasos[].fuente_bundle` | string | sí | bundle identifier de la fuente — la clave técnica confiable |
| `pasos[].fuente_nombre` | string | sí | nombre legible de la fuente — solo para mostrar/loggear, no para lógica |
| `pasos[].fuente_version` | string | no | versión del software de la fuente |
| `pasos[].dispositivo_nombre` | string, nullable | no | **nuevo (20 sep 2026)** — `HKDevice.name`, nombre legible del hardware físico. `null` cuando `sample.device` es `nil`, nunca string vacío |
| `pasos[].dispositivo_modelo` | string, nullable | no | **nuevo** — `HKDevice.model`. Para dispositivos Apple ya es la categoría (`iPhone`/`Watch`/`iPad`), sin tabla ni parseo |
| `pasos[].dispositivo_fabricante` | string, nullable | no | **nuevo** — `HKDevice.manufacturer`. Puede venir nulo en apps puente de terceros |
| `sesiones[]` | array | sí (puede ir vacío) | una entrada por `HKWorkout` **que tenga ritmo cardíaco y no sea manual** (ver "Qué cuenta como workout"). De **cualquier duración** (decidido 1 oct 2026): los 30 min mínimos solo aplican a los puntos de intensidad, no a contar un workout |
| `sesiones[].external_id` | string (UUID) | sí | el `sample.uuid` del workout — clave de idempotencia |
| `sesiones[].inicio` / `.fin` | string (ISO 8601) | sí | ventana del workout |
| `sesiones[].duracion_min` | int | sí | duración en minutos |
| `sesiones[].tipo_actividad` | string, **nullable** | no | tipo de `HKWorkoutActivityType` en texto plano. **`null` es válido** — un reloj de terceros (ej. WHOOP) puede detectar el workout automáticamente pero no tener confianza suficiente para clasificarlo, y eso puede quedar sin corregir indefinidamente si el usuario nunca lo edita a mano. El backend nunca lo rechaza por venir nulo; se guarda tal cual y se muestra como "No registrado" |
| `sesiones[].fc_promedio` / `.fc_maxima` | int (bpm) | sí | FC durante la ventana de la sesión. **Siempre un valor medido**: si no hubo muestras de ritmo cardíaco en la ventana, Swift no manda la sesión (nunca manda `0`) |
| `sesiones[].fuente_bundle` / `.fuente_nombre` | string | sí | mismo criterio que pasos[] |
| `sesiones[].dispositivo_nombre` / `.dispositivo_modelo` / `.dispositivo_fabricante` | string, nullable | no | **nuevo** — mismo criterio que pasos[] |
| `frecuencia_cardiaca[]` | array | sí (puede ir vacío) | una entrada por muestra `.heartRate` **medida** del día completo, esté o no dentro de un workout. Las escritas a mano no se mandan |
| `frecuencia_cardiaca[].external_id` | string (UUID) | sí | misma clave de idempotencia |
| `frecuencia_cardiaca[].inicio` / `.fin` | string (ISO 8601) | sí | ventana exacta |
| `frecuencia_cardiaca[].bpm` | int | sí | valor de la muestra |
| `frecuencia_cardiaca[].fuente_bundle` / `.fuente_nombre` | string | sí | mismo criterio que pasos[] |
| `frecuencia_cardiaca[].dispositivo_nombre` / `.dispositivo_modelo` / `.dispositivo_fabricante` | string, nullable | no | **nuevo** — mismo criterio que pasos[] |
| `sincronizado_en` | string (ISO 8601) | sí | cuándo el teléfono armó el payload |
| `app_version` | string | sí | versión de la app. Hoy el servidor solo exige que venga; todavía no rechaza versiones viejas |

**`usuario_id` ya no va en este JSON (30 sep 2026).** El servidor saca al usuario
del token (ver "Autenticación (token)"). **Transición:** una versión vieja de la
app que todavía lo mande no se rechaza: el servidor lo ignora.

**Alcance:** se manda el día completo cada vez, no solo lo nuevo — idempotencia
por `external_id` hace seguro reenviar todo. **Fuera de alcance:** sueño.

**Cuándo NO se manda un día:** el sync manual de "hoy" manda el día aunque esté
completamente vacío. La cola de reintentos y ponerse al día ("Cuándo se manda
cada día") **saltan** los días vacíos — un payload vacío es indistinguible entre "sin
actividad" y "permiso negado", y mandarlo haría que Luis lo diera por
entregado para siempre. Ver "Días sin actividad" más abajo.

### Tipo de dispositivo — derivado en el servidor (confirmado 20 sep 2026)

*Detalle completo del problema, la investigación y las alternativas descartadas
en `decision-tipo-dispositivo.md` — acá solo lo que queda vigente para
construir.*

`fuente_bundle`/`fuente_nombre`/`fuente_version` describen la **app** que
escribió la muestra (`HKSource`), no el **hardware** que la generó. Una
muestra de pasos del iPhone y una del Apple Watch pueden compartir el mismo
`fuente_bundle` (`com.apple.health`) — sin los campos `dispositivo_*` nuevos,
el backend no tenía cómo saber cuál muestra vino del reloj, lo que bloqueaba
la regla de precedencia de la sección 7 de `reglas-puntaje-vivo.md`.

**Principio: el teléfono manda campos crudos de `HKDevice`; el servidor deriva
la categoría.** Igual que con los puntos, no se manda `tipo_dispositivo` ya
resuelto desde el cliente — así una reclasificación de marca no exige tocar la
app.

**Derivación de `tipo_dispositivo` ∈ `{ telefono, reloj, anillo, desconocido }`**,
en este orden:

1. Si `dispositivo_modelo` es de Apple (`iPhone`, `Watch`, `iPad`) → mapeo
   directo, sin tabla.
2. Si no, buscar `fuente_bundle` en la tabla de bundles conocidos (match por
   prefijo, no por igualdad exacta):

   ```python
   BUNDLE_A_TIPO = {
       "com.garmin.connect":  "reloj",
       "com.whoop":           "reloj",
       "com.huami":           "reloj",   # Zepp / Amazfit
       "com.fitbit":          "reloj",
       "com.ouraring":        "anillo",
       # se amplía según lo que aparezca en el piloto
   }
   ```
3. Si tampoco, usar `dispositivo_fabricante` como refuerzo si vino lleno.
4. Si nada aplica → `desconocido`.

**`desconocido` se trata como `telefono`** — nunca se excluye la muestra ni se
marca el día como sospechoso. Contar de menos es preferible a acusar a alguien
con una fuente no reconocida (pulsera barata, app puente rara).

**Desde el 1 oct 2026 el puntaje ya no usa `tipo_dispositivo`.** La elección
de fuente (ver "Elección de fuente") compara dispositivos entre sí por la
combinación `fuente_bundle` + `dispositivo_modelo` + `dispositivo_fabricante`,
sin importar si son reloj, anillo o teléfono. La derivación de arriba se
conserva para reportes y para saber qué dispositivo es cada uno, pero
"`desconocido` se trata como `telefono`" ya no cambia ningún puntaje.

### Elección de fuente — por bloques (decidido 1 oct 2026; bloques desde el 5 oct 2026)

Reemplaza la regla anterior "si hay reloj ese día, el reloj gana", que dejaba en
cero a quien usa el reloj solo para dormir o solo para entrenar. **Nunca se
suma la misma actividad dos veces, y nunca se descarta actividad real.**

| Métrica | Regla |
|---|---|
| **Pasos** | En cada **bloque** gana el dispositivo con más pasos; después se suman los bloques. Un bloque es **una hora** (hora de Guatemala) o, si una muestra de **más de una hora** las cubre, esas horas juntas (ver "Pasos por bloques"). Una muestra corta cuenta en la hora en que **empieza**. |
| **Workouts** | Si dos dispositivos registran el mismo entrenamiento (se cruzan en el tiempo) cuenta **uno**, el más largo. Los que no se cruzan cuentan todos, aunque vengan de dispositivos distintos. |
| **Intensidad** | Cada dispositivo calcula la suya con sus propias sesiones y su propio ritmo cardíaco; gana el de más puntos. No se suman. |

Ejemplos: reloj solo de noche + teléfono de día → se cuentan los pasos del día
del teléfono y los de la noche del reloj. Teléfono en el locker y reloj en el
gym → en la hora del gym gana el reloj, el resto del día el teléfono.

El día se **recalcula completo en cada sync** de esa fecha, a partir de lo
guardado y no del último payload: un reloj de terceros que escribe a Apple
Salud con horas de retraso corrige el resultado solo (con una fila de ajuste en
el ledger, nunca editando una existente).

### Pasos por bloques (hecho 5 oct 2026)

Una app que escribe un total de varias horas de golpe (una pulsera con "11.000
pasos de 8:00 a 18:00") antes caía entera en la hora en que empieza, y el iPhone
ganaba las otras nueve: 12.000 pasos reales se contaban como 21.800.

- Una muestra de **más de una hora** es larga: las horas que cubre se **funden en
  un solo bloque** (y dos muestras largas que se cruzan, en uno). En cada bloque
  gana el dispositivo con más pasos; no se suman. Una muestra de justo una hora o
  menos es corta.
- Las muestras **cortas** siguen contando en la hora en que empiezan, **aunque
  crucen el cambio de hora** (8:51 a 9:09 cuenta en la hora 8). Si no, las lecturas
  normales del iPhone encadenarían todo el día en un bloque y un reloj usado solo
  en el gimnasio perdería su hora.
- Una muestra que **cruza la medianoche** se reparte entre los dos días en
  proporción al tiempo que pasa en cada uno; lo repartido suma siempre la cantidad
  original (se calcula con el acumulado de cada borde, sin perder un paso por
  redondeo). Una lectura sin duración cuenta entera en el día en que ocurre.
- Una muestra de todo el día (0:00 a 24:00) compara el día entero: gana el
  dispositivo con más pasos en total.

### Qué días recalcula un sync (hecho 5 oct 2026)

El sync nombra un día, pero cada muestra pertenece a un día: una que cruza la
medianoche, un teléfono en otra zona horaria o un dato que el reloj sube tarde
pueden viajar en el paquete de otro día. Antes se guardaban sin recalcular su
día, que se quedaba con los puntos viejos hasta que alguien lo volviera a mandar.

- El servidor recalcula **el día del sync y todos los días a los que pertenecen
  las muestras del paquete**, del más viejo al más nuevo y en la misma
  transacción. Los pasos pertenecen a todos los días que cubren; los workouts y el
  ritmo cardíaco, al día en que empiezan.
- Solo dentro de la **ventana de 14 días** y hasta hoy. Lo más viejo o futuro se
  guarda pero no se recalcula (y no responde error). Un ciclo ya cerrado (semana,
  liga) no se reabre: se corrigen los puntos y el historial, no el cierre.
- La respuesta del sync sigue siendo la del día que nombra `fecha`.

### Qué cuenta como workout (decidido 1 oct 2026)

Un workout necesita **ritmo cardíaco medido**, o sea un reloj o una banda. Con
solo el teléfono no se registran workouts.

- **Sin ritmo cardíaco no hay workout.** Swift no manda la sesión si no hay
  muestras de ritmo cardíaco en su ventana. Si aun así llega con
  `fc_promedio` y `fc_maxima` en `0`, el servidor la descarta (responde `200`;
  se cuenta aparte en el log como `sesiones_sin_ritmo_cardiaco`, distinto de un
  dato imposible).
- **Los workouts ingresados a mano no cuentan.** Son demasiado fáciles de
  inventar. Swift no los manda (`HKMetadataKeyWasUserEntered`). Tampoco cuenta
  el ritmo cardíaco escrito a mano dentro de un workout: `fc_promedio` y
  `fc_maxima` salen solo de las lecturas medidas dentro de su ventana (promedio
  simple de esas lecturas).
- Un workout que cuenta suma a `workouts_dia` (dashboard) y al objetivo
  semanal, además de a los puntos de intensidad.
- **Duración coherente (5 oct 2026):** la `duracion_min` no puede ser **mayor** que el
  tiempo entre `inicio` y `fin` (puede ser menor: las pausas no cuentan). Se tolera el
  minuto del redondeo (34 min 40 s se manda como 35). Una sesión que no cumple se
  descarta como cualquier muestra imposible: se cuenta en `descartadas`, el resto del
  paquete se acepta y la respuesta es `200`. Es porque los puntos de intensidad salen
  de `duracion_min` (30, 60 o 90): un error o una falsificación podía dar 150 puntos
  por "95 minutos" en un entrenamiento de 10:00 a 10:10.
- **Duración (decidido 1 oct 2026):** cualquier workout, de cualquier duración,
  cuenta para `workouts_dia` y para el objetivo semanal. Los 30 minutos mínimos
  son solo para ganar **puntos de intensidad** (un workout de 10 min cuenta
  como workout y da 0 puntos de intensidad).
- Las sesiones intensas que el servidor **infiere** del ritmo cardíaco (sin un
  workout registrado) dan puntos de intensidad, pero **no** cuentan como
  workout.

### Lo escrito a mano no cuenta (decidido 1 oct 2026)

Cualquiera puede inventar datos en la app Salud (Explorar › Actividad ›
Pasos › Añadir datos) en menos de un minuto: 15.000 pasos escritos a mano darían
100 puntos y cashback. Por eso **Swift no manda nada que la persona haya
escrito a mano**, sea cual sea el tipo: pasos, ritmo cardíaco o workouts. Apple
marca esas lecturas con `HKMetadataKeyWasUserEntered`; sin esa marca se asume
que la lectura es medida (un reloj de terceros suele no escribirla).

El filtro está en Swift y no en el servidor porque el servidor no recibe esa
marca: el JSON #1 no la trae. Así se mantiene el principio de que el teléfono
no manda conclusiones, solo datos crudos: lo manual simplemente no es un dato
medido.

**Alcance honesto:** esto frena el engaño fácil, no todo. Una app que escriba
datos falsos por programa no viene marcada como manual y HealthKit no puede
probar su origen. Ver "Puntos abiertos".

---

## JSON #2 — Response: Backend → iOS

Respuesta síncrona al mismo `POST /api/v1/sync`. Se mantiene mínima a
propósito: solo lo que la app necesita confirmar de inmediato. Todo lo demás
(objetivo semanal, historial, catálogo de premios) Daniel lo pide después por
HTTP directo contra la API de Luis — no viaja por acá.

```json
{
  "fecha": "2026-09-03",
  "puntos_pasos": 50,
  "puntos_intensidad": 100,
  "puntos_dia": 150,
  "tope_diario_aplicado": false,
  "puntos_ano": 3240,
  "tope_anual_aplicado": false,
  "nivel": 1,
  "pasos_totales_dia": 8420
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `fecha` | string (YYYY-MM-DD) | eco del día sincronizado |
| `puntos_pasos` | int | tabla de pasos: 7.000–9.999 = 25, 10.000–14.999 = 50, 15.000+ = 100. Debajo de 7.000: 0. **+25** si la persona tiene 60 años o más y ganó algo por pasos |
| `puntos_intensidad` | int | FCM = 219 − edad. Escalón de **la mejor sesión del día** (no se suman): 30 min al 60% = 50, 30 min al 70% = 100, 60 min al 60% = 100, 90 min al 60% = 150. Cuentan los workouts y las sesiones que el servidor infiere del ritmo cardíaco. **+25** con 60 años o más si ganó algo por intensidad |
| `puntos_dia` | int | suma de los dos anteriores, con el techo diario de 200 pts ya aplicado. **Es lo que calculó el día, no necesariamente lo acreditado:** no refleja el techo anual ni un día anulado por retroactivo. Lo acreditado está en `GET /api/v1/historial` y, desde el 5 oct 2026, también en `dashboard/resumen` |
| `tope_diario_aplicado` | bool | true si los puntos brutos pasaron de 200 (llegar a 200 justos no es recorte) |
| `puntos_ano` | int | lo acreditado en el **año de póliza** en curso (desde la fecha de inicio o la última renovación de la póliza; suma del ledger), con el techo de 12.000 ya aplicado (hecho el 4 oct; ver "Cashback en quetzales"). Es el año **en curso**, aunque el día sincronizado sea de uno anterior. Sin póliza verificada es el año calendario, solo de referencia |
| `tope_anual_aplicado` | bool | true si el techo del año de póliza **recortó lo de este día** |
| `nivel` | int (0–4) | nivel de cashback del **año de póliza**, según `puntos_ano`: 0 bajo 2.500, 1 desde 2.500 (5%), 2 desde 5.000 (7,5%), 3 desde 10.000 (10%), 4 desde 15.000 (20%) — no confundir con el **objetivo semanal** (ver abajo) |
| `pasos_totales_dia` | int | total de pasos del día con la regla por bloques (ver "Elección de fuente"). Nunca es una suma cruda de `pasos[].cantidad` de dispositivos distintos |

No incluye ningún campo que explique *por qué* se descartó una muestra, se
detectó una sesión intensa, o se aplicó un techo — esa lógica es del backend.

**Techo anual de 12.000 (por año de póliza):** con el chequeo médico fuera de v1, ese es el máximo
alcanzable solo por actividad — Nivel 4 (15.000+) queda fuera de alcance en el
piloto. Consecuencia aceptada y documentada, no un bug.

**`nivel` (anual, cashback) ≠ objetivo semanal.** Dos conceptos completamente
distintos con nombres que se prestan a confusión — por eso el objetivo semanal ya
no usa la palabra "nivel" en ningún lado: en código y en respuestas de API
nunca deben compartir el mismo nombre de campo.

### Errores de `POST /api/v1/sync`

Swift decide **por el código de estado**, nunca por el texto:

| Código | Cuándo | Qué hace Swift |
|---|---|---|
| `200` | Guardado | Confirma el día |
| `400` | Payload inválido | Error permanente: no se reintenta |
| `401` | Falta el token o es inválido | **No es permanente.** No envía (o deja de enviar) y el día queda pendiente; **no corta los demás días** ni saca el día de la cola |
| `403` | La cuenta no tiene perfil de usuario | Error permanente: no se reintenta |
| `408`, `429`, `5xx` | Tiempo agotado, demasiadas peticiones o caída del servidor | Se reintenta (el día va a la cola) |
| `422` | `fuera_de_ventana` | Ver "Ventana de aceptación de datos rezagados" |

Todas las filas describen lo que Swift hace hoy (la de `401` desde el 30 sep).

#### Qué hace el servidor con datos raros

Hay dos niveles, y no se confunden:

| Caso | Respuesta |
|---|---|
| **Mal formado** — falta un campo obligatorio de la raíz (`fecha`, `zona_horaria`, `sincronizado_en`, `app_version`), una muestra no trae un campo requerido (por ejemplo `external_id`), un tipo es incorrecto, `zona_horaria` no es una zona IANA válida, `fecha` es más de un día en el futuro, o un número que no puede ser negativo lo es (`cantidad`, `bpm`, `duracion_min`, `fc_promedio`, `fc_maxima`) | `400` con el detalle por campo, por ejemplo `{ "pasos[0]": { "external_id": ["This field is required."] } }` o `{ "fecha": ["La fecha no puede ser futura."] }`. **Todo el sync se rechaza.** |
| **Físicamente imposible** — esa muestra se descarta y el resto se acepta | `200`. No hay forma de saber desde el cliente qué se descartó (se cuenta en el log del servidor) |

Una muestra se descarta, sin tumbar el sync, si:

- **pasos:** `cantidad` mayor que 30.000 en una sola muestra (30.000 exactos sí entra), o `fin` anterior a `inicio`;
- **ritmo cardíaco:** `bpm` menor que 30 o mayor que 230, o `fin` anterior a `inicio`;
- **sesión:** duración de 0 min o de más de 24 h, `fc_promedio` o `fc_maxima` fuera de 30 a 230, `fc_maxima` menor que `fc_promedio`, o `fin` anterior a `inicio`. Una sesión con `fc_promedio` y `fc_maxima` en `0` se descarta por la regla de "Qué cuenta como workout" y se cuenta aparte en el log.

Ojo con la frontera: un valor **negativo** es un dato mal formado (rechaza todo
el sync con `400`); un valor positivo pero absurdo (31.000 pasos en una muestra)
solo se descarta.

Las cifras vienen de lo que ya impone la base de datos (en PostgreSQL una
restricción rota tumba todo el `INSERT`, y en SQLite se ignora en silencio),
por eso se aplican antes: el resultado no depende del motor.

Si el servidor no tiene ninguna versión de reglas vigente responde `500`, y
Swift reintenta los `5xx`. **Una base migrada ya la trae:** la migración
`poincs/0007` carga la versión 1 (vigente desde el 1 ene 2026) y la `0008` la
versión 2 (desde el 2 oct 2026), así que un
despliegue limpio con `migrate` no tiene este problema. Solo ocurriría si
alguien borra la versión. Cada fila del ledger queda sellada con la versión
vigente en la fecha del día que puntúa.

---

## Mecánica de objetivos semanales (fuera del payload de sync)

*Antes "mecánica de retos semanales" — el nombre "reto" ya no existe, todo es
objetivo semanal.*

Por dificultad progresiva, no por meta de puntos. **No hay rachas diarias** —
si aparecen en algún doc de pantallas, es material viejo. La progresión
numérica (1, 2, 3...) se llama **objetivo semanal** — nunca "nivel", para no
confundirla con el nivel anual de cashback del JSON #2.

### Demo 1 (acordado 23 sep; cambios del 2 oct) — objetivo sin progresión

En el demo 1 el objetivo **no progresa**: no sube ni se congela según lo que
cumpla cada uno.

- **Duración siempre igual:** lunes 00:00 a domingo 23:59.
- **Dos componentes:** (a) **pasos totales de la semana** y (b) **cantidad de
  workouts**. Ejemplo: "30.000 pasos y mínimo 1 workout".
- **Cada componente paga sus monedas por separado** (decidido 2 oct 2026):
  cumplir los pasos paga lo suyo aunque no se cumplan los workouts, y al revés.
  Montos **provisionales: 5 por pasos + 5 por workouts** (la reunión los dio
  como ejemplo).
- La semana se marca **completada** solo si se cumplen **los dos**.
- **La meta de pasos depende del rango de edad**, de 10 en 10 años (decidido
  2 oct 2026). La edad sale de la fecha de nacimiento **confirmada por la
  aseguradora** si hay póliza verificada; si no, de la del registro (la misma
  regla que usan los puntos). La meta de workouts es igual para todos.
  **Tabla provisional** (2 oct 2026), ver "Meta de pasos por edad" abajo.
- **No se sube ni se congela objetivo** en el demo. La sección "Diseño
  completo" de abajo **se mantiene como diseño**.
- Los valores (metas y monedas) viven en una tabla del backend, editable a
  mano — sin cálculo.

**Hecho en el código (3 oct):** `services/goals.py`. La meta de pasos sale de la
tabla `MetaPasosPorEdad` (editable en el admin) con la edad del usuario **el
lunes de esa semana**: quien cumple años a media semana conserva la meta de su
rango anterior hasta la semana siguiente. La meta de workouts y las monedas de
cada componente viven en `ObjetivoSemanal`, también editables, y cada semana
nueva copia las de la anterior. Un componente con 0 monedas no escribe nada en
el ledger.

### Meta de pasos por edad — tabla provisional (2 oct 2026)

| Edad | Pasos al día | Meta semanal de pasos |
|---|---|---|
| 18 a 29 | 7.000 | 49.000 |
| 30 a 39 | 7.000 | 49.000 |
| 40 a 49 | 6.500 | 45.000 |
| 50 a 59 | 6.000 | 42.000 |
| 60 a 69 | 5.000 | 35.000 |
| 70 o más | 4.500 | 31.000 |

**De dónde sale.** Queda entre lo que la gente camina medido con el teléfono y
lo que recomienda la evidencia de salud:

- Medido con teléfono o podómetro, un adulto camina unos **5.000 pasos al día**:
  4.961 en promedio con iPhone en 111 países y 4.692 en México (Althoff et al.,
  *Nature* 2017); entre 5.843 (18 a 29 años) y 4.027 (60 o más) con podómetro en
  EE. UU. (Bassett et al., 2010). Un acelerómetro en la cintura cuenta casi el
  doble (10.700 en ocho países de Latinoamérica, estudio ELANS 2021), porque el
  teléfono no siempre va encima. +Vida mide con iPhone y, a veces, reloj: la
  referencia que aplica es la del teléfono.
- El beneficio en mortalidad se aplana en **6.000 a 8.000 pasos al día con 60
  años o más** y en **8.000 a 10.000 con menos de 60** (Paluch et al., *Lancet
  Public Health* 2022).
- Arranca en 7.000 al día porque es el primer escalón de puntos diarios (25
  puntos). No hay datos publicados de Guatemala.

**Es provisional:** después de 2 a 4 semanas de piloto se ajusta con los pasos
reales de los usuarios de cada rango, que miden exactamente como mide la app.
La edad sale de la fecha confirmada por la aseguradora si hay póliza
verificada; si no, de la del registro. **Hecho en el código (3 oct):** la tabla
se carga con la migración `objetivos/0002`. Un menor de 18 usa, mientras no se
decida otra cosa, la fila de 18 a 29 (ver "Puntos abiertos").

### Vista de semanas tipo "battle pass" (decidido 2 oct 2026)

Cada semana es una caja, con scroll horizontal para ver las semanas pasadas y
las que vienen. Muestra **las semanas de la season en curso** (13, o 14 cuando
incluye la semana 53). Cada caja necesita: número de semana, fechas, metas,
monedas de cada componente, estado (completada, un componente cumplido, en
curso o futura) y el **logo del patrocinador** si esa semana está vendida. Lo
pidió la reunión para mostrar mejor la marca.

**Hecho en el código (3 oct):** `GET /api/v1/objetivos/semanas` (ver abajo).
**Hecho en el código (4 oct):** `patrocinador` trae la marca de cada semana
vendida (ver "Patrocinios"); en las demás viene en `null`.

### Diseño completo — cómo se mueve el objetivo semanal (se mantiene; vuelve después del demo)

- Todos arrancan en **objetivo semanal 1** al inicio de cada season.
- Completar la meta de la semana → sube al **siguiente objetivo** la semana
  siguiente.
- **No completarla → el objetivo se congela** (se queda igual, misma meta la
  semana siguiente). **No baja.**
- La dificultad aumenta con el objetivo — tabla a definir por Luis (L11).
- Techo real de diseño: **~13 objetivos** (una season dura 13 semanas).

### Seasons (redefinidas el 2 oct 2026)

El año se divide en **4 seasons de 13 semanas completas**, iguales para todos.
Empiezan siempre un **lunes** y siguen las **semanas ISO** (la semana 1 es la
que contiene el 4 de enero):

| Season | Semanas ISO |
|---|---|
| 1 | 1 a 13 |
| 2 | 14 a 26 |
| 3 | 27 a 39 |
| 4 | 40 a 52, más la **53** en los años que la tienen |

Ejemplos: **2026 tiene 53 semanas**, así que la season 4 de 2026 va del lunes
28 sep 2026 al domingo 3 ene 2027 (14 semanas). En 2027 la season 1 empieza el
lunes 4 ene 2027.

- Afectan el **objetivo semanal** y las **monedas** (el saldo se reinicia al
  cerrar la season; ver "Monedas y seasons"). **No** tocan los puntos anuales
  ni el cashback, que siguen el **año de póliza**, ni La Liga, que sigue el mes
  de calendario.
- Al cerrar una season, todos vuelven a **objetivo 1** (diseño completo).
- Cada season queda en el historial del usuario, con el **objetivo máximo**
  alcanzado.
- Como toda season empieza en lunes, **nunca parte una semana**. Esto
  reemplaza la regla anterior (corte el 1 de enero, abril, julio y octubre,
  aunque cayera a media semana).

**Hecho en el código (2 oct):** `services/tiempo.py` calcula las seasons por
semanas ISO (`numero_season`, `anio_season` y `rango_season`). El año de la
season es el **año ISO**: el 3 ene 2027 todavía es de la season 4 de 2026, y el
29 dic 2025 ya es de la season 1 de 2026. `GET /api/v1/objetivos/estado` devuelve
esa season, su `fecha_cierre` (domingo de cierre) y cuántas semanas tiene. La tabla `Season` se llena
sola al pedir la season, y corrige las filas que se hayan guardado con la regla
vieja de trimestres.

### Monedas y seasons (decidido 2 oct 2026)

- **Sin tope de acumulación.** Reemplaza el tope de 100.
- **Todas las monedas caducan al cerrar la season:** el saldo vuelve a 0.
  Reemplaza la caducidad de 90 días por cada ganancia.
- **Orden al cambiar de season:** el saldo se reinicia el lunes 00:00 en que
  empieza la season, y la semana que acaba de terminar se paga **después**, en
  su cierre del martes 00:00. Así las monedas de la última semana cuentan en la
  season nueva.
- **Aviso:** se quita el aviso al llegar a 80 (existía por el tope). En su
  lugar se avisa **7 días antes** de que termine la season.
- Sin póliza verificada se ganan igual pero no se pueden gastar, y al cerrar la
  season se reinician como las demás.
- Los **cupones ya canjeados** no cambian con las seasons y caducan aparte, a las **3 semanas** del
  canje (21 días; hasta el 5 oct eran 60).

**Hecho en el código (2 oct):** `services/monedas.py`.

- Cada ganancia **caduca el domingo en que cierra la season en que se ganó**, y
  ese día todavía se puede usar. El vencimiento se calcula **siempre de la
  season de la fecha de la ganancia**, no de lo que haya quedado guardado en
  `fecha_expiracion`: así las filas anteriores (guardadas con 90 días) también
  siguen la regla nueva.
- **El reinicio no necesita un proceso aparte.** Antes de leer o mover el saldo
  se asientan las monedas vencidas con una fila `expiracion` negativa (el ledger
  no se edita). Por eso el orden al cambiar de season sale solo: como la semana
  que terminó se paga con la fecha de su cierre (el martes 00:00; el lunes es
  margen de gracia) y las seasons empiezan en lunes, ese martes ya es de la
  season nueva: primero se reinicia y después entra lo nuevo.
- Las monedas se acreditan **sin tope**.
- El servicio calcula cuántos días faltan para el cierre y si ya toca el aviso
  (desde 7 días antes, inclusive el último domingo). Los dos vienen en
  `season.dias_para_cierre` y `season.aviso_fin_de_season` de
  `objetivos/estado` y `objetivos/semanas`.
- **Hecho (3 oct):** `GET /api/v1/monedas/saldo`, que es lo que la app lee para
  mostrar las monedas y el aviso. Ver "Premios, canje y cupones".

### Ciclos y cortes

- Ciclo semanal: **lunes 00:00 a domingo 23:59** — separado del ciclo de La Liga (día 1 al último día del mes calendario, premiada en monedas).
- **El objetivo de la semana nueva se fija de inmediato al arrancar, lunes
  00:00**, con los datos que hay hasta el corte del domingo 23:59. El usuario
  no ve ningún estado intermedio — la semana nueva ya aparece corriendo con
  normalidad desde las 00:00, sin pantalla de "evaluando" ni aviso de cambio
  de objetivo.
- **Margen de gracia (decidido 3 oct 2026): el resultado de la semana se fija
  el martes 00:00.** Los datos atrasados del domingo tienen **todo el lunes**
  para llegar (por ejemplo, de alguien que no abrió la app el domingo) y
  cuentan para `cumplido` y para las monedas. El martes 12:00 una corrida de
  corrección actualiza los acumulados, pero ya no cambia `cumplido` ni paga. Un
  ciclo cerrado no se reabre. Antes se cerraba el lunes 00:00 y un domingo que
  llegaba tarde nunca completaba el objetivo (StepBet da 24 h; Discovery
  Vitality, 48 h).
- **El lunes**, la semana que terminó el domingo todavía no tiene resultado:
  `GET /api/v1/objetivos/semanas` la devuelve con `estado: "en_revision"` hasta
  el martes.
- Huso horario: **zona horaria de Guatemala**, por ahora — para el piloto
  (todo Guatemala) una sola corrida alcanza.

**Nota:** con esto, un día atrasado que llega después del cierre del martes ya
no puede subirle ni bajarle el objetivo a nadie — solo cuenta para el historial y
el acumulado anual. Es una simplificación deliberada: como
el objetivo ya no baja (se congela), el peor caso de decidir temprano es que
alguien no suba de objetivo esa semana aunque en realidad sí había cumplido —
no se pierde progreso acumulado, solo una semana de avance.

**Por qué esto no viaja en el JSON #2:** cambia una vez por semana (o una vez
por season), no en cada sync — incluirlo repetiría el mismo dato sin
necesidad. Daniel lo consulta por HTTP directo: `GET /api/v1/objetivos/estado`
(tickets L11 y D12), que también devuelve la season actual, su fecha de
cierre, y el historial de seasons pasadas. *Hasta el 3 oct se llamaba
`GET /api/v1/retos/estado`; se renombró junto con el cambio de respuesta, antes
de que la app lo consumiera. La ruta vieja ya no existe (404).*

**Respuesta de `GET /api/v1/objetivos/estado`** (con token; desde el 3 oct):

```json
{
  "semana": { "numero": 2, "fecha_inicio": "2026-10-05", "fecha_fin": "2026-10-11" },
  "pasos": { "meta": 45000, "monedas": 5, "acumulados": 46000, "cumplido": true },
  "workouts": { "meta": 1, "monedas": 5, "acumulados": 0, "cumplido": false },
  "completada": false,
  "season": {
    "numero": 4,
    "anio": 2026,
    "fecha_inicio": "2026-09-28",
    "fecha_cierre": "2027-01-03",
    "semanas": 14,
    "dias_para_cierre": 88,
    "aviso_fin_de_season": false
  },
  "historial_seasons": []
}
```

- Todo es del usuario que pregunta. `semana.numero` es la semana **dentro de la
  season** (1 a 13, o 14).
- `pasos.meta` es la del **rango de edad del usuario** (ver "Meta de pasos por
  edad"); `workouts.meta` es igual para todos. La app **no calcula** ninguna de
  las dos.
- `monedas` es lo que paga **ese componente** al cerrar la semana, aunque el
  otro no se cumpla. `cumplido` dice si el componente ya alcanzó su meta.
- `completada` es `true` solo con los dos componentes cumplidos.
- `season.anio` es el año ISO de la season; `dias_para_cierre` cuenta hasta el
  domingo de cierre (0 ese domingo) y `aviso_fin_de_season` se pone en `true`
  desde 7 días antes: es el aviso de que las monedas se reinician.
- `historial_seasons` viene vacío en el demo (no hay objetivo máximo que
  registrar mientras no haya progresión).
- `403` si la cuenta no tiene perfil de usuario; `401` sin token.

**Respuesta de `GET /api/v1/objetivos/semanas`** (con token; vista tipo "battle
pass"): la misma `season` y **todas las semanas de la season en curso**, en
orden.

```json
{
  "season": { "numero": 4, "anio": 2026, "fecha_inicio": "2026-09-28", "...": "..." },
  "semanas": [
    {
      "numero": 1,
      "fecha_inicio": "2026-09-28",
      "fecha_fin": "2026-10-04",
      "estado": "parcial",
      "pasos": { "meta": 45000, "monedas": 5, "acumulados": 46000, "cumplido": true },
      "workouts": { "meta": 1, "monedas": 5, "acumulados": 0, "cumplido": false },
      "patrocinador": null
    },
    {
      "numero": 3,
      "fecha_inicio": "2026-10-12",
      "fecha_fin": "2026-10-18",
      "estado": "futura",
      "pasos": { "meta": 45000, "monedas": 5, "acumulados": null, "cumplido": null },
      "workouts": { "meta": 1, "monedas": 5, "acumulados": null, "cumplido": null },
      "patrocinador": null
    }
  ]
}
```

- `estado`: `completada` (los dos componentes), `parcial` (uno solo),
  `no_cumplida` (ninguno), `en_curso`, `en_revision` o `futura`.
- **`en_revision` (3 oct):** el lunes, la semana que terminó el domingo sigue en
  su margen de gracia hasta el cierre del martes 00:00 (ver "Ciclos y cortes").
  Sus `acumulados` y `cumplido` vienen **en vivo y son provisionales**: todavía
  pueden llegar datos del domingo. La app no la muestra como cumplida ni como no
  cumplida.
- Las semanas cerradas muestran lo que quedó guardado al cerrarlas, **con la
  meta que se usó ese día** aunque después se edite la tabla. Si ya pasó el
  margen y el cierre no corrió (por ejemplo, falló), se calculan en vivo.
- En las `futura`, `acumulados` y `cumplido` vienen en `null`: solo se conocen
  la meta y las monedas, que todavía se pueden editar en el admin.
- `patrocinador` es la marca que compró esa semana (misma forma que el
  `patrocinio` de La Liga, ver "Patrocinios") o `null` si no tiene. Sale en las
  pasadas, la en curso y las futuras.

**Cómo está construido hoy (backend, 3 oct):**

- La meta de pasos sale de `MetaPasosPorEdad`; la de workouts y las monedas de
  cada componente, de `ObjetivoSemanal`. Todo se edita a mano en el admin. Cada
  semana nueva copia la meta de workouts y las monedas de la anterior; la
  primera arranca con 1 workout y 5 + 5 monedas.
- El avance se calcula en vivo: la suma de `pasos_totales_dia` y de workouts
  de `resumen_diario` de lunes a domingo.
- El cierre lo hace el comando `cerrar_semana`: a las **00:00 del martes** (el
  lunes es margen de gracia) guarda, por usuario, la meta de pasos que se usó, si
  cumplió cada componente y si completó la semana, y **paga cada componente
  cumplido por separado** (una fila `objetivo_cumplido` por componente). Con
  `--correccion`, a las **12:00 del martes**, solo actualiza los acumulados (no
  cambia el resultado ni paga). Antes del martes no cierra nada: el margen vive
  en `goals.DIAS_DE_GRACIA` (1 día) y vale también para la puesta al día, así que
  un servidor que arranca un lunes no cierra la semana antes de tiempo. Correrlo
  dos veces no paga dos veces. Lo dispara el servicio `programador` (ver "Cierre
  semanal programado").
- Las semanas que se cerraron antes del 3 oct (cuando se pagaba todo junto) se
  completan con la migración `objetivos/0002`: si estaban cumplidas quedan con
  los dos componentes cumplidos; las monedas que ya se pagaron no se tocan.
- Las monedas se ganan **con o sin póliza**; lo que exige póliza verificada es
  **gastarlas**. Sin tope, y caducan al cerrar la season (hecho el 2 oct; ver
  "Monedas y seasons").
- Los días anulados por **retroactivo denegado** (ver "Retroactividad") **no
  cuentan** para el progreso de la semana (decidido y hecho el 5 oct 2026): la
  semana que cruza la verificación solo cuenta desde ese día. Los pasos de esos días
  siguen guardados y visibles en Progreso. Las monedas de una semana que cerró
  antes de la verificación se anulan; las de una que cierra después se pagan con lo
  que cuenta.

### Cierre semanal programado (1 oct; martes desde el 3 oct)

**Quién lo corre.** El servicio `programador` de `mas-vida_backend/compose.yaml`,
que ejecuta `python manage.py programador`:

- **Al arrancar se pone al día:** cierra las semanas que ya pasaron su margen de
  gracia y sigan sin cerrar, hasta **4 semanas atrasadas** (más viejas se omiten y queda un aviso en
  el log, para no pagar monedas de hace meses al arrancar por primera vez).
- **Martes 00:00** → cierre: fija `cumplido` y paga. También pone al día lo que
  haya quedado pendiente, así que **un martes que falló se recupera solo** en la
  corrida siguiente.
- **Martes 12:00** → corrección: actualiza los acumulados, sin pagar ni reabrir.
- **Día 2 de cada mes, 00:00** → cierre de La Liga del mes anterior (ver
  "Endpoints de La Liga y Tus Ligas"): tabla final y lo que gana cada uno, sin
  pagar. El día 1 entero es margen de gracia, igual que el lunes para la semana.
- **Día 9 de cada mes, 00:00** → pago del podio (`pago_liga`, 6 oct 2026): las monedas
  y el cupón de La Liga. Si el día 2 o el 9 es martes no hay corrida aparte: la
  hace el cierre semanal de esa hora, que también cierra y paga La Liga. Al
  arrancar, el programador también cierra y paga los meses que hayan quedado
  pendientes (si el servidor estuvo apagado el día 2, el pago cierra primero el
  mes). El programador no agenda nada antes del primer mes de La Liga (octubre
  de 2026).
- Siempre **hora de Guatemala**, sin importar en qué zona esté el servidor.
- Si una corrida falla (por ejemplo la base de datos caída un momento) reintenta
  cada 5 minutos, hasta 12 veces, y nunca se cae por un error. Si el servidor
  estuvo suspendido, dispara las corridas atrasadas en orden, sin saltarse ni
  repetir ninguna. Docker lo reinicia si el proceso se cae.
- Escribe una línea en el log por cada corrida y la hora de la siguiente. Para
  comprobar que está vivo: `docker compose logs programador` debe mostrar
  `Próxima corrida: ... (hora de Guatemala)`.
- Con una sola instancia basta; correr dos no paga dos veces (todo es
  idempotente).

**Comando manual** (`python manage.py cerrar_semana`):

| Opción | Qué hace |
|---|---|
| (ninguna) | Cierra solo la semana anterior a hoy (un lunes avisa que todavía está en su margen y no cierra) |
| `--ponerse-al-dia` | Cierra todas las semanas terminadas sin cerrar (tope de 4) |
| `--correccion` | Corrida del martes 12:00: solo actualiza acumulados |
| `--fecha AAAA-MM-DD` | Trata esa fecha como "hoy" (para simular o recuperar) |

`--ponerse-al-dia` no se combina con `--correccion`. `programador --una-vez` hace
solo la puesta al día de arranque y termina.

**Si el despliegue no usa Docker Compose**, no hace falta el servicio: se
programan dos tareas semanales en el servidor. Guatemala es UTC−6 todo el año
(sin horario de verano), así que la hora UTC es fija:

| Cuándo | Hora UTC | Comando |
|---|---|---|
| Martes, cierre | 06:05 | `python manage.py cerrar_semana --ponerse-al-dia` |
| Martes, corrección | 18:05 | `python manage.py cerrar_semana --correccion` |

Los cinco minutos de margen son a propósito. Si lo dispara un programador
externo (por ejemplo uno de AWS) y el reloj del servidor va unos segundos
atrasado, a las 06:00 en punto el comando todavía vería lunes en Guatemala y no
cerraría nada hasta el martes siguiente.

**Las monedas se pagan con la fecha del día en que corre el cierre** (el martes),
no con la fecha de la semana que se cerró. Desde el 2 oct ya no caducan a los 90 días sino
al cerrar la season (ver "Monedas y seasons"): una semana que se cierra con
retraso, si mientras tanto empezó otra season, paga en la season nueva.

---

## La Liga y Tus Ligas (fuera del payload de sync)

Detalle de reglas en `reglas-puntaje-vivo.md` sección 5 — acá solo lo que
toca el contrato.

**La Liga (demo 1, temporal):**

- **Un solo grupo** con todos los usuarios con póliza vinculada y verificada.
  Sin franja de edad ni sub-ligas (diseño futuro). Confirmado el 2 oct.
- Ciclo: día 1 al último día del mes calendario.
- **Compite por puntos** (decidido 2 oct 2026): la suma de los puntos del mes,
  los mismos que dan el cashback, **tal cual** (con el tope diario de 200 y el
  bono 60+). Antes competía por pasos.
- **Desempate** (3 oct 2026): a igualdad de puntos gana quien tenga **más pasos**
  en el mes (suma de `pasos_totales_dia`); si también empatan en pasos, gana
  quien tenga **más workouts** en el mes (suma de `workouts_cantidad`). La app
  lo explica con un botón de información.
- **Qué se muestra:** los **puntos** de cada participante sí; la **cantidad de
  pasos y de workouts** nunca, ni siquiera para explicar un desempate (decidido
  2 oct 2026; los workouts se suman el 3 oct).
- **Patrocinio:** algunos meses La Liga tiene una marca. Es la misma Liga, no
  una aparte: la marca se muestra arriba, junto al nombre de la liga,
  destacada, y los 3 primeros ganan además un cupón de esa marca. **Hecho
  (4 oct):** ver "Patrocinios".
- **Premio: monedas a los 3 primeros** del mes (decidido 3 oct 2026; reemplaza
  los premios por percentil). Nadie más gana monedas en La Liga. El servidor
  calcula la posición **una sola vez, al cierre del mes** (día 2), con el desempate
  de arriba, y **paga las monedas el día 9** (6 oct 2026; antes se pagaban al cerrar).
  Lo que gana cada uno se fija al cerrar: si se editan los montos del admin entre el
  2 y el 9, se paga lo ya fijado.
  - **Cuántas monedas a cada puesto (1.º, 2.º, 3.º): [PENDIENTE] (Diego).**
    Mientras tanto el código paga **30, 20 y 10** (provisional, 3 oct),
    editables en el admin (tabla `PremioPodioLiga`).
  - **Empate total** (mismos puntos, pasos y workouts en el mes):
    **[PENDIENTE]**. Opciones: compartir el puesto y la misma cantidad de
    monedas, o desempatar por quien llegó antes a esos puntos. **Provisional en
    el código (3 oct):** comparten el puesto y cada uno se lleva sus monedas; el
    siguiente puesto se salta (1, 1, 3).
  - Para ganar hay que tener **al menos 1 punto** en el mes: con 0 no se entra
    al podio aunque haya menos de 3 participantes con puntos.
  - El ranking devuelve `premios_monedas`: una lista con las monedas del 1.º, el
    2.º y el 3.º (vacía si el grupo no premia, como Tus Ligas). Flutter ya la lee
    (`GrupoRanking.premiosMonedas`).
  - Con patrocinio, el cupón de la marca es **además** de las monedas, para los
    mismos 3.

**Tus Ligas:** grupos que crea o a los que se une el usuario. Ranking mensual
**por puntos** entre miembros (decidido 2 oct 2026, igual que La Liga; antes era
por pasos), con el mismo desempate (pasos y luego workouts), **sin premios y sin exigir póliza** (cambia el 23
sep; antes exigían póliza).

**Duelos 1 contra 1:** eliminados del demo 1 — no construir endpoints ni
pantallas.

### Endpoints de La Liga y Tus Ligas (3 oct 2026)

Con token; `403` si la cuenta no tiene perfil. **La forma sigue la de
`social.json`** de la app (`GrupoRanking` y `RankingPersona`).

**`GET /api/v1/ligas`** → La Liga (solo con póliza verificada) y después Tus
Ligas del usuario, en el orden en que entró.

```json
{
  "puede_entrar_a_la_liga": true,
  "grupos": [
    {
      "id": "la-liga", "nombre": "La Liga", "tipo": "desconocidos",
      "mostrar_puntos": true, "ciclo": "mes",
      "miembros": [
        { "nombre": "Ana M.", "puntos_periodo": 200, "posicion": 1, "tendencia": "subida", "es_usuario": false },
        { "nombre": "Luis M.", "puntos_periodo": 150, "posicion": 2, "tendencia": "igual", "es_usuario": true }
      ],
      "liga": { "arranca": "2026-10-01", "cierra": "2026-10-31", "premios_monedas": [30, 20, 10], "patrocinio": null }
    },
    {
      "id": "12", "nombre": "Oficina", "tipo": "conocidos",
      "mostrar_puntos": true, "ciclo": "mes", "codigo": "K7QM2X", "creado_por_mi": true,
      "miembros": [ "..." ],
      "liga": { "arranca": "2026-10-01", "cierra": "2026-10-31", "premios_monedas": [], "patrocinio": null }
    }
  ]
}
```

- `miembros` viene **ya ordenado** por el servidor: puntos del mes hasta hoy y,
  a igualdad, pasos. **Nunca viajan los pasos.** `posicion` se repite en un
  empate total.
- `tendencia` compara la posición de hoy con la de ayer (`subida`, `bajada` o
  `igual`; el día 1, todos `igual`).
- **Nombre público:** con póliza verificada, el nombre y la inicial del apellido
  que manda la aseguradora ("Ana M."); sin ella, "Usuario 4F2A" (del id
  público). **Nunca el `username`**, que es la mitad del inicio de sesión.
  **[PENDIENTE]:** decidir si cada quien elige un alias.
- `puede_entrar_a_la_liga` es `false` sin póliza verificada: La Liga no viene
  en `grupos` y la app muestra el CTA de vincular póliza.
- Tus Ligas traen `premios_monedas` vacío (no premian) y `patrocinio` en `null`;
  La Liga trae el `patrocinio` del mes si está vendido y `null` si no (ver
  "Patrocinios").

**`POST /api/v1/ligas`** `{"nombre": "Oficina"}` → **201** con el grupo nuevo
(misma forma). Quien lo crea queda adentro. El código tiene 6 caracteres, sin
O/0 ni I/1. `400` `nombre_invalido` si el nombre está vacío o pasa de 60
caracteres.

**`POST /api/v1/ligas/unirse`** `{"codigo": "k7qm2x"}` → **200** con el grupo.
No distingue mayúsculas e ignora espacios. Repetirlo no duplica. `404`
`codigo_invalido` si ningún grupo tiene ese código. No exige póliza.

**`POST /api/v1/ligas/<id>/salir`** (sin cuerpo) → **204**. Sale de un grupo de
Tus Ligas; `<id>` es el `id` del grupo.

- **De La Liga no se sale:** con `la-liga` responde `400` `la_liga_no_se_sale`
  (la app no debe ofrecer el botón de salir en La Liga).
- `404` `no_eres_miembro` si el grupo no existe o el usuario no está adentro
  (también al salir dos veces).
- Los demás miembros siguen. Quien creó el grupo también puede salir: el grupo
  no pasa a nadie. Si sale el **último** miembro, el grupo se **borra** y su
  código deja de valer.
- Se puede volver a entrar con el código. Lo que se acumuló sale de los puntos
  del mes, no de la membresía, así que no se pierde ni se reinicia nada.

**Cierre de La Liga.** El **día 2 a las 00:00** (hora de Guatemala) el
servicio `programador` cierra el mes anterior. **Margen de gracia (3 oct
2026):** el día 1 entero queda para que lleguen los datos atrasados del último
día del mes (lo caminado el 31 y sincronizado el 1 todavía cuenta para el
podio), con el mismo `goals.DIAS_DE_GRACIA` que el cierre semanal del martes.
Guarda la tabla final de todos los participantes (`DesgloseLigaMensual`, con
puntos, pasos, workouts, posición y las monedas que le tocan) **sin pagar**. Una
sola vez por mes; un mes cerrado no se reabre. Participan los usuarios con póliza
verificada **al momento del cierre**. El primer cierre es el **2 nov 2026**
(octubre); los meses anteriores nunca se cierran.

**Pago del podio (6 oct 2026).** El **día 9 a las 00:00** el programador paga lo que
se fijó al cerrar: monedas `liga_mensual` fechadas ese día 9 y, si el mes tiene
patrocinio, el cupón (ver "Patrocinios"). Una sola vez por mes (`LigaMensual.pagada_en`);
pagar un mes que no está cerrado o antes del día 9 no hace nada. **Por qué el 9:** las
seasons arrancan un lunes entre el 28 de sep y el 4 de oct (y análogo en enero, abril y
julio); lo pagado el día 2 podía caer en la season que estaba por terminar y vencer a
los pocos días (en 2027, por ejemplo, octubre arranca el día 4). El día 9 siempre es de
la season nueva, así que lo ganado dura casi toda. Las monedas ganadas por el podio
cuentan en la season del día en que se pagan, también si el pago se atrasa.
**Dar a la app:** la app dice "tus monedas llegan el día 9" (texto fijo; el servidor no
manda la fecha). Entre el 2 y el 9 la tabla ya es la final.

A mano: `python manage.py cerrar_liga [--mes AAAA-MM]` cierra y, desde el día 9, paga.

---

## MethodChannel (Swift ↔ Flutter)

3 métodos, nada más: dos leen y envían HealthKit (`solicitarPermisos` y
`sincronizar`) y uno entrega la sesión (`actualizarSesion`). Todo lo demás va por
HTTP directo de Daniel contra la API de Luis — nada de dashboard, objetivos ni
historial pasa por acá.

*Hasta el 29 sep eran 2. El tercero se agregó para que Swift pueda enviar el
`sync` con el token sin depender de cómo una librería de Flutter guarda sus
datos.*

```dart
final bridge = HealthKitBridge();

// 1. Pide permiso de HealthKit (o revalida si el usuario lo cambió en Ajustes)
final permisos = await bridge.solicitarPermisos();
// permisos.estado → EstadoPermisos.concedido
// permisos.tipos  → TiposVisibles(pasos: true, ritmoCardiaco: false, entrenamientos: false)

// 2. Lee HealthKit, arma el JSON #1 y lo manda a /api/v1/sync
final sync = await bridge.sincronizar();
// sync.estado         → EstadoSync.ok
// sync.sincronizadoEn → "2026-09-05T20:15:00-06:00"
```

Usar siempre el wrapper (`lib/datos/healthkit_bridge.dart`), no
`canal.invokeMethod` crudo. Forma real que viaja por el canal:

```json
// solicitarPermisos
{ "estado": "concedido",
  "tipos": { "pasos": true, "ritmo_cardiaco": false, "entrenamientos": false } }

// sincronizar
{ "estado": "ok", "sincronizado_en": "2026-09-05T20:15:00-06:00" }
```

### `solicitarPermisos`

Salida: `{ "estado": string, "tipos": {string: bool}?, "detalle": string? }`

| `estado` | Qué significa | Qué hace Flutter |
|---|---|---|
| `concedido` | Se ven pasos: la app puede puntuar. **Mirar igual `tipos`** | Flujo normal, chequear los 3 tipos |
| `sin_datos_visibles` | No se ven pasos. Puede ser permiso negado **o** usuario sin actividad en 30 días — HealthKit no distingue | "No vemos datos de actividad. Si negaste el acceso, activalo en Ajustes › Salud › +Vida". Nunca un "listo" categórico |
| `no_disponible` | Dispositivo sin HealthKit (iPad, simulador) | Ocultar la función |

Si la solicitud falla en sí, llega como `FlutterError` código `PERMISOS_ERROR`.

**El mapa `tipos`** viaja solo en `concedido` y `sin_datos_visibles` (los dos
estados donde la sonda corrió), siempre con las tres claves. Leerlo así:

| tipo | qué significa `false` |
|---|---|
| `pasos` | Casi seguro **permiso negado** |
| `ritmo_cardiaco` | Probablemente **no tiene reloj**, no que haya negado |
| `entrenamientos` | Igual — solo cuentan los que tienen ritmo cardíaco (reloj); los ingresados a mano no cuentan |

Texto para el usuario: condicional, nunca acusatorio ("si usás un reloj,
revisá..."), porque mandar a arreglar un permiso a quien no tiene reloj es
ruido para la mayoría del piloto.

### `sincronizar`

Salida: `{ "estado": string, "sincronizado_en": string?, "detalle": string? }`

| `estado` | Qué significa | Qué hace Flutter |
|---|---|---|
| `ok` | Guardado en Luis. `sincronizado_en` viene con el timestamp | Confirmación normal |
| `encolado` | Sin red o backend caído — el día quedó en cola local, se reintenta solo al volver a primer plano | Aviso suave, **no** como falla — el dato no se perdió |
| `sin_acceso_a_salud` | No se pudo leer HealthKit — casi siempre permisos | Guiar a Ajustes › Salud › +Vida |
| `error_permanente` | URL mal configurada o backend rechazó el payload (4xx) — no se reintenta | Usuario no puede resolverlo; registrar y reportar |

`sincronizado_en` solo viene con `estado: ok` — leer como `String?`. `detalle`
es texto técnico para logs, nunca mostrárselo crudo al usuario.

**Respuesta ilegible (decidido 3 oct 2026):** si el servidor responde `2xx` pero
Swift no entiende el cuerpo, el día **ya quedó guardado**: Flutter ve `ok` y
Swift lo deja anotado en el log del dispositivo (solo la fecha y el código; ni
el cuerpo ni el token). Es lo que hacen Google y Stripe: un éxito no se
reintenta. Si aparece en el log, el servidor y la app ya no coinciden en el
formato.

**Flutter no necesita llamar a `sincronizar` para que los datos lleguen:** Swift
se pone al día solo (ver "Cuándo se manda cada día"). Sirve para un "jalar para
refrescar".

**Sin token, o token rechazado (`401`):** no es `error_permanente`. Swift no pierde
datos: el día queda pendiente y se envía cuando haya sesión. **Hoy Flutter ve
`encolado`** (con un `detalle` que lo explica). Si debe ser un estado propio
sigue abierto (ver "Puntos abiertos").

### `actualizarSesion`

Le entrega a Swift el token de la sesión actual, o le avisa que se cerró. Swift
lo guarda en su propio Keychain y lo manda como `Authorization` en cada envío.

Flutter lo llama:
1. **Al iniciar sesión o registrarse**, con el token y el `usuario_id` de la respuesta.
2. **Al cerrar sesión**, con `null`.
3. **Cada vez que abre la app**, con el token actual (o `null` si no hay
   sesión). Así la copia de Swift no se desincroniza, ni siquiera después de
   reinstalar: el Keychain sobrevive a desinstalar la app.

Entrada: `{ "token": string?, "usuario_id": string? }` — `token` en `null` significa
"no hay sesión". `usuario_id` llega desde A35; una versión de Flutter que no lo manda
sigue funcionando (ver abajo).

Salida: `{ "estado": string, "detalle": string? }`

| `estado` | Qué significa |
|---|---|
| `ok` | Guardado (o borrado, si vino `null`) |
| `error_almacenamiento` | No se pudo escribir o borrar en el Keychain, y **Swift se queda con el token que tenía antes**: en un primer ingreso no firma (los días quedan pendientes); al cambiar de cuenta o cerrar sesión **sigue mandando datos a la cuenta anterior** hasta el próximo arranque. Reintentar si importa cerrar esa ventana |

En Dart, el wrapper devuelve `EstadoSesionNativa` (`ok`, `errorAlmacenamiento`,
`noDisponible` sin lado nativo, `desconocido`) y **nunca lanza**, porque la
sesión lo llama sin esperar la respuesta. Un `FlutterError` de Swift
(`ARGUMENTOS_INVALIDOS`, error de programación) llega como `desconocido`.

- Es **idempotente**: mandar el mismo token dos veces no cambia nada.
- **Si entra otra persona**, Swift olvida hasta qué día se había mandado y **vacía
  la cola**: empieza como la primera vez (sus 7 días) y no recibe días que esperaban
  a nombre de la anterior. **Desde A35 "otra persona" se decide por el
  `usuario_id`, no por el token** (4 oct 2026), porque cada login trae un token
  nuevo: si la misma persona vuelve a entrar después de que su token venció, sigue
  donde iba y no pierde los días de la cola. Es lo que hace el SDK de Rook
  (`updateUserID` solo reinicia si cambia el usuario).
  - `token` en `null` (cerró sesión o venció): **solo se borra el token**. La marca y
    la cola esperan a ver quién entra. Swift recuerda el último `usuario_id`
    (`UserDefaults`, clave `vida.cuentaDeLosEnvios`; no es secreto).
  - Sin `usuario_id` se compara el token, como antes: el mismo token no cambia
    nada; otro token cuenta como otra persona.
- **Con un token, Swift se pone al día** sin esperar (ver "Cuándo se manda cada
  día").
- **No hay forma de leer el token desde Flutter** (no existe un método para
  eso). Flutter conserva su propia copia y, al cerrar sesión, borra **las dos**.
- Swift lo guarda en el Keychain con acceso "después del primer desbloqueo"
  (`AfterFirstUnlockThisDeviceOnly`): se puede leer con el teléfono bloqueado, así
  que un envío en segundo plano sí puede firmar, y **no viaja en copias de
  seguridad ni a otro teléfono**. Servicio `com.assures.masvida.sesion`, cuenta
  `token_api`. **Nunca se escribe en logs.**

### Cuándo se manda cada día (decidido 3 oct 2026)

Antes había un backfill de 7 días **una sola vez por instalación**, y nadie
mandaba los días nuevos: en la app real nadie llamaba a `sincronizar`, así que
después del primer día el servidor no recibía nada. Se decidió tras comparar con
Vitality, Betterfly, Sweatcoin, StepBet, Oura, Strava, Junction, Terra, Rook y
Thryve (las plataformas especializadas combinan "al abrir" con "segundo plano").

**Ponerse al día** — Swift lo hace solo, sin método propio, cuando:
1. la app vuelve a primer plano (`SceneDelegate`);
2. llega un token (`actualizarSesion`);
3. `solicitarPermisos` confirma el acceso.

Una vuelta a la vez. Qué manda:

| Paso | Qué |
|---|---|
| 1. La cola | Los días que fallaron antes (caducan a los 14 días) |
| 2. Desde la marca | Desde **el último día enviado** (otra vez: pudo sumar pasos después) **hasta hoy**, del más viejo al más nuevo, sin pasar de la ventana del servidor (15 días con hoy) |
| La primera vez | Sin marca (teléfono nuevo, reinstalación o cambio de cuenta): **los últimos 7 días, con puntos** (decidido 3 oct; Vitality y Sweatcoin solo premian desde la inscripción, se eligió mantener el comportamiento de siempre) |

- **La marca solo avanza** con lo que ya no hay que volver a mandar: lo que
  llegó y lo que el servidor rechazó por viejo (`422`). Un día vacío no la mueve:
  puede ser un permiso de Salud que todavía no se dio.
- **Fallo general → se corta la vuelta.** Sin red, servidor caído, token
  rechazado o Salud bloqueada fallan igual para todos los días: tras el primero
  no se intenta ninguno más, y si la cola se cortó así no se sigue con la marca.
  No se pierde nada (lo que no se intentó sigue en la cola o detrás de la
  marca). Así, con el servidor caído hay **un** intento por apertura, no uno por
  día.
- **Rechazo permanente** (otro `4xx`) → se saca ese día y se corta la vuelta.
- **Sin sesión** → no se manda nada y la marca no se mueve.
- **Antes de dar el permiso de Salud**, HealthKit no deja leer: los días quedan
  en la cola y salen solos cuando se concede.

**Segundo plano (decidido, sin construir — A32):** iOS despierta la app cuando
Salud tiene datos nuevos (`HKObserverQuery` con *background delivery*; para pasos,
como mucho una vez por hora). Límites de Apple: con el teléfono **bloqueado** no
se puede leer Salud; si el usuario **cierra la app a la fuerza**, iOS deja de
despertarla hasta que la vuelva a abrir; el modo de bajo consumo lo apaga. Por
eso "al abrir" sigue siendo el piso garantizado.

**Notificaciones push (decidido, sin construir):** para que abra la app quien no
sincroniza (por ejemplo, "abre +Vida para que tu registro cuente"). El servidor
sabe cuándo recibió datos de cada usuario por última vez; ese es el dato
confiable para avisar. Ver "Puntos abiertos".

### Wrapper

`lib/datos/healthkit_bridge.dart` expone los tres métodos tipados
(`EstadoPermisos`, `EstadoSync`, `TiposVisibles` y `EstadoSesionNativa`). El
`actualizarSesion` lo escribió Daniel en D11 junto con su conexión a la sesión, y
Alvaro le ajustó en A31 el caso del `FlutterError` y el texto de
`errorAlmacenamiento`. Es la **frontera del contrato**, no UI: un cambio ahí es
un cambio de contrato y se avisa a Alvaro, que mantiene el lado Swift.

Banco de pruebas sin UI: `lib/debug/pantalla_prueba_healthkit.dart` (no
ruteado, necesita iPhone físico — HealthKit no existe en el simulador).

---

## Días sin actividad

Tres caminos mandan datos a `/api/v1/sync` y hoy no se comportan igual frente
a un día vacío:

| Camino | Día vacío |
|---|---|
| Sync de hoy (`sincronizar`) | Lo manda igual |
| Cola de reintentos | Lo salta (y lo deja en la cola) |
| Ponerse al día | Lo salta (y la marca no avanza) |

Un payload vacío es indistinguible entre "sin actividad" y "permiso negado" —
mandarlo haría que Luis lo diera por entregado con cero datos para siempre.
La consecuencia: un día ausente en la base es ambiguo, y eso pega directo en
la evaluación del objetivo semanal (un día ausente puede ser un cero real o un
día que todavía no llegó).

**Sigue abierto (Alvaro + Luis):** emparejar los tres caminos — mandar siempre
el día aunque esté vacío (y que Luis distinga "vacío" de "ausente"), o no
mandarlo nunca (y tratar la ausencia como "sin datos"). Con el objetivo ahora
congelándose en vez de bajar (no degrada progreso), esto es menos grave que
antes, pero sigue sin resolverse.

---

## Ventana de aceptación de datos rezagados

**14 días.** Un payload cuya `fecha` tenga más de 14 días de antigüedad al
llegar al servidor se rechaza.

```
ventana ≥ día más viejo de la primera vez + holgura para reintentos
        = 6 días + 7 días de gracia
        = 13 → 14
```

| Cifra | Valor | Qué contesta |
|---|---|---|
| Ventana del servidor | 14 días | ¿Hasta qué tan viejo acepto un dato? |
| Cola de reintentos (cliente) | 14 días: un día con `fecha < hoy − 14` sale solo de la cola; tope de 15 días | ¿Cuánto sigo intentando mandar un día que falló? |
| Primera vez (cliente) | 7 días | ¿Cuánto historial le traigo a un teléfono nuevo? |

Ventana y cola comparten cifra a propósito (si la cola fuera más corta,
tiraría días que el servidor aceptaría; más larga, reintentaría en vano). La
primera vez es deliberadamente menor — necesita holgura de reintentos.

**Respuesta de rechazo**, distinguible de un payload inválido:

```
HTTP 422
{ "error": "fuera_de_ventana", "fecha": "2026-08-15" }
```

Un `4xx` genérico haría que el cliente descarte el día **y aborte el
procesamiento de los días siguientes** — con motivo identificable, descarta
ese día y sigue con el resto.

**Lo que hace Swift (hecho en A31):** distingue el `422` con
`"error": "fuera_de_ventana"` (cualquier otro `422`, o el mismo cuerpo con otro
código, sigue siendo un rechazo normal). Una sola regla para los tres caminos:

| Qué pasó | Ese día | La vuelta |
|---|---|---|
| Sin red, `401`, `408`, `429`, `5xx`, Salud bloqueada | Queda pendiente | **Se corta** (fallaría igual) |
| `422` de la ventana | Se descarta | Sigue |
| Respuesta `2xx` ilegible | Cuenta como enviado (y va al log) | Sigue |
| Otro `4xx` | Se descarta | Se corta |

**Frontera de ciclo — decidido:** un ciclo ya cerrado (La Liga u
objetivo semanal) es **inmutable**. Un dato del 29 de septiembre que llega el
10 de octubre entra igual a la base (cae dentro de los 14 días) y suma al
historial y al acumulado anual, pero **no reabre ni recalcula** La Liga de
septiembre ni ningún objetivo semanal ya evaluado — porque ya cerró. Son dos
reglas distintas:

| Pregunta | Regla |
|---|---|
| ¿Entra el dato a la base? | Ventana de 14 días |
| ¿Puede mover un ciclo ya cerrado? | Frontera de ciclo — nunca, un ciclo cerrado no se reabre |

La ventana tampoco frena la inyección de datos falsos: quien pueda escribir
muestras fabricadas en HealthKit las escribe con fecha de hoy igual de fácil.
Lo que la ventana sí hace es impedir que se reabran libros ya cerrados.

---

## Endpoint de resumen del dashboard (decidido)

No es un endpoint con agregación en caliente. Es una fila **`resumen_diario`**
(`usuario_id` + `fecha`) que se hace **upsert en cada sync** de ese día, con
datos que el sync ya calcula — no hay lógica nueva, solo persistir lo que ya
existe en memoria al procesar el payload.

```json
{
  "fecha": "2026-09-03",
  "pasos_totales_dia": 8420,
  "workouts_dia": {
    "cantidad": 1,
    "duracion_total_min": 35,
    "fc_promedio": 148,
    "fc_maxima": 162
  },
  "puntos_dia": 150,
  "ritmo_cardiaco": { "minutos_ligero": 310, "minutos_moderado": 42, "minutos_intenso": 18 }
}
```

| Campo | Notas |
|---|---|
| `pasos_totales_dia` | mismo valor que ya viaja en el JSON #2 del sync — se guarda, no se recalcula |
| `workouts_dia.cantidad` / `.duracion_total_min` | agregado de los workouts del día que cuentan (sin duplicar los que dos dispositivos registran a la vez) |
| `workouts_dia.fc_promedio` | promedio de `sesiones[].fc_promedio` del día — **no** un promedio de las 24h de `frecuencia_cardiaca[]` cruda (eso incluiría horas de reposo y no dice nada) |
| `workouts_dia.fc_maxima` | máximo de `sesiones[].fc_maxima` del día |
| `workouts_dia` | `null` si no hubo sesión ese día — no `0`, para no confundir "sin actividad intensa" con "FC de cero" |
| `ritmo_cardiaco` | minutos del día en cada zona (4 oct 2026); ver "Minutos por zona de ritmo cardíaco" abajo. `null` los días sin lecturas de ritmo cardíaco (casi siempre, sin reloj) — no ceros |
| `puntos_dia` | **lo acreditado** (desde el 5 oct 2026): la suma de las filas de actividad de ese día en el ledger, o sea con el techo diario, el techo anual, los ajustes por datos tardíos y el retroactivo denegado ya aplicados. **Ya no es el mismo valor que el del JSON #2 del sync** (ese es lo que calculó el día): pasado el techo anual un día puede calcular 200 y acreditar 0, y Progreso tiene que decir lo mismo que Mi Plan. Un día anulado por retroactivo denegado va en `0` (sus pasos siguen guardados y se ven) |

### Minutos por zona de ritmo cardíaco (hecho 4 oct 2026)

Para la gráfica de ritmo cardíaco de Progreso (ligero, moderado e intenso por
semana, mes y año). Los totales y la tendencia se suman en la app a partir de las
filas diarias, igual que los pasos.

- **Zonas** con la misma FCmáx de los puntos (219 − edad, la de la aseguradora
  si hay póliza verificada): **ligero** por debajo del 60 %, **moderado** del 60 %
  al 70 % (sin llegar) e **intenso** del 70 % hacia arriba. El reposo cuenta como
  ligero. Con 36 años: ligero hasta 109 bpm, moderado de 110 a 128, intenso desde 129.
- **Cuánto vale una lectura:** el tiempo hasta que empieza la siguiente, sin pasar
  de 15 minutos (un hueco más largo es tiempo sin dato, como al armar las
  sesiones inferidas). La última lectura vale lo que dura ella misma.
- **Un dispositivo a la vez:** si dos registran el mismo rato (reloj y pulsera),
  se usa el que cubre más minutos del día y no se suman.
- Sale de `frecuencia_cardiaca[]`, no de los workouts: cuenta todo el día.
- Se recalcula con cada sync del día. Los días anteriores al 4 oct 2026 quedan en
  `null` hasta que se vuelva a mandar ese día.
- **[PENDIENTE]:** la edad de una persona cambia con los años y los minutos ya
  guardados no se recalculan si la aseguradora corrige la fecha de nacimiento.

Mostrar máximo y promedio de FC por workout (no un promedio diario plano) es
también lo que justifica ante Apple el permiso de `.heartRate`: tiene que
sostener una función visible para el usuario, y un promedio de 24h mezclado
con reposo no lo hace tan bien como el máximo/promedio de la sesión.

**`GET /api/v1/dashboard/resumen?desde=&hasta=`** devuelve un array de filas
`resumen_diario` en ese rango — así arma Daniel el gráfico semanal y mensual,
sin pedir un endpoint por vista. `desde` y `hasta` son **obligatorios** (formato `AAAA-MM-DD`, `desde` ≤
`hasta`) y el rango no puede pasar de **366 días** (un año con bisiesto, lo
más que pide Progreso); fuera de eso responde `400`. Devuelve solo los días
que existen, sin rellenar huecos con ceros. Qué fechas calcula Daniel
para "semanal" y "mensual" (decidido: lunes–domingo alineado al objetivo
semanal, mes calendario alineado a La Liga) es una decisión de UI — vive en
el dominio de pantallas, no acá.

---

## Historial de puntos — `GET /api/v1/historial`

Los puntos acreditados día por día. Pide `Authorization: Token <clave>`; el
usuario sale del token.

| Parámetro | Tipo | Notas |
|---|---|---|
| `fecha_desde` | `YYYY-MM-DD`, opcional | incluida |
| `fecha_hasta` | `YYYY-MM-DD`, opcional | incluida |

```json
{
  "historial": [
    {
      "fecha": "2026-09-30",
      "puntos_pasos": 50,
      "puntos_intensidad": 100,
      "puntos_brutos": 150,
      "puntos_dia": 150,
      "tope_diario_aplicado": false,
      "version_regla": 1
    }
  ]
}
```

- Los días vienen del más nuevo al más viejo, y solo los que tienen movimientos.
- `puntos_dia` es **lo que de verdad se acreditó**: la suma de todas las filas
  del día en el ledger, incluidos los ajustes por datos tardíos. Nunca pasa de
  200 por el tope diario.
- Un día **anulado por retroactivo denegado** (ver "Póliza vinculada") aparece
  con `puntos_dia` en `0`, pero con `puntos_pasos` y `puntos_intensidad` del
  cálculo original, para que se vea que hubo actividad.
- `puntos_brutos` es `puntos_pasos + puntos_intensidad` antes del tope; no es
  lo acreditado.
- Errores: `400` si una fecha no tiene formato `YYYY-MM-DD` o si `fecha_desde`
  es mayor que `fecha_hasta`; `401` sin token; `403` si la cuenta no tiene perfil.

---

## Perfil — `GET /api/v1/perfil` (hecho 4 oct 2026)

Los datos de la propia cuenta para la pantalla de Perfil. Con token; `403` si la
cuenta no tiene perfil.

```json
{
  "usuario_id": "6f1c0e52-…",
  "correo": "ana@correo.com",
  "nombre": "Ana Martínez",
  "fecha_nacimiento": "1990-05-17",
  "edad": 36,
  "poliza_verificada": true,
  "dispositivos": [
    { "nombre": "Apple Watch de Ana", "modelo": "Watch", "fuente": "Apple Watch", "ultimo_dato": "2026-10-04" }
  ]
}
```

- `correo`: el `username` en las cuentas con contraseña (la app lo guarda así) y
  `User.email` en las de Google y Apple; `null` si no hay ninguno (un nombre
  generado como `google-4f2a…`).
- `nombre`: nombre y apellido que dio la aseguradora; `null` sin póliza
  verificada (pendiente y rechazada cuentan como sin póliza).
- `fecha_nacimiento` y `edad` son las **que usa el servidor** para los puntos: la
  confirmada por la aseguradora si hay póliza verificada y, si no, la del
  registro. La app no las calcula.
- `dispositivos`: los que mandaron datos (pasos, ritmo cardíaco o workouts) en
  los últimos 30 días, el más reciente primero. Es el mismo dispositivo si
  coinciden fuente, modelo y fabricante (la clave del puntaje); el nombre es el
  de su dato más nuevo y, si no trae, el de la fuente. No hay un máximo de
  dispositivos. Un reloj que se deja de usar sale solo.
- **Lo que no tiene el backend:** el "uso del seguro" del mock depende de lo que
  mande la aseguradora; no hay endpoint.

---

## Póliza vinculada

Una cuenta base (gratis) no tiene póliza. Vincularla es un paso aparte, después
de registrarse. Todo lo que implica dinero (cashback, canjear monedas, La
Liga) exige la póliza **verificada**; `pendiente` y `rechazada` cuentan igual
que no tener póliza. Ambos endpoints piden `Authorization: Token <clave>`; el
usuario sale del token.

### `POST /api/v1/polizas/vincular`

Vincula y verifica en el mismo paso, contra el registro de la aseguradora.

| Cuerpo | Tipo | Notas |
|---|---|---|
| `policy_number` | string | número como lo escribe el usuario; se guarda el oficial de la aseguradora |
| `insurer` | string | |
| `birth_date` | `YYYY-MM-DD` | la que escribe el usuario; se compara con la de la aseguradora |

Respuesta `200`: `{ "estado_verificacion": "verificada" | "rechazada", "motivo_rechazo": string | null }`.
Motivos: `no_existe`, `aseguradora_no_coincide`, `no_vigente` (la aseguradora
la **canceló o la suspendió**; las fechas no se miran),
`fecha_nacimiento_no_coincide` y `poliza_en_otra_cuenta`.

**Una sola cuenta verificada por póliza** (decidido y hecho el 4 oct 2026; sin
pólizas familiares hasta hablarlo con las aseguradoras). Si el número y la fecha
son correctos pero la póliza ya está verificada en otra cuenta, la segunda queda
`rechazada` con el motivo `poliza_en_otra_cuenta`: sugerencia de texto, "Esta
póliza ya está vinculada a otra cuenta. Si es tuya, escríbenos." No se aplica
retroactivo ni se toca su historial, y **ese rechazo no gasta intentos** del límite.
La regla está en la base de datos (no distingue mayúsculas ni espacios en el número
ni en la aseguradora), así que dos verificaciones a la vez no la burlan. Pendientes
y rechazadas sí pueden repetirse; solo cuentan las verificadas. **Hoy no hay forma de
liberar una póliza desde el admin** (no deja rechazar una verificada): lo hará el
panel (ver `panel-admin.md`).

`409` si el usuario ya tiene una póliza verificada; `400` por campos faltantes;
`403` si la cuenta no tiene perfil; `429` si se pasó el límite de intentos (ver
"Límite de intentos"). Una rechazada se puede volver a enviar.

*Hoy la aseguradora es un registro simulado cargado desde un CSV (comando
`cargar_registro_aseguradora`); cuando haya integración real se reemplaza sin
cambiar este endpoint.* Para el piloto también se puede verificar o rechazar a
mano desde el admin con las acciones "Verificar" (exige llenar antes la fecha
de nacimiento confirmada y aplica la misma regla de retroactividad) y
"Rechazar". El estado
nunca se edita a mano.

### `GET /api/v1/polizas/estado`

```json
{ "estado": "sin_poliza" | "pendiente" | "verificada" | "rechazada",
  "verificada": true,
  "motivo_rechazo": null,
  "poliza": { "policy_number": "POL-100001", "insurer": "Seguros Demo GT",
              "policy_start_date": "2026-01-15",
              "nombre": "Ana", "apellido": "Morales", "plan": "Plan Plus",
              "prima_anual_gtq": "15000.00",
              "fecha_renovacion": "2027-01-14" } }
```

`poliza` es `null` si no hay póliza. `policy_start_date`, `nombre`, `apellido`,
`plan`, `prima_anual_gtq` y `fecha_renovacion` son `null` hasta que la
aseguradora confirma la póliza (y vuelven a `null` si se rechaza).
`prima_anual_gtq` viaja como **texto con dos decimales** (es dinero: no debe
pasar por un número de punto flotante). `fecha_renovacion` es la **próxima**
renovación anual, no un vencimiento: se guarda la que dio la aseguradora y, si
ya pasó **o es hoy**, se responde la del año siguiente (y así hasta después de
hoy; el 29 de febrero cae en el 28 los años que no son bisiestos). El día de la
renovación ya es el primero del año de póliza nuevo, igual que en
`GET /api/v1/cashback` (4 oct 2026). `verificada` es el único valor que debe usarse
para habilitar canje, cashback y La Liga.

### Datos que entrega la aseguradora (decidido 2 oct 2026)

**Nombre, apellido, prima anual, número de póliza, fecha de nacimiento, plan y
fecha de renovación.** El registro simulado tiene todos (más deducible,
coaseguro y red).

- **La póliza es anual:** se renueva cada año, y la **prima es anual**.
- La fecha de la aseguradora es la de **renovación**, no un vencimiento: una
  póliza médica no vence. **Solo deja de dar beneficios si la aseguradora la
  cancela o la suspende.**
- **Hecho en el código (3 oct):**
  - La verificación ya no mira fechas: solo rechaza con `no_vigente` una
    póliza **cancelada o suspendida**. Pasada la fecha de renovación, sigue
    valiendo.
  - El registro simulado guarda la **prima anual** (`prima_anual_gtq`; la
    migración multiplicó por 12 la mensual que hubiera) y ya no tiene el estado
    `vencida` (las filas que lo tenían pasaron a `vigente`; el comando de carga
    lo rechaza explicando por qué). `POL-100004`, con la renovación ya pasada,
    queda como ejemplo de póliza que se verifica igual.
  - La póliza vinculada guarda nombre, apellido, plan, prima anual y fecha de
    renovación al verificarse, y los devuelve en `GET /api/v1/polizas/estado`.
    En el registro, la fecha de renovación sigue en la columna `vigencia_fin`
    (se dejó el nombre para no romper la carga del CSV).
- **[PENDIENTE]:** cómo se entera el sistema de que una póliza ya verificada fue
  cancelada (depende de la integración real con la aseguradora). Si se verifica
  a mano desde el admin, estos cinco datos no se llenan solos.

### Cashback en quetzales (decidido 2 oct 2026, hecho 4 oct 2026)

**Monto = % del nivel × prima anual**, redondeado a centavos. Se devuelve como
dinero **después** del pago de la prima, nunca como descuento (regla
regulatoria, ver `CLAUDE.md`). Se muestra en Mi Plan, debajo de las gráficas.

**El año del cashback es el año de póliza:** los puntos anuales, el techo de
12.000, el nivel y el cashback se cuentan desde un aniversario de la
renovación hasta el día antes del siguiente, no del 1 de enero al 31 de
diciembre. El ancla es `fecha_renovacion` (la que dio la aseguradora; si ya
pasó se proyecta un año tras otro) o, si falta, `policy_start_date`. El día de
la renovación ya es del año nuevo. Por ahora una póliza tiene una sola cuenta
verificada (sin pólizas familiares); si más adelante hay varias, compartirían esas
fechas.

**Cada año de póliza arranca en cero** (decidido 4 oct 2026): los puntos de
antes de su inicio no cuentan para él ni gastan su techo de 12.000, y al
renovar el total vuelve a 0. Esto vale también con retroactividad: lo ganado
antes del inicio del año en curso pertenece a un año anterior (la regla de
retroactividad de abajo solo decide si lo de la cuenta base existe o no). No
se borra ni se edita nada del ledger: solo cambia qué filas entran en la
ventana. Como los días ya asentados se recortaron con la ventana de su
momento (año calendario antes de verificar), al pasar al año de póliza la
actividad del año **se limita a 12.000 al sumarla**; el chequeo médico va
aparte, como en el techo.

**Sin póliza verificada** (pendiente y rechazada incluidas) la cuenta base
cuenta sus puntos por año calendario, solo como referencia: se ve el avance y
el nivel, pero no hay prima ni monto. Al verificar, pasa al año de póliza.

**Cuándo se paga:** el backend solo calcula y muestra. El pago lo hace la
aseguradora, fuera de la app, después de cobrar la prima. Mientras el año
corre, el monto es una **proyección** con el nivel de hoy; al cerrar el año
(la renovación), el del año que terminó queda **por pagar** en el bloque
`anterior`. El backend no mueve dinero ni registra si ya se pagó.

#### `GET /api/v1/cashback`

Con token. Cuenta sin perfil: `403`.

```json
{
  "con_poliza": true,
  "anio": {"inicio": "2026-03-01", "fin": "2027-02-28", "renovacion": "2027-03-01"},
  "puntos_ano": 5200,
  "nivel": 2,
  "porcentaje": 7.5,
  "siguiente_nivel": {"nivel": 3, "desde": 10000, "faltan": 4800, "porcentaje": 10.0, "cashback_gtq": "600.00"},
  "prima_anual_gtq": "6000.00",
  "cashback_gtq": "450.00",
  "estado": "proyeccion",
  "anterior": {
    "inicio": "2025-03-01", "fin": "2026-02-28", "puntos_ano": 2600,
    "nivel": 1, "porcentaje": 5.0, "cashback_gtq": "300.00", "estado": "por_pagar"
  }
}
```

- `estado`: `proyeccion` (póliza verificada) o `sin_poliza`. Sin póliza,
  `anio.renovacion`, `prima_anual_gtq`, `cashback_gtq` y
  `siguiente_nivel.cashback_gtq` son `null`, y `anterior` también.
- El dinero va como **texto con dos decimales**; el porcentaje, como número.
- `siguiente_nivel` es `null` en el último nivel (con el techo de 12.000, el
  nivel 4 no se alcanza en el piloto).
- `anterior` es `null` si la póliza todavía no tenía un año cerrado o si ese
  año no llegó al nivel 1 (no hay nada por pagar). **[PENDIENTE]:** usa la
  prima actual; si la prima cambia en una renovación, el monto del año
  anterior se calcula con la nueva.

### Retroactividad

Al verificarse, la fecha de nacimiento de la **cuenta** (la del registro) se
compara con la **confirmada por la aseguradora**:

- **Coinciden:** todo lo ganado en la cuenta base (puntos y monedas) cuenta
  (veredicto `aplicado`).
- **Difieren poco y sin ventaja:** se toma como un error y **no se le quita nada**
  (`tolerado`).
- **Mentira:** no hay retroactividad (`denegado`). Los días anteriores a la
  verificación se anulan con una fila negativa por día en el ledger
  (`retroactivo_denegado`), y las monedas ganadas antes también. Nada se edita
  ni se borra. Los pasos y workouts de esos días tampoco cuentan para la meta
  semanal ni para el desempate de La Liga y Tus Ligas (siguen guardados y se ven en
  Progreso).

La edad que se usa para el puntaje es, desde la verificación, la confirmada por la
aseguradora. Como la verificación ocurre al vincular, "desde la vinculación" y
"desde la verificación" son el mismo momento.

**Qué es error y qué es mentira** (decidido el 4 oct 2026, hecho el 5 oct; es la regla
**del demo**, se revisa con casos reales):

- Una fecha distinta se **tolera** si difiere en **hasta 2 años** de la de la
  aseguradora (mes y día incluidos) **y no le da ventaja**.
- Es **mentira** si difiere en **más de 2 años**, o si **le da ventaja** aunque
  difiera poco.
- **Ventaja** es cruzar los 60 años (bono +25), una meta semanal de pasos más baja o una
  FCmáx más baja (que hace más fácil la intensidad). Como la meta y la FCmáx bajan con
  la edad, en la práctica es ser **más vieja en años cumplidos**, aunque sea uno. Se
  mide con las edades del día de la verificación: alguien que se puso unos meses más
  vieja es tolerada o no según cuándo verifique (nacida el 2 ene en vez del 17 may:
  verificando en octubre las dos ya cumplieron 36; verificando en marzo una tiene 36 y
  la otra 35, y cuenta como ventaja). Quien se puso más joven nunca le conviene y se
  tolera hasta 2 años.
- `POST /api/v1/polizas/vincular` no dice el veredicto (queda en la póliza). **[PENDIENTE]**
  decidir si la respuesta lo lleva para que la app lo explique con tono cálido.

**El veredicto se toma una vez y no se recalcula** (5 oct 2026). Se guarda en la póliza
(`retroactivo` y, si fue denegado, `corte_retroactivo`, el día de la verificación).
Las filas anteriores a este campo se fijaron con lo que ya se les había aplicado
(cualquier diferencia de fecha anulaba lo anterior).

**Si la aseguradora corrige su fecha después de verificar** (error suyo, 5 oct 2026):

- **No se le quita nada a la persona.** El veredicto no cambia y la corrección **vale
  hacia adelante**: para un día anterior se sigue usando la fecha de entonces (los
  puntos, el bono 60+, la FCmáx, las zonas de ritmo cardíaco y la meta semanal), así
  que un dato tardío de ayer conserva lo que tenía aunque la fecha corregida ya no se
  lo daría. Con varias correcciones, cada tramo usa su fecha.
- Hoy se hace **cambiando la fecha confirmada de la póliza en el admin de Django**: queda
  registrada como `CorreccionDeNacimiento` (fecha anterior, nueva y desde cuándo vale; se
  ve en la ficha de la póliza) y el admin avisa. Solo se agregan filas.
- **Sumar hacia atrás**, si la fecha corregida le daba más puntos, **no es automático**:
  lo decide un administrador caso por caso (el panel; ver `panel-admin.md`).

---

## Notas para Luis (backend)

- **Identidad desde el token (30 sep):** el usuario sale de `request.user`.
  Cualquier `usuario_id` que venga en el cuerpo se ignora (no se rechaza, para no
  romper versiones viejas de la app). **Prueba obligatoria de suplantación:** con
  el token de A y el `usuario_id` de B en el cuerpo, los datos quedan a nombre de
  A.
- **Códigos de error coherentes:** fecha inválida en `sync` da `400`. Una cuenta
  sin perfil de usuario da `403` en todos los endpoints (`sync`, `historial`,
  dashboard, retos y póliza). Resuelto el 1 oct.
- **Nunca registrar el token ni el encabezado `Authorization`** en logs.
- **Idempotencia (L4):** constraint único en `(usuario_id, external_id)` (la
  columna interna, no un campo del JSON) para
  pasos, sesiones y frecuencia cardíaca. Reenviar una muestra ya guardada
  nunca debe duplicar una fila.
- **Nunca sumar `pasos[].cantidad` de fuentes distintas sin dedup** — ni para
  puntos ni para `pasos_totales_dia`. Jerarquía de fuentes antes de sumar,
  siempre: sistema (`com.apple.health.*`) vs. terceros (Garmin, Whoop, Zepp,
  Fitbit, etc.) al mismo nivel de confianza. **Elección de fuente (1 oct): pasos
  por bloque (hora o varias horas), workouts sin duplicar los que se cruzan, intensidad por el
  dispositivo que más puntos da — ver "Elección de fuente". Nunca se suman.**
  La decisión se re-evalúa en cada sync de esa fecha, no solo la primera vez
  (los relojes de terceros pueden sincronizar a Health con retraso).
- **Datos del dispositivo (confirmado 20 sep 2026):** tres columnas nullable
  nuevas en `Muestra`, `MuestraBPM` y `Sesion` (`dispositivo_nombre`,
  `dispositivo_modelo`, `dispositivo_fabricante`), más una función de
  derivación de `tipo_dispositivo` (`telefono`/`reloj`/`anillo`/`desconocido`)
  que corre en el servidor con el orden descrito en la sección "Tipo de
  dispositivo" de arriba. Desde el 1 oct el puntaje compara dispositivos por
  `fuente_bundle` + `dispositivo_modelo` + `dispositivo_fabricante`, no por
  `tipo_dispositivo`; la derivación se conserva para reportes. Nunca se excluye
  una muestra por su tipo. Detalle y por qué en `decision-tipo-dispositivo.md`.
- **`sesiones[].tipo_actividad` puede llegar `null` (confirmado 21 sep 2026)
  — nunca rechazar la sesión por eso.** Un reloj de terceros (ej. WHOOP)
  puede detectar el workout automáticamente pero clasificarlo genérico/sin
  tipo cuando su confianza es baja, y eso queda así indefinidamente si el
  usuario no lo corrige a mano en su app. El backend guarda `tipo_actividad`
  tal cual llega (incluido `null`) — no inventa un valor, no descarta la
  sesión, no la excluye de intensidad/puntos por eso. Al servir el dato hacia
  el dashboard (`resumen_diario`, historial), si `tipo_actividad` es `null`
  se representa como `"no_registrado"` para que Daniel lo muestre como
  "No registrado" / "Workout sin nombre" — la sesión existe y cuenta, solo no
  tiene nombre. **Hoy ni el dashboard ni el historial devuelven
  `tipo_actividad`** (el dashboard agrega los workouts del día); la regla
  aplica cuando exista una lista de workouts.
- **`pasos_totales_dia`** usa la misma regla por bloques que el motor de puntos —
  no es un cálculo nuevo y separado.
- **Sesión intensa sin workout (L7):** se detecta en el backend sobre
  `frecuencia_cardiaca[]` cruda. Umbral: ≥30 min continuos al 60-70% de FCM,
  FCM = 219 − edad. La edad vive en el servidor, nunca la manda el teléfono.
- **Techos:** diario 200 pts (pasos + intensidad), anual 12.000 pts.
- **Nivel anual (0–4):** implementado con los pisos de `CLAUDE.md`: 2.500 /
  5.000 / 10.000 / 15.000 puntos → 5% / 7,5% / 10% / 20%.
- **Ventana de sync:** mismo endpoint para el día de hoy y para ponerse al día —
  cada día es una llamada independiente con su propio `fecha`.
- **Ventana de aceptación (L14):** 14 días, no 3. Rechazo por antigüedad
  devuelve `422` con `{"error": "fuera_de_ventana"}`, no un `400` genérico.
- **Frontera de ciclo:** un ciclo ya cerrado (La Liga, objetivo semanal)
  es inmutable — un dato tardío dentro de la ventana de 14 días se guarda
  para historial/acumulado anual, pero nunca recalcula un ciclo ya cerrado.
- **Ráfagas de usuario nuevo:** la primera vez de cada teléfono son 7 POSTs
  seguidos en segundos. Con 50 personas del piloto entrando el mismo día, ~350
  requests en ráfaga. Después, cada apertura de la app manda desde el último día
  enviado hasta hoy (normalmente 1 o 2 POSTs); con el servidor caído, un solo
  intento por apertura.
- **Un día ausente es ambiguo** — ver "Días sin actividad" arriba. Afecta la
  evaluación del objetivo semanal.
- **Cuándo se fija el objetivo semanal:** el objetivo de la semana nueva rige
  desde las **00:00 del lunes**. El **resultado** de la semana que terminó
  (`cumplido` y monedas) se fija el **martes 00:00**, después del margen de
  gracia del lunes (decidido 3 oct, hecho en A34 por Alvaro); el martes 12:00
  una corrección actualiza acumulados sin cambiar el resultado. Las dos corridas
  las programa el servicio `programador` (ver "Cierre semanal programado").
- **Objetivos semanales (L11) — implementado para el demo 1 (1 oct; ver "Cómo
  está construido hoy"). Lo que sigue vigente del ticket:** un
  objetivo sin progresión (meta de pasos totales de la semana + meta de
  workouts), editable a mano, lunes–domingo. Completada = ambas métricas
  alcanzadas; desde el 2 oct cada componente paga por separado y la meta de
  pasos depende del rango de edad (ver "Demo 1"). Sin subir ni congelar objetivo en el demo; el
  mecanismo completo (progresión que se congela en vez de bajar, tabla de
  dificultad, historial de seasons con objetivo máximo) **queda como diseño
  para después, pero las seasons se mantienen** en el modelo y en la
  respuesta del endpoint (desde el 2 oct, seasons de 13 semanas ISO). Se
  mantienen las dos corridas programadas (00:00 fija el objetivo, 12:00 solo
  corrige historial/acumulado). Un **workout** = un entrenamiento que
  cuenta (con ritmo cardíaco, no manual y sin duplicar los que dos
  dispositivos registran a la vez — ver "Qué cuenta como workout"), **de
  cualquier duración** (decidido 1 oct 2026).
- **La Liga (demo 1):** un solo grupo con todos los usuarios con póliza
  vinculada y verificada. Desde el 2 oct compite **por puntos** del mes (tal
  cual, con tope y bono 60+), con desempate por pasos y luego workouts del mes. Al cierre del
  mes calcular una vez la posición de cada participante, guardarla y **pagar las
  monedas a los 3 primeros** (decidido 3 oct; ya no hay percentiles ni tramos).
  Las monedas de cada puesto, en configuración — por definir con Diego. Sin
  franja de edad ni sub-ligas (diseño futuro).
- **Tus Ligas:** grupos que crea/une el usuario; ranking mensual **por puntos**
  (desde el 2 oct), con el mismo desempate; **sin premios y sin exigir póliza**.
  **Duelos 1 contra 1: no construir.**
- **Endpoint de resumen para el dashboard (decidido):** tabla `resumen_diario`
  (`usuario_id` + `fecha`), upsert en cada sync con lo que el sync ya calcula
  — `pasos_totales_dia`, agregado de los workouts del día que cuentan
  (cantidad, duración total, fc_promedio, fc_maxima), `puntos_dia`. Sin lógica nueva de
  agregación. `GET /api/v1/dashboard/resumen?desde=&hasta=` devuelve el rango.
  Ver sección "Endpoint de resumen del dashboard" arriba para el shape
  completo.
- **Ledger append-only:** cada acreditación es una fila nueva con la versión
  de la regla que la generó — nunca `UPDATE` sobre una fila existente.
  **Se hace cumplir en el código (3 oct):** en `Ledger` (puntos) y
  `MonedaLedger` (monedas), editar una fila, `update()` y borrar (una fila o en
  bloque) lanzan `FilaInmutable`. En el admin se pueden ver y **agregar** filas
  (acreditaciones manuales del demo), nunca editarlas ni borrarlas. Tipos:
  `pasos` e `intensidad` (el primer cálculo del día), `ajuste_manual` (cada
  corrección por datos tardíos, positiva o negativa; el nombre se presta a
  confusión porque también lo usa el sistema), `retroactivo_denegado` y
  `chequeo_medico` (fuera de v1).
- **Muestras borradas en HealthKit:** si la persona borra una muestra en Apple
  Salud, el servidor la conserva (solo inserta, nunca borra). El día se
  recalcula con lo guardado, así que esa muestra sigue contando.
- **Reunión del 2 oct — trabajo de backend [PENDIENTE]:**
  - Inicio de sesión con Google y Apple (ver "Inicio de sesión con Google y
    Apple").
  - Objetivo semanal: pago por componente (5 + 5 provisional), meta de pasos
    por rango de edad y lista de semanas de la season para la vista "battle
    pass".
  - ~~Seasons por semanas ISO~~ — **hecho** (2 oct): ver "Seasons".
  - ~~Monedas: sin tope, reinicio al cerrar la season y el orden del lunes en que
    cambia~~ — **hecho** (2 oct): ver "Monedas y seasons".
  - La Liga y Tus Ligas por puntos, con desempate por pasos y luego workouts; en La Liga se
    devuelven los puntos de cada participante pero nunca sus pasos ni sus workouts.
  - ~~Póliza: no rechazar por la fecha de renovación, y guardar y devolver
    nombre, apellido, plan, prima y fecha de renovación~~ — **hecho** (3 oct):
    ver "Datos que entrega la aseguradora".
  - Endpoints nuevos: ~~cupones (activos, usados y vencidos)~~ — **hecho**
    (3 oct): ver "Premios, canje y cupones"; ~~cashback en quetzales~~ —
    **hecho** (4 oct, `GET /api/v1/cashback`); ~~patrocinios~~ — **hecho**
    (4 oct): ver "Patrocinios".
  - ~~Puntos anuales, techo de 12.000, nivel y cashback por **año de póliza**,
    y prima anual en el registro de la aseguradora~~ — **hecho** (4 oct): ver
    "Cashback en quetzales".
- **Sincronización (3 oct) [PENDIENTE]:** para las notificaciones push, guardar
  los dispositivos y mandar el recordatorio (ver "Puntos abiertos"). Lo puede
  hacer Luis o Alvaro. El margen de gracia del cierre ya está hecho (A34).

## Notas para Daniel (Flutter)

- Todo lo que no sea leer HealthKit va por HTTP directo contra la API de
  Luis — el MethodChannel es solo `solicitarPermisos`, `sincronizar` y
  `actualizarSesion`.
- **Sesión (30 sep):** hacen falta las pantallas de registro e inicio de sesión
  (`POST /api/v1/registro`, `POST /api/v1/login`). Guardá el token en
  almacenamiento seguro (Keychain) para tus propias llamadas HTTP, con el
  encabezado `Authorization: Token <clave>`.
- **`actualizarSesion`:** llamalo al iniciar sesión (con el token), al cerrar sesión
  (con `null`) y **cada vez que se abre la app** (con el token actual, o `null`).
  Al cerrar sesión borrá tu copia **y** avisale a Swift.
- **Orden de pantallas:** primero la sesión y después `solicitarPermisos` (ya
  está así en D11). Si se invirtiera tampoco se pierde nada: los días esperan en
  la cola hasta que haya sesión y permiso.
- **Sesión real [PENDIENTE]:** la app usa `ServicioSesionLocal`, que inventa
  tokens (`local-…`). Swift los guarda y el servidor rechaza cada envío con
  `401`: los días esperan, pero **no llega nada al servidor** hasta pasar a
  `ServicioSesionApi`.
- **Si una llamada HTTP responde `401`:** limpiá la sesión, llamá
  `actualizarSesion(null)` y llevá a la persona a iniciar sesión.
- `usuario_id` viene en la respuesta del registro y es solo un nombre público;
  no lo mandes en ninguna petición.
- Los booleanos `concedido` y `ok` no existen — todo se lee desde `estado`.
- `solicitarPermisos` trae un mapa `tipos` (`pasos`, `ritmo_cardiaco`,
  `entrenamientos`). `estado: concedido` solo garantiza que se ven pasos —
  leer los tres antes de decirle al usuario que quedó todo listo.
- `ritmo_cardiaco: false` casi nunca es "negó el permiso" — probablemente no
  tiene reloj, y eso va a ser la mayoría en el piloto. Mensaje condicional,
  nunca imperativo.
- `sincronizado_en` solo viene con `estado: ok` — leer como `String?`.
- Usar `lib/datos/healthkit_bridge.dart` — no parsear strings/mapas a mano. Si
  falta algo ahí, es un cambio de contrato, no un parche local.
- `pasos_totales_dia` **no** viene por el canal — se pide por HTTP a
  `GET /api/v1/dashboard/resumen?desde=&hasta=`, que devuelve un array de
  filas `resumen_diario` (pasos, workouts con fc_promedio/fc_maxima, puntos)
  — una por día del rango. Con eso armás semanal y mensual sin pedir nada
  aparte. Ver "Endpoint de resumen del dashboard" en el contrato para el
  shape exacto. FC del día: usar el promedio/máximo **por workout**, no un
  promedio de 24h — no lo vas a recibir así.
- **`tipo_actividad` de un workout puede venir vacío/`"no_registrado"`
  (confirmado 21 sep 2026) — no es un error ni un caso a ocultar.** Pasa con
  relojes de terceros que detectan el ejercicio automáticamente pero no
  logran clasificarlo (ej. WHOOP). Mostrarlo como **"No registrado"** o
  **"Workout sin nombre"** en vez de dejar el campo en blanco o romper la
  tarjeta del workout — la sesión sí cuenta para intensidad/puntos, solo no
  tiene nombre de actividad. (Hoy ningún endpoint devuelve `tipo_actividad`;
  aplica cuando haya una lista de workouts.)
- `encolado` **no** es una falla — el dato quedó a salvo y se reintenta solo.
- **No implementar reintentos propios ni llamar a `sincronizar` al abrir** —
  Swift se pone al día solo cada vez que la app vuelve a primer plano (ver
  "Cuándo se manda cada día").
- **Segundo plano (A32, cuando se construya):** iOS va a despertar la app sin
  pantalla, y eso también corre el `main()` de Flutter (carga de datos, sesión,
  relevo de semana). Habrá que revisar que sea seguro y liviano.
- El **objetivo semanal** no viene en la respuesta del sync — pedirlo aparte
  con `GET /api/v1/objetivos/estado` (antes `retos/estado`, que ya no existe), y
  las semanas de la season con `GET /api/v1/objetivos/semanas`. No confundirlo con `nivel` (el anual, de
  cashback) que sí viene en la respuesta del sync.
- **Objetivos semanales (D12) — demo 1:** meta de pasos + meta de workouts de
  la semana, con el progreso del usuario en cada una. **Desde el 2 oct:** cada
  componente muestra **sus propias monedas** (cumplir uno paga aunque no se
  cumpla el otro), la semana se marca completada solo con los dos, y la meta de
  pasos depende de la edad (la manda el servidor; la app no la calcula). **Sin rango, sin subir/bajar, sin congelamiento, sin
  animación de cambio de objetivo.** Mostrar en qué season está el usuario y
  cuánto falta para que cierre (las seasons se mantienen). La progresión
  completa vuelve después del demo — no construir hoy.
- **La Liga:** un solo grupo, todos los usuarios con póliza verificada,
  **monedas a los 3 primeros** del mes (el servidor calcula la posición y manda
  `premios_monedas`; los textos de los términos ya dicen "los 3 primeros"). **Desde el 2
  oct compite por puntos**, con desempate por pasos y luego workouts, y un botón de información
  que lo explique; si el mes está patrocinado, la marca va arriba junto al
  nombre de la liga. **Tus Ligas también compite por puntos.** En La Liga se
  muestran los puntos de cada participante, **nunca la cantidad de pasos ni de workouts**. Sin franjas
  de edad ni sub-ligas. **Tus Ligas:** cualquiera se une (con o sin póliza),
  sin premios. **Duelos 1 contra 1: eliminar.**
- **El objetivo de la semana se fija a las 00:00 del lunes y ya no cambia
  después** — la semana nueva arranca normal, sin pantalla de "evaluando".
  **Desde el 3 oct:** el **resultado** de la semana anterior (si se completó y
  sus monedas) llega el **martes 00:00**. El lunes, `objetivos/semanas` la
  devuelve con `estado: "en_revision"` (cifras provisionales): mostrarla "en
  revisión", nunca "no cumplida". Es un estado nuevo que la app tiene que
  manejar.
- `dispositivo_*` (nuevo) no cambia nada del lado de Flutter — son campos que
  Swift agrega al payload de sync; Daniel no los toca ni los muestra.
- Nada de SDKs de terceros (ej. Firebase) puede tocar datos de HealthKit, ni
  indirectamente — Apple lo trata como filtración y remueve la app.
- **Reunión del 2 oct — pantallas** (el detalle vive en `CLAUDE.md`):
  - **Login:** botones "Continuar con Google" e "Iniciar sesión con Apple", y un
    paso para pedir la fecha de nacimiento la primera vez.
  - **Hoy:** sin racha; las cajas de etapas (7.000 / 10.000 / 15.000) pasan a un
    botón de información que se expande; el desglose de puntos queda siempre
    visible.
  - **Objetivo semanal:** vista tipo "battle pass" con las semanas de la season
    en scroll horizontal.
  - **Monedas:** sin tope; se quita el aviso de 80 y se avisa 7 días antes de
    que termine la season (`season.aviso_fin_de_season` de `objetivos/estado`).
  - **Mi Plan:** la gráfica de nivel y la de barras se unen, con el cashback en
    quetzales debajo.
  - **Premios:** lista desplegable con los cupones usados y vencidos.

---

## Notas para Alvaro (iOS)

- **Token (30 sep):** `ApiClient` manda `Authorization: Token <clave>` en
  `POST /api/v1/sync`. El token lo entrega Flutter con `actualizarSesion`; Swift lo
  guarda en su propio Keychain (acceso "después del primer desbloqueo", solo en
  este dispositivo) y **nunca lo escribe en logs**.
- **Sin token:** no enviar. El día queda pendiente. Aplica a los tres caminos de
  envío: el sync de hoy, la cola de reintentos y ponerse al día.
- **`401`:** no es error permanente: el día queda pendiente (A24). **Desde el 3
  oct corta la vuelta**, igual que sin red o con el servidor caído: fallaría
  igual para los demás días. No se pierde nada.
- **`usuario_id` fuera del payload** y sin la constante `"alvaro-001"`. Hecho (A24).
- **`actualizarSesion(null)`:** borra el token del Keychain. Hecho (A24).
- **Hecho en A31 (3 oct):** cola de 14 días; `422` de la ventana (descarta y
  sigue); una sola regla para los días que fallan (`AccionDiaFallido`,
  `RecorridoDias`); ponerse al día al abrir la app, al iniciar sesión y al dar
  el permiso (`MarcaEnvios`, reemplaza al backfill); al cambiar de cuenta se
  olvidan la marca y la cola; respuesta ilegible como enviada, con log. El
  wrapper de Dart lo hizo Daniel (D11), con dos ajustes de Alvaro.
- **[PENDIENTE] Segundo plano (A32):** `HKObserverQuery` con *background
  delivery* registrados en `AppDelegate` al arrancar; con el teléfono bloqueado
  no leer (`isProtectedDataAvailable`); mandar solo hoy y ayer en ~25 s y
  **siempre** llamar al `completionHandler` (si no, a las 3 veces iOS deja de
  despertar la app); pedirle a iOS tiempo extra si la app pasa a segundo plano a
  mitad de una vuelta. Solo se prueba en un iPhone real.
- **[PENDIENTE] Identidad de la app:** el identificador es
  `com.example.vidaDemo`. Push y *background delivery* se configuran en Apple
  Developer para un identificador concreto: hay que fijar el definitivo antes
  (ver "Puntos abiertos"). Lo mismo la URL del backend (IP fija, A10) antes de
  TestFlight.
- **Carrera angosta (anotada):** si un envío de la cuenta anterior sigue en vuelo
  cuando entra otra cuenta, puede mover la marca de la nueva, que recibiría
  menos días.
- **Workouts y lo manual (1 oct) — hecho:** Swift no manda una sesión si no hay
  ritmo cardíaco medido en su ventana (antes mandaba `fc_promedio`/`fc_maxima`
  en `0`), ni los workouts, pasos o lecturas de ritmo cardíaco escritos a mano
  (`metadata[HKMetadataKeyWasUserEntered] == true`). Ver "Qué cuenta como
  workout" y "Lo escrito a mano no cuenta". `fc_promedio` y `fc_maxima` ahora se
  calculan a partir de las lecturas medidas dentro del workout (antes salían de
  una consulta de estadísticas de HealthKit que no permitía excluir lo manual).
  Un error real al leer el ritmo cardíaco no se traga: falla la lectura del día
  (no se da por enviado) en vez de perder el workout en silencio. "Sin muestras"
  se trata como "sin ritmo cardíaco", que es lo normal en un iPhone sin reloj.
  El servidor mantiene su descarte de sesiones con `fc` en `0` como red de
  seguridad.

---

## Premios, canje y cupones (3 oct 2026)

Todo con token (`Authorization: Token <clave>`); `401` sin él y `403` si la
cuenta no tiene perfil de usuario. **La forma sigue la del mock de la app**
(`premios.json`) para que Daniel cambie el origen de los datos sin tocar los
modelos; los `id` son texto.

### `GET /api/v1/monedas/saldo`

```json
{
  "saldo": 35,
  "vence": "2027-01-03",
  "dias_para_cierre": 88,
  "aviso_fin_de_season": false,
  "puede_canjear": true,
  "season": { "numero": 4, "anio": 2026, "monedas_ganadas": 50, "semanas_completas": 2 }
}
```

- `vence` es el domingo en que cierra la season: ese día todavía se pueden usar
  y al siguiente el saldo vuelve a 0. `aviso_fin_de_season` es `true` desde 7
  días antes (el aviso de que las monedas se reinician).
- `puede_canjear` es `false` sin póliza verificada (sin póliza, pendiente o
  rechazada): las monedas se ganan igual, pero no se gastan. La app lo usa para
  el candado del botón de compra.
- `season.monedas_ganadas` suma lo ganado en la season (no baja al gastar) y
  `semanas_completas` cuenta las semanas con los dos objetivos cumplidos: son
  los datos de la hoja de la temporada.

### `GET /api/v1/monedas/periodo?desde=&hasta=` (hecho 4 oct 2026)

Qué pasó con las monedas en un período, para los filtros de semana, mes y año.
`desde` y `hasta` son obligatorios (`AAAA-MM-DD`, `desde` ≤ `hasta`, máximo 366
días; fuera de eso `400`).

```json
{
  "desde": "2026-10-01", "hasta": "2026-10-31",
  "ganadas": 40, "por_objetivos": 10, "por_liga": 30, "otras": 0,
  "gastadas": 40, "vencidas": 0, "anuladas": 0
}
```

- `ganadas` = `por_objetivos` + `por_liga` + `otras` (lo que se acreditó a mano).
  `gastadas` son los canjes. `vencidas`, las que caducaron al cerrar la season.
  `anuladas`, lo que se descontó a mano (por ejemplo, el retroactivo denegado).
  Todo en positivo.
- **Cada movimiento cuenta en su fecha**, no en la de la actividad: las ganadas,
  cuando se pagaron (el cierre del martes o el pago del día 9 de La Liga); las
  vencidas, cuando se asentaron, que es la primera vez que se pidió el saldo
  después del cierre de la season. Antes de contar se asientan las pendientes,
  igual que en `monedas/saldo`.
- Sirve para cuadrar: `ganadas − gastadas − vencidas − anuladas` es lo que cambió
  el saldo en ese período.

### `GET /api/v1/premios`

```json
{
  "categorias": ["Todos", "Cafecitos", "Restaurantes"],
  "premios": [{
    "id": "7", "nombre": "Ookii", "zona": "Guatemala", "categoria": "Restaurantes",
    "descripcion": "2x1 en sushi", "detalle": "...", "condiciones": "...",
    "costo_monedas": 40, "vence": "2026-12-31",
    "foto": "assets/img/premios/restaurantes/ookii.webp", "fondo": null,
    "destacado": false
  }]
}
```

- Solo salen los premios **activos** y dentro de su fecha de canje. El catálogo
  se ve **completo con o sin póliza**.
- `vence` es el último día para canjearlo y puede venir en **`null`** (premio
  sin fecha). `foto` y `fondo` vienen en `null` si el premio no tiene logo o
  usa fondo blanco: el catálogo tiene que seguir saliendo con el placeholder.
- `destacado` es `true` para el comercio que compró visibilidad hoy (ver
  "Patrocinios") y `false` para los demás.
- `categorias` empieza con `"Todos"` y sigue con las que tengan los premios
  que salen, en orden alfabético.

### `POST /api/v1/premios/<id>/canjear`

Sin cuerpo. Canjea el premio con las monedas del usuario y devuelve **201** con
el cupón y el saldo que queda:

```json
{ "cupon": { "...": "ver abajo" }, "saldo": 60 }
```

| Código | `error` | Cuándo |
|---|---|---|
| 403 | `poliza_no_verificada` | Sin póliza verificada. No se toca nada. |
| 404 | — | El premio no existe. |
| 409 | `premio_no_disponible` | Está apagado o ya pasó su fecha de canje. |
| 409 | `saldo_insuficiente` | No alcanzan las monedas; trae `saldo` y `costo`. |

- El descuento (una fila `canje` negativa en el ledger) y el cupón se escriben
  **en la misma transacción**: nunca queda uno sin el otro.
- El cupón **caduca a las 3 semanas** (21 días) del canje (hora de Guatemala),
  aparte de las monedas. Los cupones ya emitidos conservan la fecha que tenían. El código es único, con la forma `MV-XXXX-XXXX` (sin 0, O, 1, I
  ni L, para que se lea y se teclee bien en caja).
- Se puede canjear el mismo premio más de una vez; cada canje es otro cupón.
- Un premio con costo 0 (promoción gratis) se canjea igual, sin mover el ledger.
- Los canjes que existían antes del 3 oct reciben un código al migrar
  (`coins/0002`).

### `GET /api/v1/cupones`

```json
{
  "cupones": [{
    "id": "12", "comercio": "Ookii", "beneficio": "2x1 en sushi",
    "codigo": "MV-OK41-7XQ2", "origen": "tienda",
    "canjeado": "2026-10-03", "vence": "2026-12-02", "dias_para_vencer": 60,
    "estado": "activo", "foto": null, "fondo": null,
    "costo_monedas": 40, "ganado_en": null, "usado_el": null
  }],
  "por_usar": 1
}
```

- Trae **todos** los cupones del usuario en una lista: `origen` es `tienda`
  (comprado con monedas), `semana` o `liga` (ganados en una semana o un podio
  patrocinados). Primero los activos —el que vence antes arriba— y después los
  usados y vencidos, del más reciente al más viejo. La app arma "Mis cupones"
  y el desplegable de usados y vencidos con `estado`.
- `estado`: `activo`, `usado` o `vencido`. **El servidor lo calcula**: un
  cupón activo pasa a `vencido` al día siguiente de su `vence` (el último día
  todavía vale). `dias_para_vencer` es 0 en los que no están activos.
- `costo_monedas` es `null` en los que se ganaron; `ganado_en` ("Semana 1")
  solo viene en esos.
- `por_usar` cuenta los activos (la píldora de la pestaña).

### Admin

- **Premios:** se crean y editan a mano (nombre, comercio, categoría, costo,
  detalle, condiciones, logo, fondo, fecha límite y `activo`). Apagar un premio
  lo saca del catálogo sin borrarlo: los cupones ya canjeados siguen
  apuntando a él.
- **Cupones:** acción "Marcar como usado" (ver "Puntos abiertos").
- **Patrocinios:** aquí se venden las semanas, los meses de La Liga y los
  premios destacados (ver "Patrocinios").
- Para cargar el catálogo del mock de la app:
  `python manage.py importar_premios <ruta al premios.json>`. Es idempotente
  (un premio se identifica por nombre y comercio), no apaga lo que ya no esté
  en el archivo y guarda todo o nada: si un premio viene mal, avisa cuál y no
  guarda ninguno.

---

## Patrocinios (4 oct 2026)

Una marca puede comprar tres cosas (las tres vías de ingreso del comercio): una
**semana** del objetivo semanal, **La Liga de un mes** y el **destacado** de su
premio en el catálogo. Todo se carga a mano en el admin (tabla *Patrocinios*);
la marca viaja dentro de los endpoints que ya usa la app y, además, hay un
endpoint que lista todo lo vendido (ver abajo). Sin patrocinio no se dibuja
nada (nunca un hueco ni un cartel).

**Qué lleva un patrocinio:** el comercio (el mismo del catálogo de Premios: de
ahí salen el nombre de la marca, el logo y el color de fondo), el periodo
(`desde` y `hasta`, inclusivos), el texto del cupón que se gana, el color de
`acento`, las fotos del carrusel y `activo`. Apagarlo lo quita de la app sin
borrarlo. El admin valida que una semana vaya de lunes a domingo, que un mes de
La Liga vaya del día 1 al último, que semana y liga tengan texto de cupón y que
el comercio tenga logo. **Una sola marca por semana y por mes de La Liga.**

**La forma que lee la app** (`Patrocinio.desdeJson` en Dart), igual en las tres
partes donde aparece:

```json
{
  "id": "12",
  "marca": "Montanos",
  "logo": "assets/img/premios/restaurantes/montanos.webp",
  "fondo": "#000000",
  "acento": "#8C5A3C",
  "cupon": "2x1 en Puyazo 8 oz",
  "fotos": ["assets/img/premios/restaurantes/montanos.webp"]
}
```

`id` es el id del premio del comercio, el mismo del catálogo. `fondo` y
`acento` vienen en `null` si no se cargaron; `fotos` viene vacía si no hay (el
carrusel usa solo el logo).

**Dónde sale:**

| Compra | Dónde viaja |
|---|---|
| Semana | `patrocinador` de cada semana en `GET /api/v1/objetivos/semanas` |
| La Liga de un mes | `liga.patrocinio` de La Liga en `GET /api/v1/ligas` (Tus Ligas siempre `null`) |
| Premio destacado | `destacado: true` del premio en `GET /api/v1/premios` (vigente si hoy cae entre `desde` y `hasta`) |

#### `GET /api/v1/patrocinios`

Con token (`403` si la cuenta no tiene perfil). Lista **todo lo vendido que
todavía no terminó** (la semana, el mes o el destacado de hoy y los de más
adelante; lo apagado y lo que ya pasó no salen), ordenado por fecha. Es lo mismo
que viaja dentro de las otras pantallas, en un solo lugar, para quien necesite
saber qué hay vendido sin pedir cada pantalla.

```json
{
  "semanas": [{
    "fecha_inicio": "2026-10-05", "fecha_fin": "2026-10-11",
    "patrocinador": {"id": "12", "marca": "Montanos", "logo": "assets/img/premios/restaurantes/montanos.webp",
                     "fondo": "#000000", "acento": "#8C5A3C", "cupon": "2x1 en Puyazo 8 oz", "fotos": []}
  }],
  "ligas": [{
    "arranca": "2026-10-01", "cierra": "2026-10-31",
    "patrocinio": {"id": "7", "marca": "Ookii", "logo": "assets/img/premios/restaurantes/ookii.webp",
                   "fondo": null, "acento": null, "cupon": "2x1 en sushi", "fotos": []}
  }],
  "destacados": [{"premio_id": "7", "desde": "2026-10-04", "hasta": "2026-10-31"}]
}
```

`patrocinador` y `patrocinio` llevan la forma de marca de arriba; los
destacados dicen solo qué premio (`premio_id`, el id del catálogo) y hasta
cuándo, porque el premio ya lo trae `GET /api/v1/premios`. Las tres listas
vienen siempre, vacías si no hay nada.

**Cupones que se ganan** (siempre **además** de las monedas, nunca en lugar de
ellas). Los crea el servidor al cerrar el ciclo y aparecen en
`GET /api/v1/cupones` con `origen` `semana` o `liga`:

- **Semana patrocinada:** al cierre del martes 00:00, quien **completó** la
  semana (los dos componentes) gana el cupón. Con un solo componente cumplido
  cobra sus monedas pero no el cupón. `ganado_en` = "Semana 7".
- **La Liga patrocinada:** el día 9, al pagar el podio (antes, al cerrar el día 2), los
  que ganan monedas (el podio, con al menos 1 punto) ganan el cupón. `ganado_en` = "La Liga de octubre".
- **Hace falta póliza verificada al momento de ganarlo** (decidido 4 oct; en La Liga, al pagar el día 9, no al cerrar): un
  cupón es un premio, y todo premio exige póliza. Sin ella las monedas se
  ganan igual, pero el cupón no. Tampoco se da por una semana anterior a la
  verificación si se denegó el retroactivo.
- **Un patrocinio da un solo cupón por persona**: correr el cierre dos veces,
  o la corrección de las 12:00, no duplica.
- El cupón caduca a las **3 semanas** (21 días) de ganado (igual que uno canjeado), no
  cuesta monedas (`costo_monedas` en `null`) y su `beneficio` es el texto del
  cupón del patrocinio, no el del premio del catálogo. Si un patrocinio se
  carga o se apaga **después** del cierre, no se premia hacia atrás.
- Los resúmenes de `cerrar_semana` y de `pagar_la_liga` traen `cupones`: cuántos se
  entregaron (el cierre de La Liga ya no trae `monedas_pagadas`, sino `monedas_por_pagar`).

**[PENDIENTE]:** Diego define los comercios, los textos de cupón y las fotos
de cada marca (las del mock son de ejemplo). Qué pasa con el cupón de quien
ganó sin póliza verificada (hoy no se da) lo confirma el negocio.

---

## Puntos abiertos

*Del 3 oct (sincronización):*

- **Identificador definitivo de la app (*bundle ID*):** hoy es
  `com.example.vidaDemo`, el de ejemplo de Flutter. Es el nombre de la app para
  Apple (App Store, Apple Developer, notificaciones push, permisos de Salud), no
  la dirección del backend. **Una vez publicada no se puede cambiar** (sería otra
  app). Candidato: `com.assures.masvida`, que ya usan el canal de Swift y el
  Keychain. Frena A32 (segundo plano) y las notificaciones push.
- **Margen de gracia del cierre semanal — resuelto (3 oct):** martes 00:00
  (ver "Ciclos y cortes"). Hecho en A34.
- **Notificaciones push:** cómo se registra el teléfono (directo en Swift con
  APNs, recomendado: sin un tercero con datos del usuario, o con Firebase desde
  Flutter) y cuándo suena el recordatorio (24 h sin datos, domingo en la tarde,
  o las dos). Necesita: llave `.p8` en Apple Developer, modelo y endpoint de
  dispositivos en el backend, envío programado y la pantalla del permiso.
- **Monedas de La Liga — resuelto (3 oct):** van a los 3 primeros, como ya
  decían los términos y `CLAUDE.md`. Quedan abiertos cuántas monedas da cada
  puesto y qué pasa con un empate total (ver "La Liga y Tus Ligas").
- **Textos de los términos:** dicen que los demás ven "tu nombre y tu posición"
  (desde el 2 oct también ven los puntos) y "4 temporadas de 13 semanas" (la
  season 4 de 2026 tiene 14).

*De la reunión del 2 oct:*

- **Endpoints que faltan definir:** inicio de sesión con Google y Apple y
  patrocinios (el de cashback en quetzales y los patrocinios ya están). (Ya están hechos la lista de semanas de
  la season, `objetivos/semanas`, y los de saldo, premios, canje y cupones.)
- **Póliza cancelada después de verificada:** cómo se entera el sistema y qué
  pasa con los puntos y monedas de ese momento.
- ~~Año de póliza y cuentas sin póliza~~, ~~puntos de antes del inicio de la
  póliza~~ y ~~cuándo se paga el cashback~~ — **decididos el 4 oct**: ver
  "Cashback en quetzales".
- **Transición de la season en curso:** según la regla nueva, la season 4 de
  2026 empezó el lunes 28 sep y termina el domingo 3 ene 2027 (14 semanas), y
  el código ya la calcula así (2 oct). Falta decidir qué pasa con las monedas
  que se pagaron en las semanas de la season 3 (hasta el 27 sep) cuando se
  construya el reinicio de saldo: ¿se reinician el 28 sep o no se tocan?

*Encontrados en la revisión contra el código (1 oct):*

- **Ritmo cardíaco de Garmin (por verificar en un dispositivo):** según lo
  publicado, Garmin sincroniza a Apple Salud solo el ritmo cardíaco alto y bajo
  de una actividad. Si es así, el `fc_promedio` de un workout de Garmin sería
  el punto medio entre dos lecturas y no su promedio real, y podría subestimar
  la intensidad. Se aclara con un reloj Garmin real.
- **Datos falsos escritos por programa:** el filtro de lo manual no detecta una
  app que escriba pasos o workouts falsos en HealthKit sin marcarlos. Es un
  límite de HealthKit; se mitiga con las reglas del servidor (topes por muestra,
  ventana de 14 días), no se resuelve.

- ~~Días anulados y objetivo semanal~~ — **resuelto** (5 oct): no cuentan para la meta
  semanal ni para el desempate de las ligas (ver "Retroactividad").
- **Programar `cerrar_semana` — resuelto en el repo (1 oct):** lo corre el
  servicio `programador` de Compose (ver "Cierre semanal programado"). Falta
  confirmar con quien despliegue que producción usa Compose; si no, hay que
  programar las dos tareas de la tabla de esa sección.
- **`zona_horaria` y `app_version`:** el servidor los exige pero no los usa.
  Decidir si se usan (días en la zona del usuario, rechazar versiones viejas)
  o se dejan solo como dato.
- **Cuánto paga el objetivo semanal:** desde el 2 oct, 5 monedas por pasos +
  5 por workouts, de forma **provisional** (la reunión los dio de ejemplo). El
  código ya paga por componente (3 oct); los montos se editan en el admin.
- **La Liga y Tus Ligas:** endpoints, salir de un grupo y cierre mensual hechos
  (3 oct). Falta el cupo de miembros y el alias público (ver "Endpoints de La
  Liga y Tus Ligas"). La tabla `TramoPremio` (premios por percentil) quedó
  sin uso: decidir si se borra. El código de invitación se valida único al
  crearlo, pero la columna todavía no tiene restricción `unique` en la base.
- ~~Cupones que se ganan (semanas y podios patrocinados)~~ — **hecho** (4 oct):
  los crean el cierre semanal y el pago del podio de La Liga (ver "Patrocinios").
- **Quién marca un cupón como usado:** hoy solo se hace a mano en el admin
  (acción "Marcar como usado"). Falta decidir si el comercio lo marca (por
  ejemplo con un endpoint que reciba el código) o si basta con que venza.

*Abiertos desde antes:*

- **Aviso al usuario cuando se deniega el retroactivo (1 oct):**
  `POST /polizas/vincular` responde `verificada` sin decir que se anularon los
  puntos anteriores. Falta decidir si la respuesta lleva un campo (por ejemplo
  `retroactivo: "aplicado" | "denegado"`) para que la app lo explique con tono
  cálido, o si el usuario lo descubre en el historial.
- **Anillos (Oura):** falta verificar con un anillo real qué escribe a Apple
  Salud (pasos, ritmo cardíaco, workouts). Mientras tanto un anillo se trata
  como cualquier otro dispositivo en la elección de fuente. Hoy el backend,
  además, infiere sesiones intensas desde `frecuencia_cardiaca[]` cuando no hay
  un workout que las cubra, para todos los dispositivos.
- **`VersionRegla` inicial — resuelto (2 oct):** la migración `poincs/0007` carga
  la versión 1 sola, con cualquier `migrate`; no hace falta comando ni fixture.
  Cuando cambie una regla de puntaje o de monedas, se agrega una versión nueva
  con su `vigente_desde` (por ejemplo con otra migración de datos igual a esa).
  **La versión 2** (migración `poincs/0008`, vigente desde el **2 oct 2026**)
  marca las reglas de la reunión de ese día, empezando por las monedas sin tope
  que caducan con la season. Cada fila de los ledgers queda sellada con la versión
  vigente en su fecha: lo anterior al 2 oct es versión 1 y lo posterior, versión 2.
  La versión es solo una etiqueta de auditoría: los cálculos los hace el código.
- **Filas antiguas del ledger (`puntos_diarios`):** el formato viejo de una
  fila por día ya no se lee. No hay datos reales en ese formato; una base de
  pruebas vieja se vuelve a sincronizar.
- ~~Logout en el servidor~~ — **hecho** (4 oct): `POST /api/v1/logout` cierra este
  teléfono y `POST /api/v1/logout/todos` todos (A35, un token por sesión con Knox).
  **[PENDIENTE]:** que cambiar la contraseña y borrar la cuenta cierren todas las
  sesiones (todavía no existen esos endpoints).
- **Qué estado ve Flutter cuando Swift no tiene sesión:** hoy recibe `encolado`.
  Falta decidir si se queda así o se agrega un estado nuevo (cambia el contrato).
- **Cola y marca al cerrar sesión o entrar otra cuenta — resuelto (3 oct; cambiado
  en A35, 4 oct):** se vacían solo si entra **otra persona** (otro `usuario_id`);
  cerrar sesión solo borra el token. La cuenta que entra nueva recibe sus 7 días.
- ~~Caducidad del token~~ — **hecha** (4 oct; A35 la pasó a Knox): vence a los 30 días
  sin uso, cada uso la renueva, tope de 90 días y guardado como hash. Queda abierto
  exigir HTTPS fuera de pruebas locales (paquete 7) y, más adelante, tokens de vida
  corta con uno de renovación como las plataformas grandes.
- **`Token` o `Bearer` en el encabezado:** se dejó `Token` porque es lo que espera
  django-rest-knox (y antes Django REST Framework); `Bearer` es el estándar de OAuth 2.0 y se puede configurar
  más adelante.
- **Días vacíos:** emparejar los tres caminos de envío frente a un día sin
  actividad (ver "Días sin actividad").
- **Tipo de dispositivo:** las tres columnas y la función de derivación ya
  existen en el backend, pero desde el 1 oct el puntaje no las usa (ver
  "Elección de fuente"). Queda decidir si `tipo_dispositivo` se guarda o se
  deriva al vuelo para los reportes de la aseguradora. La regla
  `desconocido → telefono` ya no afecta ningún puntaje. Ver "Puntos abiertos"
  en `decision-tipo-dispositivo.md`.
- **Metas del objetivo semanal:** la tabla de pasos por edad es provisional
  (ver "Meta de pasos por edad"); falta ajustarla con 2 a 4 semanas de datos
  del piloto. Falta decidir cuántos workouts y qué meta tiene un menor de 18
  (la tabla empieza en 18; mientras tanto el código le da la de 18 a 29). (Qué es un
  workout ya está decidido: cualquier entrenamiento con ritmo cardíaco, de
  cualquier duración.)
- **Monedas de cada puesto de La Liga:** cuántas al 1.º, al 2.º y al 3.º
  (Diego), y qué pasa con un empate total en puntos y pasos. El código usa
  30 / 20 / 10 y puesto compartido, provisionales.
