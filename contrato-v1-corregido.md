# Contrato v1 — +Vida (corregido)

Este documento define cómo se comunican las tres capas del proyecto: iOS (Alvaro),
backend (Luis) y Flutter (Daniel). Una vez congelado, los tres construyen contra
este documento — no contra lo que cada quien tenga corriendo en su máquina.

Cualquier cambio de campo, tipo o forma es un **v2**, no un parche silencioso a este
archivo. Si algo no está aquí, no existe todavía.

> **Nota de esta revisión:** la versión anterior tenía 4 números tomados de la
> tabla de puntos de Vitality Ecuador en vez de las reglas propias de +Vida
> (documento "Reglas_Puntaje_vida"). Quedan corregidos abajo. También se definió
> la mecánica real de retos semanales (por nivel de dificultad, no por meta de
> puntos) y el techo anual de 12.000 puntos.

## Principio no negociable

La app de iOS **nunca** manda puntos, edad, ni frecuencia cardíaca máxima calculada.
Manda datos crudos de HealthKit — nada más. Los puntos los calcula Luis en el
servidor, con la edad que ya vive en el perfil del usuario (para sacar
**FCM = 219 − edad**).

Razón: si el teléfono pudiera mandar puntos ya calculados, cualquier iPhone
jailbreakeado se acredita lo que quiera sin que el servidor tenga cómo auditarlo.
Todo el poder de decisión vive del lado que controlamos nosotros.

---

## JSON #1 — Request: iOS → Backend

`POST /api/v1/sync`

```json
{
  "usuario_id": "alvaro-001",
  "fecha": "2026-08-19",
  "zona_horaria": "America/Guatemala",
  "pasos": [
    {
      "external_id": "uuid-de-healthkit",
      "inicio": "2026-08-19T06:00:00-06:00",
      "fin": "2026-08-19T07:00:00-06:00",
      "cantidad": 2350,
      "fuente_bundle": "com.apple.health.ABC123",
      "fuente_nombre": "Apple Watch de Alvaro",
      "fuente_version": "11.2"
    }
  ],
  "sesiones": [
    {
      "external_id": "uuid-de-healthkit",
      "inicio": "2026-08-19T17:00:00-06:00",
      "fin": "2026-08-19T17:42:00-06:00",
      "duracion_min": 42,
      "tipo_actividad": "running",
      "fc_promedio": 148,
      "fc_maxima": 165,
      "fuente_bundle": "com.apple.health.ABC123",
      "fuente_nombre": "Apple Watch de Alvaro"
    }
  ],
  "sincronizado_en": "2026-08-19T20:15:00-06:00",
  "app_version": "0.1.0"
}
```

### Campo por campo

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `usuario_id` | string | sí | id interno del usuario, no el HealthKit userID |
| `fecha` | string (YYYY-MM-DD) | sí | día calendario en la zona horaria del usuario, no en UTC |
| `zona_horaria` | string (IANA) | sí | ej. `America/Guatemala`. Define dónde cae la medianoche para el corte de la semana (lunes 00:00 a domingo 23:59) |
| `pasos[]` | array | sí (puede ir vacío) | una entrada por muestra de `HKQuantitySample` de tipo `.stepCount` |
| `pasos[].external_id` | string (UUID) | sí | el `sample.uuid` que asigna HealthKit — estable entre syncs, es la clave de idempotencia |
| `pasos[].inicio` / `.fin` | string (ISO 8601 con offset) | sí | ventana exacta de la muestra, no del día |
| `pasos[].cantidad` | int | sí | pasos en esa ventana. Nunca un total ya sumado del día — eso lo calcula el backend |
| `pasos[].fuente_bundle` | string | sí | bundle identifier de quién escribió la muestra (reloj, iPhone, Garmin, Whoop). Sostiene la jerarquía de fuentes anti-fraude |
| `pasos[].fuente_nombre` | string | sí | nombre legible de la fuente |
| `pasos[].fuente_version` | string | no | versión del software de la fuente, si HealthKit la expone |
| `sesiones[]` | array | sí (puede ir vacío) | una entrada por `HKWorkout` de ≥30 minutos continuos |
| `sesiones[].tipo_actividad` | string | sí | tipo de `HKWorkoutActivityType` en texto plano (`running`, `walking`, `cycling`, etc.) |
| `sesiones[].fc_promedio` / `.fc_maxima` | int (bpm) | sí | ritmo cardíaco durante la ventana de la sesión — no del día completo |
| `sincronizado_en` | string (ISO 8601) | sí | cuándo el teléfono armó este payload, para detectar reintentos viejos |
| `app_version` | string | sí | para poder invalidar sync de versiones viejas si cambia el contrato |

**Alcance del payload:** se manda el día completo cada vez que se sincroniza, no
solo lo nuevo desde el último sync. La idempotencia por `external_id` (ver
notas para Luis) hace seguro reenviar todo — es más simple que llevar un cursor
de "qué ya se mandó" del lado del teléfono.

**Fuera de alcance en v1:** sueño. No está en las decisiones técnicas cerradas
del proyecto (solo pasos, ritmo cardíaco y workouts) y no viaja en este contrato
aunque el spike de HealthKit lo lea en pantalla para depuración.

---

## JSON #2 — Response: Backend → iOS

Respuesta síncrona al mismo `POST /api/v1/sync`. Se mantiene mínima a propósito:
solo lo que la app necesita confirmar de inmediato tras sincronizar. Todo lo
demás (progreso semanal, nivel del reto, historial, catálogo de premios) Daniel
lo pide después por HTTP directo contra la API de Luis — no viaja por acá.

```json
{
  "fecha": "2026-08-19",
  "puntos_pasos": 50,
  "puntos_intensidad": 100,
  "puntos_dia": 150,
  "tope_diario_aplicado": false,
  "puntos_ano": 3240,
  "tope_anual_aplicado": false,
  "nivel": 1
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `puntos_pasos` | int | según la tabla de pasos: 7.000–10.000 = 25, 10.000–15.000 = 50, 15.000+ = 100. Por debajo de 7.000 pasos: 0 |
| `puntos_intensidad` | int | según la matriz de intensidad, con FCM = 219 − edad, sesión ≥30 min continuos |
| `puntos_dia` | int | suma de los dos anteriores, con el **techo diario de 200 pts** ya aplicado si corresponde |
| `tope_diario_aplicado` | bool | true si el techo de 200/día recortó el resultado — señal para la UI, no detalle de por qué |
| `puntos_ano` | int | acumulado anual, con el **techo anual de 12.000 pts** ya aplicado si corresponde |
| `tope_anual_aplicado` | bool | true si el usuario ya llegó al techo anual — a partir de ahí, actividad adicional no suma |
| `nivel` | int (0–4) | nivel numérico del esquema propio de +Vida. **Nunca** usar naming tipo Bronze/Silver/Gold/Platinum — eso es de Vitality y está prohibido en el proyecto |

No se incluye ningún campo que explique *por qué* se descartó una muestra o se
aplicó un techo. Esa lógica es del backend y no debe ser visible para el
cliente — si el teléfono supiera exactamente qué regla lo frenó, sabría
exactamente cómo evadirla la próxima vez.

**Nota sobre el techo anual de 12.000:** con el chequeo médico fuera de v1, el
máximo alcanzable solo por actividad es 12.000 puntos. Nivel 4 (15.000+) queda
fuera de alcance en el piloto — es una consecuencia aceptada y documentada, no
un bug.

---

## Mecánica de retos semanales (fuera del payload de sync, referencia para Luis y Daniel)

Confirmado: **es por nivel de dificultad progresiva, no por meta de puntos.**

- Todos los usuarios arrancan en **nivel de reto 1**.
- Si completan la meta de la semana, suben a **nivel 2** la semana siguiente.
- Si no la completan, bajan un nivel (ej. de nivel 10 a nivel 9).
- La dificultad de la meta aumenta con el nivel — no hay un número de puntos fijo
  documentado todavía para cada nivel; eso lo define Luis al construir la tabla
  de dificultad progresiva (fuera de este contrato v1, vive en el motor de
  reglas de retos).
- Este estado (nivel de reto actual, progreso de la semana) **no viaja en el
  JSON #2**. Daniel lo consulta por HTTP directo, ej. `GET /api/v1/retos/estado`.

---

## Los 2 métodos — MethodChannel (Swift ↔ Flutter)

Dart no puede leer HealthKit directamente. El puente entre el código de Daniel
(Flutter) y el código de Alvaro (Swift/HealthKit) se reduce a dos métodos — todo
lo demás (dashboard, niveles, retos, historial) es HTTP directo de Daniel contra
la API de Luis, sin pasar por código nativo.

```dart
// 1. Pide permiso de HealthKit la primera vez (o revalida si el usuario lo cambió en Ajustes)
final resultado = await canal.invokeMethod('solicitarPermisos');
// → { "concedido": true }

// 2. Lee HealthKit, arma el JSON #1, lo manda a /api/v1/sync, y devuelve el JSON #2 tal cual
final resultado = await canal.invokeMethod('sincronizar');
// → { "ok": true, "sincronizado_en": "2026-08-19T20:15:00-06:00" }
```

| Método | Entrada | Salida | Qué hace del lado nativo |
|---|---|---|---|
| `solicitarPermisos` | ninguna | `{ "concedido": bool }` | Llama `HKHealthStore.requestAuthorization` para pasos, ritmo cardíaco y workouts. `concedido` es una inferencia (HealthKit nunca confirma un permiso negado) — ver nota abajo |
| `sincronizar` | ninguna | `{ "ok": bool, "sincronizado_en": string }` | Lee HealthKit del día, arma el JSON #1, hace el POST, y si la respuesta trae el JSON #2, lo cachea localmente para que Flutter lo pida por HTTP normal en la siguiente pantalla |

**Nota para Daniel:** `concedido: true` no es una garantía fuerte. HealthKit
nunca le dice a la app si el usuario negó el permiso de lectura — solo se puede
inferir consultando y viendo si vuelve algo. Si `sincronizar` devuelve
`pasos: []` y `sesiones: []` de forma persistente, hay que asumir permiso negado
y guiar al usuario a Ajustes → Salud, no reintentar en loop.

---

## Notas para Luis (backend)

- **Idempotencia (L4):** constraint único en `(usuario_id, external_id)` para las
  tablas de pasos y sesiones. El `external_id` es el `sample.uuid` de HealthKit,
  estable entre reenvíos — un reintento de red o un día completo reenviado no
  duplica datos.
- **Nunca sumar `pasos[].cantidad` de fuentes distintas sin dedup.** Si el mismo
  rango de tiempo tiene muestras de `fuente_bundle` distintos (ej. Apple Watch y
  Whoop), aplicar la jerarquía de fuentes antes de sumar — nunca sumar crudo.
- **Techos a implementar:** diario de 200 pts (pasos + intensidad combinados) y
  anual de 12.000 pts. Ambos se reflejan en el JSON #2 con un booleano cada uno,
  sin exponer el detalle del cálculo.
- **Nivel (0–4):** numérico, esquema propio. Confirmar con Alvaro/Diego el
  mapeo exacto de rango de puntos → nivel → % de cashback antes de implementar,
  si no está ya cerrado en la nota técnica de puntaje.
- Ventana de sync: mismo endpoint para sync del día y para backfill de varios
  días atrás — el `fecha` del payload define de qué día son los datos, no hay
  endpoint separado.
- Retos semanales por nivel de dificultad (no por meta de puntos) viven en su
  propio endpoint, fuera de este contrato v1 — ver sección de retos arriba.

## Notas para Daniel (Flutter)

- Todo lo que no sea leer HealthKit va por HTTP directo contra la API de Luis —
  no hay que pedirle a Alvaro un tercer método del canal para eso, incluyendo
  el estado de los retos semanales.
- El `puntos_dia`, `puntos_ano` y `nivel` que devuelve `sincronizar` son el
  mismo shape que devolvería la API si los pidieras directo después — no hay
  dos formatos de respuesta para la misma información.
- El progreso del reto semanal (nivel de dificultad, si se completó o no) no
  viene en la respuesta del sync — pedirlo aparte por HTTP cuando se necesite
  mostrar en la pantalla de retos.
