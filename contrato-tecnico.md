---
title: Contrato técnico — estado actual (iOS ↔ Backend ↔ Flutter)
---

# Contrato técnico — +Vida

**Actualizado el 3 oct 2026** (cierre semanal): la semana se cierra el **martes
00:00**, no el lunes: los datos atrasados del domingo tienen **todo el lunes**
para llegar (como StepBet, 24 h). Ya está en el código (A34). El objetivo de la
semana nueva se sigue fijando el lunes 00:00. Ver "Ciclos y cortes" y "Cierre
semanal programado".

**Actualizado el 3 oct 2026** (La Liga): las monedas de La Liga van a **los 3
primeros** del mes, no por percentil. Ver "La Liga y Tus Ligas".

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
cerrar cada season; **La Liga compite por puntos**, con desempate por pasos;
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
fuente pasa de "gana el reloj" a **una decisión por hora** para los pasos; un
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

   La palabra es `Token` (así la espera Django REST Framework), no `Bearer`.
3. El servidor busca a quién pertenece ese token y trabaja con ese usuario.
   Nunca toma la identidad del cuerpo de la petición.

**No piden token:** `POST /api/v1/registro`, `POST /api/v1/login` y
`GET /api/health/`. Todo lo demás sí.

### Registro y login

| Petición | Cuerpo | Respuesta |
|---|---|---|
| `POST /api/v1/registro` | `{ "username": string, "password": string, "birth_date": "YYYY-MM-DD" }` | `201` `{ "token": string, "username": string, "usuario_id": string }` |
| `POST /api/v1/login` | `{ "username": string, "password": string }` | `200` `{ "token": string }` |

Errores: `400` con un objeto `{ "<campo>": [mensajes] }` (usuario repetido,
contraseña débil, fecha de nacimiento futura) o `{ "non_field_errors": [...] }`
(credenciales incorrectas en el login).

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

### Reglas del token

- Hay **un token por cuenta** y **no caduca** por ahora (ver "Puntos
  abiertos").
- Se trata como una contraseña: nunca se escribe en logs ni en mensajes de
  error, y nunca viaja dentro del cuerpo de una petición.
- Flutter guarda su propia copia para sus llamadas HTTP. A Swift se la entrega
  con `actualizarSesion` (ver "MethodChannel"); Swift guarda la suya en su
  Keychain y la usa para enviar el `sync`.

### `usuario_id`

Identificador **público** de la persona: un UUID que genera el servidor al
registrarse y que devuelve en la respuesta del registro. Sirve para mostrar y
compartir (hoy la app lo muestra en Perfil y lo usa como código para agregar
amigos). **No identifica a quien manda datos y no viaja en ninguna petición.**

No confundir con la columna interna `usuario_id` de las tablas del servidor
(`(usuario_id, external_id)`, `(usuario_id, fecha)`), que es la referencia a la
fila del usuario y no tiene relación con este campo.

### Respuestas de error de autenticación

| Situación | Código | Cuerpo |
|---|---|---|
| Falta el encabezado | `401` | `{ "detail": "..." }` y el encabezado `WWW-Authenticate: Token` |
| Token inválido | `401` | `{ "detail": "..." }` |
| Token válido pero la cuenta no tiene perfil de usuario | `403` | `{ "mensaje": "..." }` |

Los textos pueden salir en inglés (los mensajes estándar de Django REST
Framework, como los de `401` o "This field is required.") o en español (los
propios del proyecto, como el de `403`), y pueden cambiar: los clientes deciden
**siempre por el código de estado**, nunca por el texto.

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
| `fecha` | string (YYYY-MM-DD) | sí | día calendario que se está sincronizando. El servidor guarda todas las muestras que llegan y **recalcula ese día** con todas las guardadas que **empiezan** dentro de él, en hora de Guatemala |
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

### Elección de fuente — por hora (decidido 1 oct 2026)

Reemplaza la regla anterior "si hay reloj ese día, el reloj gana", que dejaba en
cero a quien usa el reloj solo para dormir o solo para entrenar. **Nunca se
suma la misma actividad dos veces, y nunca se descarta actividad real.**

| Métrica | Regla |
|---|---|
| **Pasos** | En **cada hora** (hora de Guatemala) gana el dispositivo con más pasos en esa hora; después se suman las horas. Una muestra cuenta en la hora en que **empieza**. |
| **Workouts** | Si dos dispositivos registran el mismo entrenamiento (se cruzan en el tiempo) cuenta **uno**, el más largo. Los que no se cruzan cuentan todos, aunque vengan de dispositivos distintos. |
| **Intensidad** | Cada dispositivo calcula la suya con sus propias sesiones y su propio ritmo cardíaco; gana el de más puntos. No se suman. |

Ejemplos: reloj solo de noche + teléfono de día → se cuentan los pasos del día
del teléfono y los de la noche del reloj. Teléfono en el locker y reloj en el
gym → en la hora del gym gana el reloj, el resto del día el teléfono.

El día se **recalcula completo en cada sync** de esa fecha, a partir de lo
guardado y no del último payload: un reloj de terceros que escribe a Apple
Salud con horas de retraso corrige el resultado solo (con una fila de ajuste en
el ledger, nunca editando una existente).

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
| `puntos_dia` | int | suma de los dos anteriores, con el techo diario de 200 pts ya aplicado. **Es lo que calculó el día, no necesariamente lo acreditado:** no refleja el techo anual ni un día anulado por retroactivo. Lo acreditado está en `GET /api/v1/historial` |
| `tope_diario_aplicado` | bool | true si los puntos brutos pasaron de 200 (llegar a 200 justos no es recorte) |
| `puntos_ano` | int | lo acreditado en el **año de póliza** en curso (desde la fecha de inicio o la última renovación de la póliza; suma del ledger), con el techo de 12.000 ya aplicado. **[PENDIENTE] (código):** hoy se cuenta del 1 de enero al 31 de diciembre |
| `tope_anual_aplicado` | bool | true si el techo del año de póliza **recortó lo de este día** |
| `nivel` | int (0–4) | nivel de cashback del **año de póliza**, según `puntos_ano`: 0 bajo 2.500, 1 desde 2.500 (5%), 2 desde 5.000 (7,5%), 3 desde 10.000 (10%), 4 desde 15.000 (20%) — no confundir con el **objetivo semanal** (ver abajo) |
| `pasos_totales_dia` | int | total de pasos del día con la regla por hora (ver "Elección de fuente"). Nunca es una suma cruda de `pasos[].cantidad` de dispositivos distintos |

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
**[PENDIENTE] (Luis):** el endpoint de patrocinios, pendiente desde septiembre;
hasta entonces `patrocinador` viene en `null` en todas las semanas.

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
- Los **cupones ya canjeados** no cambian: caducan a los 60 días del canje.

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
- **[PENDIENTE]** el endpoint de saldo, que es lo que la app lee para mostrar las
  monedas y el aviso, va con el paquete de premios y canje.

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
- `patrocinador` viene en `null` hasta que exista el endpoint de patrocinios.

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
- **[PENDIENTE]** los días anulados por retroactivo denegado (ver "Póliza
  vinculada") **sí** cuentan para el progreso de la semana en curso. Las
  monedas solo se anulan si la semana entera cerró antes de la verificación.

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
- **Desempate:** a igualdad de puntos gana quien tenga **más pasos** en el mes
  (suma de `pasos_totales_dia`). La app lo explica con un botón de información.
- **Qué se muestra:** los **puntos** de cada participante sí; la **cantidad de
  pasos** nunca, ni siquiera para explicar un desempate (decidido 2 oct 2026).
- **Patrocinio:** algunos meses La Liga tiene una marca. Es la misma Liga, no
  una aparte: la marca se muestra arriba, junto al nombre de la liga,
  destacada, y los 3 primeros ganan además un cupón de esa marca.
  **[PENDIENTE] (Luis):** el endpoint de patrocinios.
- **Premio: monedas a los 3 primeros** del mes (decidido 3 oct 2026; reemplaza
  los premios por percentil). Nadie más gana monedas en La Liga. El servidor
  calcula la posición **una sola vez, al cierre del mes**, con el desempate de
  arriba, y paga las monedas en ese momento.
  - **Cuántas monedas a cada puesto (1.º, 2.º, 3.º): [PENDIENTE] (Diego).**
  - **Empate total** (mismos puntos y mismos pasos en el mes):
    **[PENDIENTE]**. Opciones: compartir el puesto y la misma cantidad de
    monedas, o desempatar por quien llegó antes a esos puntos.
  - El ranking devuelve `premios_monedas`: una lista con las monedas del 1.º, el
    2.º y el 3.º (vacía si el grupo no premia, como Tus Ligas). Flutter ya la lee
    (`GrupoRanking.premiosMonedas`).
  - Con patrocinio, el cupón de la marca es **además** de las monedas, para los
    mismos 3.

**Tus Ligas:** grupos que crea o a los que se une el usuario. Ranking mensual
**por puntos** entre miembros (decidido 2 oct 2026, igual que La Liga; antes era
por pasos), con el mismo desempate por pasos, **sin premios y sin exigir póliza** (cambia el 23
sep; antes exigían póliza).

**Duelos 1 contra 1:** eliminados del demo 1 — no construir endpoints ni
pantallas. Los endpoints de La Liga y de Tus Ligas: por definir con Luis y
Daniel.

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
1. **Al iniciar sesión o registrarse**, con el token.
2. **Al cerrar sesión**, con `null`.
3. **Cada vez que abre la app**, con el token actual (o `null` si no hay
   sesión). Así la copia de Swift no se desincroniza, ni siquiera después de
   reinstalar: el Keychain sobrevive a desinstalar la app.

Entrada: `{ "token": string? }` — `null` significa "no hay sesión".

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
- **Si la cuenta cambia** (otro token, o `null`), Swift olvida hasta qué día se
  había mandado y **vacía la cola**: la cuenta que sigue empieza como la primera
  vez (sus 7 días) y no recibe días que esperaban a nombre de la anterior. El
  mismo token de cada arranque no cambia nada.
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
  "puntos_dia": 150
}
```

| Campo | Notas |
|---|---|
| `pasos_totales_dia` | mismo valor que ya viaja en el JSON #2 del sync — se guarda, no se recalcula |
| `workouts_dia.cantidad` / `.duracion_total_min` | agregado de los workouts del día que cuentan (sin duplicar los que dos dispositivos registran a la vez) |
| `workouts_dia.fc_promedio` | promedio de `sesiones[].fc_promedio` del día — **no** un promedio de las 24h de `frecuencia_cardiaca[]` cruda (eso incluiría horas de reposo y no dice nada) |
| `workouts_dia.fc_maxima` | máximo de `sesiones[].fc_maxima` del día |
| `workouts_dia` | `null` si no hubo sesión ese día — no `0`, para no confundir "sin actividad intensa" con "FC de cero" |
| `puntos_dia` | mismo valor que ya viaja en el JSON #2, **salvo** un día anulado por retroactivo denegado (ver "Póliza vinculada"), que aquí y en el historial va en `0` |

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
`fecha_nacimiento_no_coincide`. Una póliza puede estar vinculada a varios
usuarios (pólizas familiares). `409` si el usuario ya tiene una póliza
verificada; `400` por campos faltantes; `403` si la cuenta no tiene perfil.
Una rechazada se puede volver a enviar.

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
ya pasó, se responde la del año siguiente (y así hasta hoy o después; el 29 de
febrero cae en el 28 los años que no son bisiestos). `verificada` es el único valor que debe usarse
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

### Cashback en quetzales (decidido 2 oct 2026)

**Monto = % del nivel × prima anual.** Se devuelve como dinero **después** del
pago de la prima, nunca como descuento (regla regulatoria, ver `CLAUDE.md`). Se
muestra en Mi Plan, debajo de las gráficas.

**El año del cashback es el año de póliza** (decidido 2 oct 2026): los puntos
anuales, el techo de 12.000, el nivel y el cashback se cuentan desde la fecha de
inicio (o la última renovación) de la póliza hasta su siguiente renovación, no
del 1 de enero al 31 de diciembre. Con varias personas en la misma póliza
(pólizas familiares), todas comparten esas fechas.

**[PENDIENTE] (Luis):**
- No hay endpoint que devuelva el cashback.
- El código cuenta el año por calendario (`fecha__year` en el ledger y en el
  techo anual); hay que pasarlo al año de póliza.

### Retroactividad

Al verificarse, la fecha de nacimiento de la **cuenta** (la del registro) se
compara con la **confirmada por la aseguradora**:

- **Coinciden:** todo lo ganado en la cuenta base (puntos y monedas) cuenta.
- **No coinciden:** no hay retroactividad. Los días anteriores a la
  verificación se anulan con una fila negativa por día en el ledger
  (`retroactivo_denegado`), y las monedas ganadas antes también. Nada se edita
  ni se borra. La edad que se usa para el puntaje es, desde la verificación, la
  confirmada por la aseguradora.

Como la verificación ocurre al vincular, "desde la vinculación" y "desde la
verificación" son el mismo momento.

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
  por hora, workouts sin duplicar los que se cruzan, intensidad por el
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
- **`pasos_totales_dia`** usa la misma regla por hora que el motor de puntos —
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
  cual, con tope y bono 60+), con desempate por pasos del mes. Al cierre del
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
  - La Liga y Tus Ligas por puntos, con desempate por pasos; en La Liga se
    devuelven los puntos de cada participante pero nunca sus pasos.
  - ~~Póliza: no rechazar por la fecha de renovación, y guardar y devolver
    nombre, apellido, plan, prima y fecha de renovación~~ — **hecho** (3 oct):
    ver "Datos que entrega la aseguradora".
  - Endpoints nuevos: cashback en quetzales, cupones (activos, usados y
    vencidos) y patrocinios.
  - Puntos anuales, techo de 12.000, nivel y cashback por **año de póliza**
    (hoy por año calendario), y prima anual en el registro de la aseguradora.
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
  oct compite por puntos**, con desempate por pasos y un botón de información
  que lo explique; si el mes está patrocinado, la marca va arriba junto al
  nombre de la liga. **Tus Ligas también compite por puntos.** En La Liga se
  muestran los puntos de cada participante, **nunca la cantidad de pasos**. Sin franjas
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

- **Endpoints que faltan definir:** inicio de sesión con Google y Apple, lista de
  semanas de la season (vista "battle pass"), cashback en quetzales, cupones
  (activos, usados y vencidos) y patrocinios.
- **Póliza cancelada después de verificada:** cómo se entera el sistema y qué
  pasa con los puntos y monedas de ese momento.
- **Año de póliza y cuentas sin póliza:** una cuenta base no tiene año de
  póliza. ¿Con qué fechas cuenta sus puntos anuales y su nivel mientras no
  vincula una póliza?
- **Puntos de antes del inicio de la póliza:** al verificar con retroactividad,
  ¿los días anteriores al inicio del año de póliza en curso cuentan para ese
  año o para el anterior?
- **Cuándo se paga el cashback:** ¿al cerrar cada año de póliza (en la
  renovación, después de pagar la prima)?
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

- **Días anulados y objetivo semanal:** un día anulado por retroactivo denegado
  sigue contando para el progreso de la semana en curso. ¿Debe contar?
- **Programar `cerrar_semana` — resuelto en el repo (1 oct):** lo corre el
  servicio `programador` de Compose (ver "Cierre semanal programado"). Falta
  confirmar con quien despliegue que producción usa Compose; si no, hay que
  programar las dos tareas de la tabla de esa sección.
- **`zona_horaria` y `app_version`:** el servidor los exige pero no los usa.
  Decidir si se usan (días en la zona del usuario, rechazar versiones viejas)
  o se dejan solo como dato.
- **Cuánto paga el objetivo semanal:** desde el 2 oct, 5 monedas por pasos +
  5 por workouts, de forma **provisional** (la reunión los dio de ejemplo). El
  código paga hoy 20 por cumplir los dos.
- **La Liga, Tus Ligas, Premios y Canje:** las tablas existen en el backend,
  pero no hay cálculo ni endpoints todavía.

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
- **Logout en el servidor:** hoy no existe un endpoint que borre el token. Como
  hay un token por cuenta, borrarlo cerraría la sesión en **todos** los
  dispositivos de esa persona. Mientras tanto, cerrar sesión en la app solo borra
  las copias locales (`actualizarSesion(null)`).
- **Qué estado ve Flutter cuando Swift no tiene sesión:** hoy recibe `encolado`.
  Falta decidir si se queda así o se agrega un estado nuevo (cambia el contrato).
- **Cola y marca al cerrar sesión o entrar otra cuenta — resuelto (3 oct):**
  Swift vacía la cola y olvida la marca; la cuenta que sigue recibe sus 7 días.
- **Caducidad y renovación del token:** hoy no caduca. Las plataformas grandes usan
  tokens de vida corta con uno de renovación. Conviene también exigir HTTPS fuera
  de pruebas locales.
- **`Token` o `Bearer` en el encabezado:** se dejó `Token` porque es lo que espera
  Django REST Framework; `Bearer` es el estándar de OAuth 2.0 y se puede configurar
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
  (Diego), y qué pasa con un empate total en puntos y pasos.
- **Endpoints de La Liga y de Tus Ligas:** sin especificar.
