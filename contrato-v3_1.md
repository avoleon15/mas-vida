# Contrato v3 — +Vida

Este documento define cómo se comunican las tres capas del proyecto: iOS (Alvaro),
backend (Luis) y Flutter (Daniel). Una vez congelado, los tres construyen contra
este documento — no contra lo que cada quien tenga corriendo en su máquina.

Cualquier cambio de campo, tipo o forma es un **v4**, no un parche silencioso a este
archivo. Si algo no está aquí, no existe todavía. Este documento es autocontenido:
no hace falta abrir `contrato-v2.md` ni `contrato-v1.md` para nada de lo que sigue.

> **Qué cambió de v2 a v3 (3 sep 2026):** se agrega `pasos_totales_dia` al JSON #2
> (respuesta) — el total de pasos del día, ya deduplicado por fuente del lado del
> servidor. Motivo: el dashboard de Daniel (D8) necesita mostrar "pasos de hoy", y
> ese número **no puede salir de una suma cruda en el teléfono** — el propio spike
> de HealthKit de Alvaro ya demostró que un mismo día puede tener pasos superpuestos
> reportados por dos fuentes distintas (ej. Apple Watch/reloj + iPhone), así que
> sumar sin deduplicar infla el número. Luis calcula este total con la misma lógica
> de deduplicación de fuentes que ya usa para los puntos (L9) — el usuario ve
> siempre el mismo número que generó sus puntos, nunca uno inflado.
>
> Se evaluó y se descartó agregar `fc_promedio_dia` (promedio de frecuencia cardíaca
> del día) a la misma respuesta — no es necesario por ahora, se puede reabrir en un
> v4 si hace falta más adelante. También se evaluó y se confirmó que los niveles de
> reto semanal siguen sin viajar en el sync — quedan en su propio endpoint separado
> (ver la sección de retos más abajo).
>
> **Qué cambió de v1 a v2 (30 ago 2026):** se agregó el array `frecuencia_cardiaca[]`
> al JSON #1, con el ritmo cardíaco crudo del día completo — no solo el que ya viaja
> dentro de `sesiones[]` cuando hay un workout. Motivo: detectar sesiones intensas en
> usuarios que nunca activan un workout en el reloj, sin romper el principio de que
> el teléfono nunca manda una conclusión ya calculada — el análisis de "¿hubo sesión
> intensa?" vive en el backend (L7), corriendo sobre este dato crudo.
>
> **Qué se corrigió de la versión original a v1:** la versión original tenía 4 números
> tomados de la tabla de puntos de Vitality Ecuador en vez de las reglas propias de
> +Vida (documento "Reglas_Puntaje_vida"). También se definió la mecánica real de
> retos semanales (por nivel de dificultad, no por meta de puntos) y el techo anual
> de 12.000 puntos.

## Principio no negociable

La app de iOS **nunca** manda puntos, edad, ni frecuencia cardíaca máxima calculada,
ni conclusiones derivadas (como "hubo sesión intensa"). Manda datos crudos de
HealthKit — nada más. Los puntos, las sesiones intensas sin workout, y el total de
pasos deduplicado, los calcula Luis en el servidor.

Razón: si el teléfono pudiera mandar puntos o conclusiones ya calculadas, cualquier
iPhone jailbreakeado se acredita lo que quiera sin que el servidor tenga cómo
auditarlo. Todo el poder de decisión vive del lado que controlamos nosotros.

---

## JSON #1 — Request: iOS → Backend

`POST /api/v1/sync`

Se manda **el día completo cada vez**, no solo lo nuevo desde el último sync. La
idempotencia por `external_id` (constraint único del lado de Luis) hace seguro
reenviar todo — nunca hay que calcular un delta del lado del teléfono.

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
      "fuente_version": "18.0"
    },
    {
      "external_id": "9A1B2C3D-4E5F-4061-8A2B-3C4D5E6F7081",
      "inicio": "2026-09-03T07:12:00-06:00",
      "fin": "2026-09-03T07:19:00-06:00",
      "cantidad": 430,
      "fuente_bundle": "com.huami.watch.gt",
      "fuente_nombre": "Zepp",
      "fuente_version": "9.2.1"
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
      "fuente_nombre": "Apple Watch"
    }
  ],
  "frecuencia_cardiaca": [
    {
      "external_id": "7E8F9012-3456-4A7B-8C9D-0E1F20314253",
      "inicio": "2026-09-03T06:30:00-06:00",
      "fin": "2026-09-03T06:31:00-06:00",
      "bpm": 140,
      "fuente_bundle": "com.apple.health",
      "fuente_nombre": "Apple Watch"
    }
  ],
  "sincronizado_en": "2026-09-03T20:15:00-06:00",
  "app_version": "1.0.0"
}
```

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `usuario_id` | string | sí | id interno del usuario, no el HealthKit userID |
| `fecha` | string (YYYY-MM-DD) | sí | día calendario en la zona horaria del usuario, no en UTC |
| `zona_horaria` | string (IANA) | sí | ej. `America/Guatemala`. Define dónde cae la medianoche para el corte de la semana |
| `pasos[]` | array | sí (puede ir vacío) | una entrada por muestra de `HKQuantitySample` de tipo `.stepCount` |
| `pasos[].external_id` | string (UUID) | sí | el `sample.uuid` de HealthKit — clave de idempotencia |
| `pasos[].inicio` / `.fin` | string (ISO 8601 con offset) | sí | ventana exacta de la muestra |
| `pasos[].cantidad` | int | sí | pasos en esa ventana, nunca un total ya sumado |
| `pasos[].fuente_bundle` | string | sí | bundle identifier de la fuente |
| `pasos[].fuente_nombre` | string | sí | nombre legible de la fuente |
| `pasos[].fuente_version` | string | no | versión del software de la fuente |
| `sesiones[]` | array | sí (puede ir vacío) | una entrada por `HKWorkout` de ≥30 min continuos |
| `sesiones[].external_id` | string (UUID) | sí | el `sample.uuid` del workout — clave de idempotencia |
| `sesiones[].inicio` / `.fin` | string (ISO 8601) | sí | ventana del workout |
| `sesiones[].duracion_min` | int | sí | duración en minutos |
| `sesiones[].tipo_actividad` | string | sí | tipo de `HKWorkoutActivityType` en texto plano |
| `sesiones[].fc_promedio` / `.fc_maxima` | int (bpm) | sí | FC durante la ventana de la sesión |
| `sesiones[].fuente_bundle` / `.fuente_nombre` | string | sí | mismo criterio que pasos[] |
| `frecuencia_cardiaca[]` | array | sí (puede ir vacío) | una entrada por muestra `.heartRate` del día completo, esté o no dentro de un workout |
| `frecuencia_cardiaca[].external_id` | string (UUID) | sí | misma clave de idempotencia |
| `frecuencia_cardiaca[].inicio` / `.fin` | string (ISO 8601) | sí | ventana exacta |
| `frecuencia_cardiaca[].bpm` | int | sí | valor de la muestra |
| `frecuencia_cardiaca[].fuente_bundle` / `.fuente_nombre` | string | sí | mismo criterio que pasos[] |
| `sincronizado_en` | string (ISO 8601) | sí | cuándo el teléfono armó el payload |
| `app_version` | string | sí | para invalidar syncs de versiones viejas |

**Alcance del payload:** se manda el día completo cada vez, no solo lo nuevo —
idempotencia por `external_id` hace seguro reenviar todo.

**Fuera de alcance en v3:** sueño.

---

## JSON #2 — Response: Backend → iOS

Respuesta síncrona al mismo `POST /api/v1/sync`. Se mantiene mínima a propósito:
solo lo que la app necesita confirmar de inmediato tras sincronizar. Todo lo
demás (nivel de reto semanal, historial, catálogo de premios) Daniel lo pide
después por HTTP directo contra la API de Luis — no viaja por acá.

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
| `fecha` | string (YYYY-MM-DD) | eco del día que se sincronizó, mismo formato que el request |
| `puntos_pasos` | int | según la tabla de pasos: 7.000–10.000 = 25, 10.000–15.000 = 50, 15.000+ = 100. Por debajo de 7.000 pasos: 0 |
| `puntos_intensidad` | int | según la matriz de intensidad, con FCM = 219 − edad, sesión ≥30 min continuos al 60-70% de FCM |
| `puntos_dia` | int | suma de los dos anteriores, con el techo diario de 200 pts ya aplicado si corresponde |
| `tope_diario_aplicado` | bool | true si el techo de 200/día recortó el resultado |
| `puntos_ano` | int | acumulado anual, con el techo anual de 12.000 pts ya aplicado si corresponde |
| `tope_anual_aplicado` | bool | true si el usuario ya llegó al techo anual |
| `nivel` | int (0–4) | nivel **anual** de +Vida, calculado sobre `puntos_ano` — determina el % de cashback (0%/5%/7,5%/10%/20%). Numérico, nunca Bronze/Silver/Gold/Platinum |
| `pasos_totales_dia` | int | total de pasos del día calendario que manda `fecha`, ya deduplicado por fuente (misma lógica que L9 usa para puntos). Nunca es una suma cruda de `pasos[].cantidad` de fuentes distintas — eso doble-cuenta cuando hay más de una fuente activa el mismo día (ej. reloj + iPhone) |

No se incluye ningún campo que explique *por qué* se descartó una muestra, se
detectó (o no) una sesión intensa sin workout, o se aplicó un techo. Esa lógica
es del backend y no debe ser visible para el cliente.

**Nota sobre el techo anual de 12.000:** con el chequeo médico fuera de v1, el
máximo alcanzable solo por actividad es 12.000 puntos. Nivel 4 (15.000+) queda
fuera de alcance en el piloto — es una consecuencia aceptada y documentada, no
un bug.

**Nota importante — no confundir `nivel` con el nivel de reto semanal:** `nivel`
en este JSON es el nivel anual (0–4, cashback). El nivel de reto semanal (1, 2,
3... dificultad progresiva) es un concepto totalmente distinto, con su propio
ciclo (lunes a domingo) y su propio endpoint — ver sección de retos abajo. Que
los dos se llamen "nivel" en la conversación del día a día es una fuente fácil
de confusión; en el código y en las respuestas de la API nunca deben compartir
el mismo nombre de campo.

---

## Mecánica de retos semanales (fuera del payload de sync)

Se evaluó explícitamente en v3 si debía moverse al JSON de sync y se decidió
que no — se mantiene en su propio endpoint separado (detalle abajo).

Confirmado: **es por nivel de dificultad progresiva, no por meta de puntos.**

- Todos los usuarios arrancan en **nivel de reto 1**.
- Si completan la meta de la semana, suben a **nivel 2** la semana siguiente.
- Si no la completan, bajan un nivel.
- La dificultad de la meta aumenta con el nivel — Luis define la tabla de
  dificultad progresiva al construir el motor de reglas de retos (L11).
- El ciclo corre de **lunes 00:00 a domingo 23:59** — separado del ciclo de la
  liga mensual (día 1 al último día del mes calendario), que corre en paralelo
  y premia en monedas.

**Por qué no viaja en el JSON #2:** el nivel de reto cambia una sola vez por
semana, en el corte de lunes 00:00 — no como consecuencia de cada sync
individual. Incluirlo en cada respuesta de `/api/v1/sync` repetiría el mismo
dato sin necesidad, en contra del principio de mantener la respuesta mínima.

Daniel lo consulta por HTTP directo, ej. `GET /api/v1/retos/estado` — ver
tickets **L11 · Retos semanales** (Luis) y **D12 · Retos: selección y
progreso** (Daniel), que ya asumen este endpoint separado.

---

## Los 2 métodos — MethodChannel (Swift ↔ Flutter)

Todo lo que no sea leer HealthKit va por HTTP directo de Daniel contra la API
de Luis. El puente nativo se reduce a estos 2 métodos — nada de dashboard,
niveles, retos ni historial pasa por acá.

```dart
// 1. Pide permiso de HealthKit la primera vez (o revalida si el usuario lo cambió en Ajustes)
final resultado = await canal.invokeMethod('solicitarPermisos');
// → { "concedido": true }

// 2. Lee HealthKit, arma el JSON #1, lo manda a /api/v1/sync, y devuelve el JSON #2 tal cual
final resultado = await canal.invokeMethod('sincronizar');
// → { "ok": true, "sincronizado_en": "2026-09-03T20:15:00-06:00" }
```

| Método | Entrada | Salida | Qué hace del lado nativo |
|---|---|---|---|
| `solicitarPermisos` | ninguna | `{ "concedido": bool }` | Llama `HKHealthStore.requestAuthorization`. `concedido` es una inferencia — HealthKit nunca confirma un permiso negado |
| `sincronizar` | ninguna | `{ "ok": bool, "sincronizado_en": string }` | Lee HealthKit del día, arma el JSON #1, hace el POST, y si la respuesta trae el JSON #2 (incluido `pasos_totales_dia`), lo cachea localmente para que Flutter lo pida por HTTP normal en la siguiente pantalla |

**Nota para Daniel:** `concedido: true` no es una garantía fuerte. Si
`sincronizar` devuelve arrays vacíos de forma persistente, asumir permiso
negado y guiar al usuario a Ajustes → Salud, no reintentar en loop.

**Nota para el dashboard (D8):** usar `pasos_totales_dia` de la respuesta del
sync para mostrar "pasos de hoy" — no hay que pedirlo aparte, y no hay que
calcularlo del lado de Flutter (no tiene acceso a HealthKit de todas formas).

---

## Notas para Luis (backend)

- **Idempotencia (L4):** constraint único en `(usuario_id, external_id)` para
  pasos, sesiones y frecuencia cardíaca. El sync manda el día completo cada
  vez — reenviar una muestra ya guardada nunca debe duplicar una fila.
- **Nunca sumar `pasos[].cantidad` de fuentes distintas sin dedup** — ni para
  puntos ni para `pasos_totales_dia`. Aplicar la jerarquía de fuentes antes de
  sumar, siempre: fuentes de sistema (`com.apple.health.*`) vs. todas las de
  terceros (Garmin, Whoop, Zepp, Fitbit, etc.) al mismo nivel de confianza,
  sin favorecer ninguna marca. Regla de precedencia: si hay actividad intensa
  y reloj disponible, el reloj tiene prioridad; si es solo pasos (o no hay
  reloj), gana la fuente que reporte más pasos ese día.
- **`pasos_totales_dia`** se calcula con la misma función de deduplicación que
  ya usa el motor de puntos (L6/L9) — no es un cálculo nuevo y separado, es
  sumar el resultado ya deduplicado de esa misma lógica. Si L9 todavía no está
  listo cuando se implemente esto, `pasos_totales_dia` va a estar inflado
  igual que los puntos estarían — es la misma dependencia, no una nueva.
- **Sesión intensa sin workout (L7):** se detecta en el backend corriendo
  sobre `frecuencia_cardiaca[]` cruda — el teléfono nunca manda esa
  conclusión ya calculada. Umbral: ≥30 min continuos al 60-70% de FCM, con
  FCM = 219 − edad. La edad vive en el servidor, nunca la manda el teléfono.
- **Techos:** diario 200 pts (pasos + intensidad sumados), anual 12.000 pts.
- **Nivel (0–4):** confirmar con Alvaro/Diego el mapeo exacto de rango de
  puntos → nivel → % de cashback si no está ya cerrado en la nota técnica de
  puntaje (0–2.500 → 0%, 2.500–5.000 → 5%, 5.000–10.000 → 7,5%,
  10.000–15.000 → 10%, 15.000+ → 20%).
- **Ventana de sync:** mismo endpoint `POST /api/v1/sync` para el sync diario
  y para el backfill de los últimos 7 días — cada día se manda como una
  llamada independiente con su propio `fecha`.
- **Retos semanales:** endpoint separado, `GET /api/v1/retos/estado` — ver
  sección de retos arriba. No confundir el nivel de reto con `nivel` (el
  anual) del JSON #2.
- **Ledger append-only:** cada acreditación de puntos es una fila nueva con la
  versión de la regla que la generó — nunca un `UPDATE` sobre una fila
  existente.

## Notas para Daniel (Flutter)

- Todo lo que no sea leer HealthKit va por HTTP directo contra la API de
  Luis — el MethodChannel es solo `solicitarPermisos` y `sincronizar`.
- `pasos_totales_dia` ya viene en la respuesta de `sincronizar()` — úsalo
  directo para D8, no hace falta pedirlo aparte ni calcularlo en Flutter.
- El nivel de reto semanal (D12) sigue sin venir en la respuesta del sync —
  pedirlo aparte con `GET /api/v1/retos/estado` cuando se necesite mostrar en
  la pantalla de retos. No lo confundas con `nivel` (el anual, de cashback)
  que sí viene en la respuesta del sync.
- `concedido: true` de `solicitarPermisos` no es garantía de datos reales —
  ver nota arriba en la sección del MethodChannel.
- Nada de SDKs de terceros (ej. Firebase) puede tocar datos que vengan de
  HealthKit, ni siquiera indirectamente — Apple lo trata como filtración y
  causa remoción inmediata de la app.
