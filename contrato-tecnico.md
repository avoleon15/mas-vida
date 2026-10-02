---
title: Contrato técnico — estado actual (iOS ↔ Backend ↔ Flutter)
---

# Contrato técnico — +Vida

**Actualizado el 1 oct 2026** (revisión contra el código): se comparó cada
sección con lo que hacen el backend (incluido el de Luis, ya en `dev`), Swift y
Flutter. Donde el código no cumple una regla ya decidida, la regla **no se
cambió**: se marca **[PENDIENTE]** con lo que pasa hoy. Ver "Puntos abiertos".

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
todos, La Liga con un solo grupo y premios por percentil, Tus Ligas sin
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
| `pasos[]` | array | sí (puede ir vacío) | una entrada por muestra de `HKQuantitySample` de tipo `.stepCount` |
| `pasos[].external_id` | string (UUID) | sí | el `sample.uuid` de HealthKit — clave de idempotencia |
| `pasos[].inicio` / `.fin` | string (ISO 8601 con offset) | sí | ventana exacta de la muestra |
| `pasos[].cantidad` | int | sí | pasos en esa ventana, nunca un total ya sumado |
| `pasos[].fuente_bundle` | string | sí | bundle identifier de la fuente — la clave técnica confiable |
| `pasos[].fuente_nombre` | string | sí | nombre legible de la fuente — solo para mostrar/loggear, no para lógica |
| `pasos[].fuente_version` | string | no | versión del software de la fuente |
| `pasos[].dispositivo_nombre` | string, nullable | no | **nuevo (20 sep 2026)** — `HKDevice.name`, nombre legible del hardware físico. `null` cuando `sample.device` es `nil`, nunca string vacío |
| `pasos[].dispositivo_modelo` | string, nullable | no | **nuevo** — `HKDevice.model`. Para dispositivos Apple ya es la categoría (`iPhone`/`Watch`/`iPad`), sin tabla ni parseo |
| `pasos[].dispositivo_fabricante` | string, nullable | no | **nuevo** — `HKDevice.manufacturer`. Puede venir nulo en apps puente de terceros |
| `sesiones[]` | array | sí (puede ir vacío) | una entrada por `HKWorkout` **que tenga ritmo cardíaco y no sea manual** (ver "Qué cuenta como workout"). **[PENDIENTE]** antes decía "de ≥30 min continuos", pero ni Swift ni el servidor filtran por duración |
| `sesiones[].external_id` | string (UUID) | sí | el `sample.uuid` del workout — clave de idempotencia |
| `sesiones[].inicio` / `.fin` | string (ISO 8601) | sí | ventana del workout |
| `sesiones[].duracion_min` | int | sí | duración en minutos |
| `sesiones[].tipo_actividad` | string, **nullable** | no | tipo de `HKWorkoutActivityType` en texto plano. **`null` es válido** — un reloj de terceros (ej. WHOOP) puede detectar el workout automáticamente pero no tener confianza suficiente para clasificarlo, y eso puede quedar sin corregir indefinidamente si el usuario nunca lo edita a mano. El backend nunca lo rechaza por venir nulo; se guarda tal cual y se muestra como "No registrado" |
| `sesiones[].fc_promedio` / `.fc_maxima` | int (bpm) | sí | FC durante la ventana de la sesión. **Siempre un valor medido**: si no hubo muestras de ritmo cardíaco en la ventana, Swift no manda la sesión (nunca manda `0`) |
| `sesiones[].fuente_bundle` / `.fuente_nombre` | string | sí | mismo criterio que pasos[] |
| `sesiones[].dispositivo_nombre` / `.dispositivo_modelo` / `.dispositivo_fabricante` | string, nullable | no | **nuevo** — mismo criterio que pasos[] |
| `frecuencia_cardiaca[]` | array | sí (puede ir vacío) | una entrada por muestra `.heartRate` del día completo, esté o no dentro de un workout |
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
completamente vacío. La cola de reintentos (A8) y el backfill de 7 días (A9)
**saltan** los días vacíos — un payload vacío es indistinguible entre "sin
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
  inventar. Swift no los manda (`HKMetadataKeyWasUserEntered`).
- Un workout que cuenta suma a `workouts_dia` (dashboard) y al objetivo
  semanal, además de a los puntos de intensidad.
- **[PENDIENTE] Duración mínima:** hoy un workout cuenta **sin importar cuánto
  dure** (comprobado: uno de 10 min con ritmo cardíaco suma 1 workout a la
  semana, aunque da 0 puntos de intensidad, que sí exigen 30 min). Falta
  decidir si para el objetivo semanal debe durar al menos 30 min.
- Las sesiones intensas que el servidor **infiere** del ritmo cardíaco (sin un
  workout registrado) dan puntos de intensidad, pero **no** cuentan como
  workout.

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
| `puntos_ano` | int | lo acreditado en el año (suma del ledger), con el techo de 12.000 ya aplicado |
| `tope_anual_aplicado` | bool | true si el techo anual **recortó lo de este día** |
| `nivel` | int (0–4) | nivel **anual** de cashback según `puntos_ano`: 0 bajo 2.500, 1 desde 2.500 (5%), 2 desde 5.000 (7,5%), 3 desde 10.000 (10%), 4 desde 15.000 (20%) — no confundir con el **objetivo semanal** (ver abajo) |
| `pasos_totales_dia` | int | total de pasos del día con la regla por hora (ver "Elección de fuente"). Nunca es una suma cruda de `pasos[].cantidad` de dispositivos distintos |

No incluye ningún campo que explique *por qué* se descartó una muestra, se
detectó una sesión intensa, o se aplicó un techo — esa lógica es del backend.

**Techo anual de 12.000:** con el chequeo médico fuera de v1, ese es el máximo
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

Si el servidor no tiene ninguna versión de reglas cargada responde `500`, y
Swift reintenta los `5xx` (ver "Puntos abiertos").

---

## Mecánica de objetivos semanales (fuera del payload de sync)

*Antes "mecánica de retos semanales" — el nombre "reto" ya no existe, todo es
objetivo semanal.*

Por dificultad progresiva, no por meta de puntos. **No hay rachas diarias** —
si aparecen en algún doc de pantallas, es material viejo. La progresión
numérica (1, 2, 3...) se llama **objetivo semanal** — nunca "nivel", para no
confundirla con el nivel anual de cashback del JSON #2.

### Demo 1 (temporal, acordado 23 sep) — objetivo fijo, igual para todos

Para el demo 1 **todos los usuarios tienen el mismo objetivo cada semana**,
hardcodeado. No hay progresión entre objetivos.

- **Duración siempre igual:** lunes 00:00 a domingo 23:59.
- **Dos componentes:** (a) **pasos totales de la semana** y (b) **cantidad de
  workouts**. Ejemplo: "30.000 pasos y mínimo 1 workout".
- Se cumple al alcanzar **ambas** métricas dentro de la semana.
- **No se sube ni se congela objetivo** en el demo. La sección "Diseño
  completo" de abajo y las seasons **se mantienen como diseño**.
- Los valores (meta de pasos y de workouts) viven en una tabla/config
  hardcodeada del backend, editable a mano — sin cálculo.

### Diseño completo — cómo se mueve el objetivo semanal (se mantiene; vuelve después del demo)

- Todos arrancan en **objetivo semanal 1** al inicio de cada season.
- Completar la meta de la semana → sube al **siguiente objetivo** la semana
  siguiente.
- **No completarla → el objetivo se congela** (se queda igual, misma meta la
  semana siguiente). **No baja.**
- La dificultad aumenta con el objetivo — tabla a definir por Luis (L11).
- Techo real de diseño: **~13 objetivos** (una season dura 13 semanas).

### Seasons

El objetivo semanal se reinicia a 1 cada 3 meses, en fechas fijas de
calendario iguales para todos:

| Season | Arranca | Termina |
|---|---|---|
| 1 | 1 de enero | 31 de marzo |
| 2 | 1 de abril | 30 de junio |
| 3 | 1 de julio | 30 de septiembre |
| 4 | 1 de octubre | 31 de diciembre |

- Afectan **únicamente** el objetivo semanal — no tocan puntos anuales,
  cashback, ni La Liga.
- Al cerrar una season, todos vuelven a **objetivo 1**, sin importar dónde
  llegaron.
- Cada season queda en el historial del usuario, con el **objetivo máximo**
  alcanzado.
- **El reinicio ocurre el día exacto de la season** (1 de enero/abril/julio/
  octubre), sin esperar al lunes siguiente — aunque eso parta una semana
  calendario a la mitad entre dos seasons. Ningún 1° de mes de season cae
  lunes en 2026-2027, así que esto pasa siempre, no es un caso raro: no
  importa, el día exacto manda.

### Ciclos y cortes

- Ciclo semanal: **lunes 00:00 a domingo 23:59** — separado del ciclo de La Liga (día 1 al último día del mes calendario, premiada en monedas).
- **El objetivo de la semana nueva se fija de inmediato al arrancar, lunes
  00:00**, con los datos que hay hasta el corte del domingo 23:59. El usuario
  no ve ningún estado intermedio — la semana nueva ya aparece corriendo con
  normalidad desde las 00:00, sin pantalla de "evaluando" ni aviso de cambio
  de objetivo.
- El servidor sigue aceptando datos atrasados de la semana recién cerrada
  hasta el **mediodía del lunes** (período de gracia), pero esa corrida ya
  **no cambia el objetivo** que se fijó a las 00:00 — solo corrige el
  acumulado anual de puntos y el historial.
- Huso horario: **zona horaria de Guatemala**, por ahora — para el piloto
  (todo Guatemala) una sola corrida alcanza.

**Nota:** con esto, un día atrasado que llega entre las 00:00 y el mediodía
del lunes ya no puede subirle ni bajarle el objetivo a nadie — solo cuenta
para el historial y el acumulado anual. Es una simplificación deliberada: como
el objetivo ya no baja (se congela), el peor caso de decidir temprano es que
alguien no suba de objetivo esa semana aunque en realidad sí había cumplido —
no se pierde progreso acumulado, solo una semana de avance.

**Por qué esto no viaja en el JSON #2:** cambia una vez por semana (o una vez
por season), no en cada sync — incluirlo repetiría el mismo dato sin
necesidad. Daniel lo consulta por HTTP directo: `GET /api/v1/retos/estado`
(tickets L11 y D12), que también debe devolver la season actual, su fecha de
cierre, y el historial de seasons pasadas. *El path conserva el nombre viejo
"retos" — ver "Puntos abiertos".*

**Respuesta de `GET /api/v1/retos/estado` (demo 1):**

```json
{
  "objetivo": {
    "meta_pasos": 30000,
    "meta_workouts": 1,
    "monedas_al_cumplir": 20,
    "fecha_inicio": "2026-09-21",
    "fecha_fin": "2026-09-27"
  },
  "progreso": {
    "pasos_acumulados": 12400,
    "workouts_acumulados": 0,
    "cumplido": false
  },
  "season": { "numero": 3, "fecha_cierre": "2026-09-30" },
  "historial_seasons": []
}
```

`objetivo.monedas_al_cumplir` es cuántas monedas paga cumplir el objetivo de esa
semana. **[PENDIENTE]** el 20 de hoy es un valor provisional del backend:
ningún documento lo fija todavía. Las monedas respetan el tope de 100 acumuladas
y caducan a los 90 días (ver `CLAUDE.md`); lo que excede el tope se pierde.

El `objetivo` es **el mismo para todos los usuarios** esa semana; `progreso`
es del usuario que pregunta. `historial_seasons` viene vacío en el demo (no
hay objetivo máximo que registrar mientras no haya progresión).

**Cómo está construido hoy (backend, 1 oct):**

- Las metas de cada semana viven en la tabla `ObjetivoSemanal` y se editan a
  mano en el admin. Cada semana nueva copia las metas de la anterior; la
  primera arranca con 30.000 pasos y 1 workout.
- `progreso` se calcula en vivo: la suma de `pasos_totales_dia` y de workouts
  de `resumen_diario` de lunes a domingo.
- El cierre lo hace el comando `cerrar_semana`: a las **00:00 del lunes** fija
  `cumplido` de la semana que terminó y paga `monedas_al_cumplir` a quien
  cumplió; con `--correccion`, a las **12:00**, solo actualiza los acumulados
  (no cambia `cumplido` ni paga). Correrlo dos veces no paga dos veces.
  **[PENDIENTE]** nada lo programa todavía: hace falta un cron en el servidor
  para las dos corridas.
- Las monedas se ganan **con o sin póliza**; lo que exige póliza verificada es
  **gastarlas**. Respetan el tope de 100 acumuladas (lo que excede se pierde) y
  cada ganancia caduca a los 90 días.
- **[PENDIENTE]** los días anulados por retroactivo denegado (ver "Póliza
  vinculada") **sí** cuentan para el progreso de la semana en curso. Las
  monedas solo se anulan si la semana entera cerró antes de la verificación.

---

## La Liga y Tus Ligas (fuera del payload de sync)

Detalle de reglas en `reglas-puntaje-vivo.md` sección 5 — acá solo lo que
toca el contrato.

**La Liga (demo 1, temporal):**

- **Un solo grupo** con todos los usuarios con póliza vinculada y verificada.
  Sin franja de edad ni sub-ligas (diseño futuro).
- Ciclo: día 1 al último día del mes calendario. Qué cuenta: suma de
  `pasos_totales_dia` del mes (el valor ya deduplicado).
- **Premios por percentil** de la posición final: el corte de cada tramo es
  `max(1, floor(N × percentil_acumulado))`. Tramos de partida: top 3% /
  siguiente 7% (hasta 10%) / 10%–25% / "y así" (por definir). Luis calcula
  posición, percentil y tramo **una sola vez, al cierre del mes**.

**Tus Ligas:** grupos que crea o a los que se une el usuario. Ranking mensual
de pasos entre miembros, **sin premios y sin exigir póliza** (cambia el 23
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
| `encolado` | Sin red o backend caído — el día quedó en cola local, se reintenta solo al volver del background | Aviso suave, **no** como falla — el dato no se perdió |
| `sin_acceso_a_salud` | No se pudo leer HealthKit — casi siempre permisos | Guiar a Ajustes › Salud › +Vida |
| `error_permanente` | URL mal configurada o backend rechazó el payload (4xx) — no se reintenta | Usuario no puede resolverlo; registrar y reportar |

`sincronizado_en` solo viene con `estado: ok` — leer como `String?`. `detalle`
es texto técnico para logs, nunca mostrárselo crudo al usuario.

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
| `error_almacenamiento` | No se pudo escribir en el Keychain: el token no quedó guardado |

- Es **idempotente**: mandar el mismo token dos veces no cambia nada.
- **No hay forma de leer el token desde Flutter** (no existe un método para
  eso). Flutter conserva su propia copia y, al cerrar sesión, borra **las dos**.
- Swift lo guarda en el Keychain con acceso "después del primer desbloqueo"
  (`AfterFirstUnlockThisDeviceOnly`): se puede leer con el teléfono bloqueado, así
  que un envío en segundo plano sí puede firmar, y **no viaja en copias de
  seguridad ni a otro teléfono**. Servicio `com.assures.masvida.sesion`, cuenta
  `token_api`. **Nunca se escribe en logs.**

### Backfill de los últimos 7 días

Cuando `solicitarPermisos` confirma acceso, el lado nativo dispara
automáticamente el sync de los últimos 7 días, **una sola vez por
instalación** — no bloquea la respuesta de `solicitarPermisos` y no tiene un
método propio. Solo se dispara con acceso confirmado (si no, la bandera de
"ya hecho" se quemaría con cero datos guardados). Los días que fallen por red
quedan en la cola de reintentos y drenan solos al volver a primer plano.
**Si en ese momento no hay sesión, el backfill no se da por hecho** (la bandera de
"ya hecho" no se enciende). Ojo: hoy **no** se reintenta solo al iniciar sesión;
se reintenta la próxima vez que Flutter llame a `solicitarPermisos` y el acceso
siga concedido. Por eso el orden de pantallas importa: sesión primero, permisos
después (ver "Notas para Daniel").

### Wrapper

`lib/datos/healthkit_bridge.dart` expone los métodos tipados
(`EstadoPermisos`, `EstadoSync`, `TiposVisibles` y el resultado de
`actualizarSesion`). **[PENDIENTE]** hoy solo tiene `solicitarPermisos` y
`sincronizar`; falta agregar `actualizarSesion` (Alvaro). Es la **frontera del
contrato**, no UI — lo mantiene Alvaro junto con el lado Swift. Daniel lo
consume, no lo edita: si le falta algo ahí, es un cambio de contrato.

Banco de pruebas sin UI: `lib/debug/pantalla_prueba_healthkit.dart` (no
ruteado, necesita iPhone físico — HealthKit no existe en el simulador).

---

## Días sin actividad

Tres caminos mandan datos a `/api/v1/sync` y hoy no se comportan igual frente
a un día vacío:

| Camino | Día vacío |
|---|---|
| Sync de hoy | Lo manda igual |
| Cola de reintentos (A8) | Lo salta |
| Backfill de 7 días (A9) | Lo salta |

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
ventana ≥ día más viejo del backfill + holgura para reintentos
        = 6 días + 7 días de gracia
        = 13 → 14
```

| Cifra | Valor | Qué contesta |
|---|---|---|
| Ventana del servidor | 14 días | ¿Hasta qué tan viejo acepto un dato? |
| Cola de reintentos (cliente) | 14 días (**[PENDIENTE]** hoy guarda hasta 30 días pendientes, sin caducidad por antigüedad) | ¿Cuánto sigo intentando mandar un día que falló? |
| Backfill (cliente) | 7 días | ¿Cuánto historial le traigo a un usuario nuevo? |

Ventana y cola comparten cifra a propósito (si la cola fuera más corta,
tiraría días que el servidor aceptaría; más larga, reintentaría en vano). El
backfill es deliberadamente menor — necesita holgura de reintentos.

**Respuesta de rechazo**, distinguible de un payload inválido:

```
HTTP 422
{ "error": "fuera_de_ventana", "fecha": "2026-08-15" }
```

Un `4xx` genérico haría que el cliente descarte el día **y aborte el
procesamiento de los días siguientes** — con motivo identificable, descarta
ese día y sigue con el resto.

**[PENDIENTE] Lo que hace Swift hoy:** todavía no distingue el `422`. Cualquier
`4xx` que no sea `401`, `408` ni `429` (incluido el `422`) saca el día de la
cola **y corta** los días que quedaban en esa vuelta, tanto en la cola de
reintentos como en el backfill. No se pierden: en la cola, los días que
quedaban siguen ahí y salen en la siguiente vuelta; en el backfill, el backfill
no se da por hecho y se repite entero la próxima vez que se dispare.

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
Motivos: `no_existe`, `aseguradora_no_coincide`, `no_vigente`,
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
  "verificada": false,
  "motivo_rechazo": null,
  "poliza": { "policy_number": "POL-100001", "insurer": "Seguros Demo GT",
              "policy_start_date": "2026-01-15" } }
```

`poliza` es `null` si no hay póliza; `policy_start_date` es `null` hasta que la
aseguradora confirma la póliza. `verificada` es el único valor que debe usarse
para habilitar canje, cashback y La Liga.

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
- **Ventana de sync:** mismo endpoint para sync diario y backfill de 7 días —
  cada día es una llamada independiente con su propio `fecha`.
- **Ventana de aceptación (L14):** 14 días, no 3. Rechazo por antigüedad
  devuelve `422` con `{"error": "fuera_de_ventana"}`, no un `400` genérico.
- **Frontera de ciclo:** un ciclo ya cerrado (La Liga, objetivo semanal)
  es inmutable — un dato tardío dentro de la ventana de 14 días se guarda
  para historial/acumulado anual, pero nunca recalcula un ciclo ya cerrado.
- **Ráfagas de usuario nuevo:** cada usuario que concede permisos dispara 7
  POSTs seguidos en segundos (backfill). Con 50 personas del piloto entrando
  el mismo día, ~350 requests en ráfaga.
- **Un día ausente es ambiguo** — ver "Días sin actividad" arriba. Afecta la
  evaluación del objetivo semanal.
- **Cuándo se fija el objetivo semanal:** se calcula y fija a las **00:00 del
  lunes**, con los datos hasta el corte del domingo 23:59 — no espera al
  mediodía, y el usuario no ve ningún estado intermedio. Sigue existiendo una
  corrida a las **12:00 del lunes**, pero esa ya no cambia el objetivo — solo
  acepta datos atrasados para el acumulado anual y el historial. El motor de
  objetivos necesita **dos corridas programadas** (00:00 y 12:00), no un cálculo
  en vivo al cierre del domingo.
- **Objetivos semanales (L11) — implementado para el demo 1 (1 oct; ver "Cómo
  está construido hoy"). Lo que sigue vigente del ticket:** un
  objetivo **fijo e igual para todos** (meta de pasos totales de la semana +
  meta de workouts), **hardcodeado**, lunes–domingo. Cumplido = ambas
  métricas alcanzadas. Sin subir ni congelar objetivo en el demo; el
  mecanismo completo (progresión que se congela en vez de bajar, tabla de
  dificultad, historial de seasons con objetivo máximo) **queda como diseño
  para después, pero las seasons se mantienen** en el modelo y en la
  respuesta del endpoint (el reinicio ocurre el día exacto de la season). Se
  mantienen las dos corridas programadas (00:00 fija el objetivo, 12:00 solo
  corrige historial/acumulado). Un **workout** = un entrenamiento que
  cuenta (con ritmo cardíaco, no manual y sin duplicar los que dos
  dispositivos registran a la vez — ver "Qué cuenta como workout"). Si además
  debe durar 30 min o ser "intenso" por FC, es un punto abierto.
- **La Liga (demo 1):** un solo grupo con todos los usuarios con póliza
  vinculada y verificada. Al cierre del mes calcular una vez posición,
  percentil y tramo de premio de cada participante
  (`max(1, floor(N × percentil_acumulado))`) y guardarlos. Tabla de tramos y
  premios en configuración — por definir con Diego. Sin franja de edad ni
  sub-ligas (diseño futuro).
- **Tus Ligas:** grupos que crea/une el usuario; ranking mensual de pasos;
  **sin premios y sin exigir póliza**. **Duelos 1 contra 1: no construir.**
- **Endpoint de resumen para el dashboard (decidido):** tabla `resumen_diario`
  (`usuario_id` + `fecha`), upsert en cada sync con lo que el sync ya calcula
  — `pasos_totales_dia`, agregado de los workouts del día que cuentan
  (cantidad, duración total, fc_promedio, fc_maxima), `puntos_dia`. Sin lógica nueva de
  agregación. `GET /api/v1/dashboard/resumen?desde=&hasta=` devuelve el rango.
  Ver sección "Endpoint de resumen del dashboard" arriba para el shape
  completo.
- **Ledger append-only:** cada acreditación es una fila nueva con la versión
  de la regla que la generó — nunca `UPDATE` sobre una fila existente. Tipos:
  `pasos` e `intensidad` (el primer cálculo del día), `ajuste_manual` (cada
  corrección por datos tardíos, positiva o negativa; el nombre se presta a
  confusión porque también lo usa el sistema), `retroactivo_denegado` y
  `chequeo_medico` (fuera de v1).
- **Muestras borradas en HealthKit:** si la persona borra una muestra en Apple
  Salud, el servidor la conserva (solo inserta, nunca borra). El día se
  recalcula con lo guardado, así que esa muestra sigue contando.

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
- **Orden de pantallas:** primero la sesión y después `solicitarPermisos`. El
  backfill de 7 días arranca al conceder el permiso y necesita sesión.
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
- **No implementar reintentos propios** — ya corren del lado nativo cuando la
  app vuelve a primer plano.
- El **objetivo semanal** no viene en la respuesta del sync — pedirlo aparte
  con `GET /api/v1/retos/estado`. No confundirlo con `nivel` (el anual, de
  cashback) que sí viene en la respuesta del sync.
- **Objetivos semanales (D12) — demo 1:** el objetivo es **el mismo para
  todos**: meta de pasos + meta de workouts de la semana, con el progreso del
  usuario en cada una. **Sin rango, sin subir/bajar, sin congelamiento, sin
  animación de cambio de objetivo.** Mostrar en qué season está el usuario y
  cuánto falta para que cierre (las seasons se mantienen). La progresión
  completa vuelve después del demo — no construir hoy.
- **La Liga:** un solo grupo, todos los usuarios con póliza verificada,
  premios por percentil (el servidor calcula posición y tramo). Sin franjas
  de edad ni sub-ligas. **Tus Ligas:** cualquiera se une (con o sin póliza),
  sin premios. **Duelos 1 contra 1: eliminar.**
- **El objetivo de la semana se fija a las 00:00 del lunes y ya no cambia
  después** — no hace falta construir ningún estado de "evaluando" ni
  pantalla de carga especial entre domingo y lunes al mediodía.
- `dispositivo_*` (nuevo) no cambia nada del lado de Flutter — son campos que
  Swift agrega al payload de sync; Daniel no los toca ni los muestra.
- Nada de SDKs de terceros (ej. Firebase) puede tocar datos de HealthKit, ni
  indirectamente — Apple lo trata como filtración y remueve la app.

---

## Notas para Alvaro (iOS)

- **Token (30 sep):** `ApiClient` manda `Authorization: Token <clave>` en
  `POST /api/v1/sync`. El token lo entrega Flutter con `actualizarSesion`; Swift lo
  guarda en su propio Keychain (acceso "después del primer desbloqueo", solo en
  este dispositivo) y **nunca lo escribe en logs**.
- **Sin token:** no enviar. El día queda pendiente. Aplica a los tres caminos de
  envío: el sync de hoy, la cola de reintentos y el backfill.
- **`401`:** no es error permanente. El día queda pendiente y **no se corta el
  procesamiento de los demás días**. Hecho (A24).
- **`usuario_id` fuera del payload** y sin la constante `"alvaro-001"`. Hecho (A24).
- **`actualizarSesion(null)`:** borra el token del Keychain. Hecho (A24).
- **[PENDIENTE] Cola:** caducar los días con más de 14 días (hoy guarda hasta
  30, sin mirar la antigüedad) y, ante un `422`, sacar ese día y **seguir** con
  los demás (hoy cualquier `4xx` que no sea `401`/`408`/`429` corta la vuelta).
- **[PENDIENTE] Wrapper de Dart:** agregar `actualizarSesion` a
  `lib/datos/healthkit_bridge.dart`.
- **[PENDIENTE] Backfill después del login:** hoy solo se reintenta en la
  siguiente llamada a `solicitarPermisos`. Decidir si `actualizarSesion` con un
  token debe dispararlo.
- **Workouts (1 oct) — hecho:** Swift no manda una sesión si no hay ritmo
  cardíaco medido en su ventana (antes mandaba `fc_promedio`/`fc_maxima` en
  `0`), ni los workouts ingresados a mano
  (`metadata[HKMetadataKeyWasUserEntered] == true`). Ver "Qué cuenta como
  workout". Un error real al leer el ritmo cardíaco ya no se traga: falla la
  lectura del día (no se da por enviado) en vez de perder el workout en
  silencio. "Sin muestras" (`errorNoData`) sí se trata como "sin ritmo
  cardíaco", que es lo normal en un iPhone sin reloj. El servidor mantiene su
  descarte de sesiones con `fc` en `0` como red de seguridad.

---

## Puntos abiertos

*Encontrados en la revisión contra el código (1 oct):*

- **Duración mínima de un workout:** hoy un workout de cualquier duración (con
  ritmo cardíaco) suma al objetivo semanal. ¿Debe durar al menos 30 min?
- **Días anulados y objetivo semanal:** un día anulado por retroactivo denegado
  sigue contando para el progreso de la semana en curso. ¿Debe contar?
- **Programar `cerrar_semana`:** el comando existe pero nada lo corre. Hace
  falta un cron (lunes 00:00 y 12:00, hora de Guatemala) en el servidor.
- **`zona_horaria` y `app_version`:** el servidor los exige pero no los usa.
  Decidir si se usan (días en la zona del usuario, rechazar versiones viejas)
  o se dejan solo como dato.
- **Cuánto paga el objetivo semanal:** `monedas_al_cumplir` es 20 de forma
  provisional.
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
- **`VersionRegla` inicial:** sin una versión de reglas cargada, `sync` responde
  `500` y Swift reintenta los `5xx`. Hace falta cargar la versión 1 al
  desplegar (comando o fixture), no depender de que alguien la cree a mano.
- **Filas antiguas del ledger (`puntos_diarios`):** el formato viejo de una
  fila por día ya no se lee. No hay datos reales en ese formato; una base de
  pruebas vieja se vuelve a sincronizar.
- **Logout en el servidor:** hoy no existe un endpoint que borre el token. Como
  hay un token por cuenta, borrarlo cerraría la sesión en **todos** los
  dispositivos de esa persona. Mientras tanto, cerrar sesión en la app solo borra
  las copias locales (`actualizarSesion(null)`).
- **Qué estado ve Flutter cuando Swift no tiene sesión:** hoy recibe `encolado`.
  Falta decidir si se queda así o se agrega un estado nuevo (cambia el contrato).
- **Cola y backfill al cerrar sesión o entrar otra cuenta:** HealthKit pertenece
  al teléfono, no a la cuenta. Sin una regla, los días pendientes de una cuenta se
  subirían a nombre de la siguiente. Propuesta: al cerrar sesión, Swift vacía la
  cola y reinicia la bandera del backfill.
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
- **Metas hardcodeadas del objetivo semanal (demo 1):** cuántos pasos y
  cuántos workouts, y si un workout debe ser "intenso" por FC o basta con que
  exista la sesión.
- **Tramos y premios de La Liga:** porcentajes más allá de 3% / 7% / 10–25%
  y qué premio le toca a cada tramo (Diego).
- **Endpoints de La Liga y de Tus Ligas:** sin especificar.
- **Nombre del path `GET /api/v1/retos/estado`:** conserva "retos" aunque el
  concepto ya se llama objetivo semanal. Decidir con Luis si se renombra
  (p. ej. `/objetivos/estado`) antes de que Daniel lo consuma.
