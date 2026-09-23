---
title: Contrato técnico — estado actual (iOS ↔ Backend ↔ Flutter)
---

# Contrato técnico — +Vida

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

---

## JSON #1 — Request: iOS → Backend

`POST /api/v1/sync`

Se manda **el día completo cada vez**, no solo lo nuevo desde el último sync.
La idempotencia por `external_id` (constraint único del lado de Luis) hace
seguro reenviar todo — nunca hay que calcular un delta del lado del teléfono.

```json
{
  "usuario_id": "usr_8f3a1c2e",
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
| `usuario_id` | string | sí | id interno del usuario, no el HealthKit userID. **Hoy es un placeholder hardcodeado** — ver "Puntos abiertos" |
| `fecha` | string (YYYY-MM-DD) | sí | día calendario en la zona horaria del usuario, no en UTC |
| `zona_horaria` | string (IANA) | sí | ej. `America/Guatemala`. Define dónde cae la medianoche para el corte de la semana |
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
| `sesiones[]` | array | sí (puede ir vacío) | una entrada por `HKWorkout` de ≥30 min continuos |
| `sesiones[].external_id` | string (UUID) | sí | el `sample.uuid` del workout — clave de idempotencia |
| `sesiones[].inicio` / `.fin` | string (ISO 8601) | sí | ventana del workout |
| `sesiones[].duracion_min` | int | sí | duración en minutos |
| `sesiones[].tipo_actividad` | string, **nullable** | no | tipo de `HKWorkoutActivityType` en texto plano. **`null` es válido** — un reloj de terceros (ej. WHOOP) puede detectar el workout automáticamente pero no tener confianza suficiente para clasificarlo, y eso puede quedar sin corregir indefinidamente si el usuario nunca lo edita a mano. El backend nunca lo rechaza por venir nulo; se guarda tal cual y se muestra como "No registrado" |
| `sesiones[].fc_promedio` / `.fc_maxima` | int (bpm) | sí | FC durante la ventana de la sesión |
| `sesiones[].fuente_bundle` / `.fuente_nombre` | string | sí | mismo criterio que pasos[] |
| `sesiones[].dispositivo_nombre` / `.dispositivo_modelo` / `.dispositivo_fabricante` | string, nullable | no | **nuevo** — mismo criterio que pasos[] |
| `frecuencia_cardiaca[]` | array | sí (puede ir vacío) | una entrada por muestra `.heartRate` del día completo, esté o no dentro de un workout |
| `frecuencia_cardiaca[].external_id` | string (UUID) | sí | misma clave de idempotencia |
| `frecuencia_cardiaca[].inicio` / `.fin` | string (ISO 8601) | sí | ventana exacta |
| `frecuencia_cardiaca[].bpm` | int | sí | valor de la muestra |
| `frecuencia_cardiaca[].fuente_bundle` / `.fuente_nombre` | string | sí | mismo criterio que pasos[] |
| `frecuencia_cardiaca[].dispositivo_nombre` / `.dispositivo_modelo` / `.dispositivo_fabricante` | string, nullable | no | **nuevo** — mismo criterio que pasos[] |
| `sincronizado_en` | string (ISO 8601) | sí | cuándo el teléfono armó el payload |
| `app_version` | string | sí | para invalidar syncs de versiones viejas |

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

**Efecto directo en la precedencia de fuente (sección 7 de reglas de puntaje):**
"¿hay reloj ese día?" pasa a resolverse con `tipo_dispositivo == "reloj"`, no
con `fuente_nombre` (string libre, solo para mostrar/loggear).

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
| `puntos_pasos` | int | tabla de pasos: 7.000–10.000 = 25, 10.000–15.000 = 50, 15.000+ = 100. Debajo de 7.000: 0 |
| `puntos_intensidad` | int | matriz de intensidad, FCM = 219 − edad, sesión ≥30 min continuos al 60-70% de FCM |
| `puntos_dia` | int | suma de los dos anteriores, con el techo diario de 200 pts ya aplicado |
| `tope_diario_aplicado` | bool | true si el techo de 200/día recortó el resultado |
| `puntos_ano` | int | acumulado anual, con el techo de 12.000 ya aplicado |
| `tope_anual_aplicado` | bool | true si el usuario ya llegó al techo anual |
| `nivel` | int (0–4) | nivel **anual** de cashback (0%/5%/7,5%/10%/20%) — no confundir con el **objetivo semanal** (ver abajo) |
| `pasos_totales_dia` | int | total de pasos del día, deduplicado por fuente en el servidor (misma lógica que L9). Nunca es una suma cruda de `pasos[].cantidad` de fuentes distintas |

No incluye ningún campo que explique *por qué* se descartó una muestra, se
detectó una sesión intensa, o se aplicó un techo — esa lógica es del backend.

**Techo anual de 12.000:** con el chequeo médico fuera de v1, ese es el máximo
alcanzable solo por actividad — Nivel 4 (15.000+) queda fuera de alcance en el
piloto. Consecuencia aceptada y documentada, no un bug.

**`nivel` (anual, cashback) ≠ objetivo semanal.** Dos conceptos completamente
distintos con nombres que se prestan a confusión — por eso el reto semanal ya
no usa la palabra "nivel" en ningún lado: en código y en respuestas de API
nunca deben compartir el mismo nombre de campo.

---

## Mecánica de retos semanales (fuera del payload de sync)

Por dificultad progresiva, no por meta de puntos. **No hay rachas diarias** —
si aparecen en algún doc de pantallas, es material viejo. La progresión
numérica (1, 2, 3...) se llama **objetivo semanal** — nunca "nivel", para no
confundirla con el nivel anual de cashback del JSON #2.

### Cómo se mueve el objetivo semanal

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
  cashback, ni la liga mensual.
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

- Ciclo semanal: **lunes 00:00 a domingo 23:59** — separado del ciclo de la
  liga mensual (día 1 al último día del mes calendario, premiada en monedas).
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
cierre, y el historial de seasons pasadas.

---

## MethodChannel (Swift ↔ Flutter)

2 métodos, nada más. Todo lo que no sea leer HealthKit va por HTTP directo de
Daniel contra la API de Luis — nada de dashboard, objetivos, retos ni
historial pasa por acá.

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
| `entrenamientos` | Igual — sale del reloj o de registrar workouts a mano |

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

### Backfill de los últimos 7 días

Cuando `solicitarPermisos` confirma acceso, el lado nativo dispara
automáticamente el sync de los últimos 7 días, **una sola vez por
instalación** — no bloquea la respuesta de `solicitarPermisos`, no expone un
tercer método. Solo se dispara con acceso confirmado (si no, la bandera de
"ya hecho" se quemaría con cero datos guardados). Los días que fallen por red
quedan en la cola de reintentos y drenan solos al volver a primer plano.

### Wrapper

`lib/datos/healthkit_bridge.dart` expone los dos métodos tipados
(`EstadoPermisos`, `EstadoSync`, `TiposVisibles`). Es la **frontera del
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
| Cola de reintentos (cliente) | 14 días | ¿Cuánto sigo intentando mandar un día que falló? |
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

**Frontera de ciclo — decidido:** un ciclo ya cerrado (liga mensual u
objetivo semanal) es **inmutable**. Un dato del 29 de septiembre que llega el
10 de octubre entra igual a la base (cae dentro de los 14 días) y suma al
historial y al acumulado anual, pero **no reabre ni recalcula** la liga de
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
| `workouts_dia.cantidad` / `.duracion_total_min` | agregado de `sesiones[]` del día |
| `workouts_dia.fc_promedio` | promedio de `sesiones[].fc_promedio` del día — **no** un promedio de las 24h de `frecuencia_cardiaca[]` cruda (eso incluiría horas de reposo y no dice nada) |
| `workouts_dia.fc_maxima` | máximo de `sesiones[].fc_maxima` del día |
| `workouts_dia` | `null` si no hubo sesión ese día — no `0`, para no confundir "sin actividad intensa" con "FC de cero" |
| `puntos_dia` | mismo valor que ya viaja en el JSON #2 |

Mostrar máximo y promedio de FC por workout (no un promedio diario plano) es
también lo que justifica ante Apple el permiso de `.heartRate`: tiene que
sostener una función visible para el usuario, y un promedio de 24h mezclado
con reposo no lo hace tan bien como el máximo/promedio de la sesión.

**`GET /api/v1/dashboard/resumen?desde=&hasta=`** devuelve un array de filas
`resumen_diario` en ese rango — así arma Daniel el gráfico semanal y mensual,
sin pedir un endpoint por vista. El endpoint no fija ninguna ventana: recibe
`desde`/`hasta` y devuelve esas filas, nada más. Qué fechas calcula Daniel
para "semanal" y "mensual" (decidido: lunes–domingo alineado al objetivo
semanal, mes calendario alineado a la liga) es una decisión de UI — vive en
el dominio de pantallas, no acá.

---

## Notas para Luis (backend)

- **Idempotencia (L4):** constraint único en `(usuario_id, external_id)` para
  pasos, sesiones y frecuencia cardíaca. Reenviar una muestra ya guardada
  nunca debe duplicar una fila.
- **Nunca sumar `pasos[].cantidad` de fuentes distintas sin dedup** — ni para
  puntos ni para `pasos_totales_dia`. Jerarquía de fuentes antes de sumar,
  siempre: sistema (`com.apple.health.*`) vs. terceros (Garmin, Whoop, Zepp,
  Fitbit, etc.) al mismo nivel de confianza. **Precedencia: si hay reloj (de
  cualquier marca) con datos ese día, el reloj gana — tanto para pasos como
  para intensidad. Sin reloj ese día, gana el teléfono. Nunca se suman.** La
  decisión se re-evalúa en cada sync de esa fecha, no solo la primera vez
  (los relojes de terceros pueden sincronizar a Health con retraso).
- **Tipo de dispositivo (nuevo, confirmado 20 sep 2026) — usarlo en vez de
  `fuente_nombre` para la precedencia de arriba:** tres columnas nullable
  nuevas en `Muestra`, `MuestraBPM` y `Sesion` (`dispositivo_nombre`,
  `dispositivo_modelo`, `dispositivo_fabricante`), más una función de
  derivación de `tipo_dispositivo` (`telefono`/`reloj`/`anillo`/`desconocido`)
  que corre en el servidor con el orden descrito en la sección "Tipo de
  dispositivo" de arriba. "¿Hay reloj ese día?" pasa a resolverse comparando
  `tipo_dispositivo == "reloj"` entre las muestras del día, no comparando
  `fuente_nombre` (string libre). `desconocido` se trata como `telefono` —
  nunca se excluye la muestra. Detalle completo y por qué en
  `decision-tipo-dispositivo.md`.
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
  tiene nombre.
- **`pasos_totales_dia`** usa la misma función de deduplicación que el motor
  de puntos (L6/L9) — no es un cálculo nuevo y separado.
- **Sesión intensa sin workout (L7):** se detecta en el backend sobre
  `frecuencia_cardiaca[]` cruda. Umbral: ≥30 min continuos al 60-70% de FCM,
  FCM = 219 − edad. La edad vive en el servidor, nunca la manda el teléfono.
- **Techos:** diario 200 pts (pasos + intensidad), anual 12.000 pts.
- **Nivel anual (0–4):** confirmar con Alvaro/Diego el mapeo exacto puntos →
  nivel → % cashback si no está cerrado en la nota técnica de puntaje.
- **Ventana de sync:** mismo endpoint para sync diario y backfill de 7 días —
  cada día es una llamada independiente con su propio `fecha`.
- **Ventana de aceptación (L14):** 14 días, no 3. Rechazo por antigüedad
  devuelve `422` con `{"error": "fuera_de_ventana"}`, no un `400` genérico.
- **Frontera de ciclo:** un ciclo ya cerrado (liga mensual, objetivo semanal)
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
  retos necesita **dos corridas programadas** (00:00 y 12:00), no un cálculo
  en vivo al cierre del domingo.
- **Retos (L11) — reescribir el ticket, no solo ampliarlo:** objetivo semanal
  que se congela en vez de bajar; seasons trimestrales en fechas fijas (el
  reinicio a objetivo 1 ocurre el día exacto de la season, sin esperar al
  lunes siguiente, aunque parta una semana a la mitad); historial de seasons
  con objetivo máximo alcanzado por season; y las dos corridas programadas
  (00:00 fija el objetivo, 12:00 solo corrige historial/acumulado).
- **Endpoint de resumen para el dashboard (decidido):** tabla `resumen_diario`
  (`usuario_id` + `fecha`), upsert en cada sync con lo que el sync ya calcula
  — `pasos_totales_dia`, agregado de `sesiones[]` del día (cantidad, duración
  total, fc_promedio, fc_maxima), `puntos_dia`. Sin lógica nueva de
  agregación. `GET /api/v1/dashboard/resumen?desde=&hasta=` devuelve el rango.
  Ver sección "Endpoint de resumen del dashboard" arriba para el shape
  completo.
- **Ledger append-only:** cada acreditación es una fila nueva con la versión
  de la regla que la generó — nunca `UPDATE` sobre una fila existente.

## Notas para Daniel (Flutter)

- Todo lo que no sea leer HealthKit va por HTTP directo contra la API de
  Luis — el MethodChannel es solo `solicitarPermisos` y `sincronizar`.
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
  tiene nombre de actividad.
- `encolado` **no** es una falla — el dato quedó a salvo y se reintenta solo.
- **No implementar reintentos propios** — ya corren del lado nativo cuando la
  app vuelve a primer plano.
- El **objetivo semanal** no viene en la respuesta del sync — pedirlo aparte
  con `GET /api/v1/retos/estado`. No confundirlo con `nivel` (el anual, de
  cashback) que sí viene en la respuesta del sync.
- **Retos (D12):** sin animación de "bajaste de objetivo" — ahora se congela.
  Mostrar en qué season está el usuario y cuánto falta para que cierre. Hay
  historial de seasons pasadas con objetivo máximo alcanzado (material para
  una pantalla de logros, si se quiere).
- **El objetivo de la semana se fija a las 00:00 del lunes y ya no cambia
  después** — no hace falta construir ningún estado de "evaluando" ni
  pantalla de carga especial entre domingo y lunes al mediodía.
- `dispositivo_*` (nuevo) no cambia nada del lado de Flutter — son campos que
  Swift agrega al payload de sync; Daniel no los toca ni los muestra.
- Nada de SDKs de terceros (ej. Firebase) puede tocar datos de HealthKit, ni
  indirectamente — Apple lo trata como filtración y remueve la app.

---

## Puntos abiertos

- **`usuario_id` sigue siendo un placeholder hardcodeado** — el login real
  (L10/D6) todavía no existe. Falta definir si los datos del piloto temprano
  se migran, se descartan, o si el login llega antes de que importe.
- **Días vacíos:** emparejar los tres caminos de envío frente a un día sin
  actividad (ver "Días sin actividad").
- **Tipo de dispositivo:** Alvaro confirmó su parte (Swift) el 20 sep; falta
  que Luis confirme la regla `desconocido → telefono` y agregue las tres
  columnas + la función de derivación antes de dar esto por cerrado. Ver
  "Puntos abiertos" en `decision-tipo-dispositivo.md`.
