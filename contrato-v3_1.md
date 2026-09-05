# Contrato v3 — +Vida

Este documento define cómo se comunican las tres capas del proyecto: iOS (Alvaro),
backend (Luis) y Flutter (Daniel). Una vez congelado, los tres construyen contra
este documento — no contra lo que cada quien tenga corriendo en su máquina.

Cualquier cambio de campo, tipo o forma es un **v4**, no un parche silencioso a este
archivo. Si algo no está aquí, no existe todavía. Este documento es autocontenido:
no hace falta abrir `contrato-v2.md` ni `contrato-v1.md` para nada de lo que sigue.

> **Qué cambió de v3.1 a v3.2 (5 sep 2026):** cambian **las dos respuestas del
> MethodChannel** (Swift ↔ Flutter). El JSON #1 y el JSON #2 — o sea todo lo que
> Luis recibe y devuelve — **no cambian en absolutamente nada**. Por eso esto es un
> v3.2 y no un v4: el contrato con el backend está intacto, lo que se movió es el
> puente interno de la app iOS.
>
> 1. **`solicitarPermisos` ahora devuelve `estado`, no solo `concedido`.** El
>    `concedido: true` anterior era una afirmación que la app no podía sostener:
>    `requestAuthorization` de HealthKit termina sin error aunque el usuario haya
>    negado todo, así que "se mostró el diálogo" se estaba reportando como "hay
>    acceso". Ahora el lado nativo hace una consulta de sondeo y distingue tres
>    situaciones, una de ellas explícitamente ambigua.
> 2. **`sincronizar` ahora devuelve `estado`, no solo `ok`.** El `ok: false`
>    anterior aplastaba tres situaciones que el usuario resuelve de forma
>    distinta: sin red (se reintenta solo, no hay nada que hacer), sin permisos
>    (hay que ir a Ajustes) y error de configuración (no lo puede resolver nadie
>    más que nosotros).
> 3. **El backfill de los últimos 7 días ahora se dispara de verdad.** Existía y
>    estaba probado (A9), pero no lo llamaba nadie: un usuario nuevo entraba con
>    cero historial. Ahora corre automáticamente cuando se confirma el acceso a
>    HealthKit, sin `await`, para no colgar la respuesta del permiso.
>
> Efecto para Luis: el contrato no cambia, pero sí el **patrón de tráfico** y el
> **significado de un día ausente** — ver "Notas para Luis" y "Puntos abiertos".
>
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

**Sin cambios en v3.2.**

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

**Nuevo en v3.2 — cuándo NO se manda un día:** dos de los tres caminos de envío
saltan los días completamente vacíos (ver "Días sin actividad" más abajo). Luis
puede recibir menos filas de las que esperaría si asume un registro por día
calendario.

---

## JSON #2 — Response: Backend → iOS

**Sin cambios en v3.2.**

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

**No hay rachas diarias.** La consistencia se premia exclusivamente por este
mecanismo — mantenerse en un nivel alto exige cumplir semana tras semana, y
fallar una semana baja el nivel y con él el acceso a las recompensas mayores. Si
aparece una "racha" o unos "escudos" en algún documento de pantallas, es material
viejo: el documento de Reglas de Puntaje nunca los tuvo.

- Todos los usuarios arrancan en **nivel de reto 1**.
- Si completan la meta de la semana, suben a **nivel 2** la semana siguiente.
- Si no la completan, bajan un nivel.
- La dificultad de la meta aumenta con el nivel — Luis define la tabla de
  dificultad progresiva al construir el motor de reglas de retos (L11).
- El ciclo corre de **lunes 00:00 a domingo 23:59** — separado del ciclo de la
  liga mensual (día 1 al último día del mes calendario), que corre en paralelo
  y premia en monedas.
- **La semana cierra el domingo 23:59, pero se evalúa el lunes a las 12:00**
  (decidido el 5 sep 2026). Esas 12 horas son un período de gracia para que
  lleguen los syncs atrasados: un día de la semana ya cerrada que aterrice antes
  del mediodía del lunes todavía cuenta para el reto.
- **Después del mediodía del lunes, un día atrasado ya no mueve el reto de esa
  semana** — pero sí sigue sumando al acumulado anual de puntos y al historial.
  Los datos tardíos nunca se descartan; solo dejan de poder cambiar un reto ya
  evaluado.

**Tres cosas que hay que definir junto con esto:**

- **Qué ve el usuario entre el domingo 23:59 y el lunes 12:00.** Si la app
  muestra el resultado provisional y después cambia al mediodía, se reproduce en
  chico el problema que el período de gracia venía a evitar. Lo sano es mostrar
  "semana en evaluación" y no anunciar ningún cambio de nivel hasta que sea
  definitivo.
- **La semana nueva arranca antes de que se evalúe la vieja.** El lunes 00:00 ya
  empieza a acumular actividad, pero el nivel —y por lo tanto la dificultad de la
  meta— no se conoce hasta el mediodía. Hay que decidir si la meta de la semana
  nueva se fija al mediodía del lunes (12 horas a ciegas) o si el reto nuevo
  directamente arranca ahí.
- **En qué huso horario es ese mediodía.** El JSON #1 manda `zona_horaria` por
  usuario y el corte de la semana es local. Para el piloto (todo Guatemala) una
  sola corrida del servidor alcanza, pero la regla hay que escribirla igual.

**Por qué no viaja en el JSON #2:** el nivel de reto cambia una sola vez por
semana, en el corte de lunes 00:00 — no como consecuencia de cada sync
individual. Incluirlo en cada respuesta de `/api/v1/sync` repetiría el mismo
dato sin necesidad, en contra del principio de mantener la respuesta mínima.

Daniel lo consulta por HTTP directo, ej. `GET /api/v1/retos/estado` — ver
tickets **L11 · Retos semanales** (Luis) y **D12 · Retos: selección y
progreso** (Daniel), que ya asumen este endpoint separado.

---

## Los 2 métodos — MethodChannel (Swift ↔ Flutter)

> **Cambiado en v3.2.** Los nombres de los métodos y sus entradas (ninguna) no
> cambian. Lo que cambia son **las dos respuestas**, que ahora traen un campo
> `estado`. Esto no toca a Luis en nada.

Todo lo que no sea leer HealthKit va por HTTP directo de Daniel contra la API
de Luis. El puente nativo se reduce a estos 2 métodos — nada de dashboard,
niveles, retos ni historial pasa por acá.

```dart
// 1. Pide permiso de HealthKit la primera vez (o revalida si el usuario lo cambió en Ajustes)
final resultado = await canal.invokeMethod('solicitarPermisos');
// → { "concedido": true, "estado": "concedido" }

// 2. Lee HealthKit, arma el JSON #1 y lo manda a /api/v1/sync
final resultado = await canal.invokeMethod('sincronizar');
// → { "ok": true, "estado": "ok", "sincronizado_en": "2026-09-05T20:15:00-06:00" }
```

### `solicitarPermisos`

Entrada: ninguna. Salida: `{ "concedido": bool, "estado": string, "detalle": string? }`

| `estado` | `concedido` | Qué significa | Qué debe hacer Flutter |
|---|---|---|---|
| `concedido` | `true` | Se vieron datos reales de HealthKit. Hay acceso, sin ambigüedad | Seguir el flujo normal |
| `sin_datos_visibles` | `false` | No se vio ningún dato en 30 días. Puede ser permiso negado **o** un usuario real sin actividad registrada — HealthKit no permite distinguirlos | Mensaje del tipo "No vemos datos de actividad. Si negaste el acceso, activalo en Ajustes › Salud › +Vida". **Nunca** un "listo" ni un "permiso denegado" categórico |
| `no_disponible` | `false` | El dispositivo no soporta HealthKit (iPad, simulador) | Ocultar la función |

Si falla la solicitud en sí, llega como `FlutterError` con código `PERMISOS_ERROR`
— no como un `estado`.

**Por qué cambió:** `HKHealthStore.requestAuthorization` termina **sin error**
aunque el usuario haya negado todos los permisos — HealthKit nunca informa un
permiso de lectura negado. El `concedido: true` de v3.1 solo significaba "se
mostró el diálogo", así que la app le decía "listo" a alguien que había negado
todo y después nunca sincronizaba nada sin explicación. Ahora el lado nativo
hace una consulta de sondeo (pasos, 30 días, `limit: 1`) y reporta lo que
realmente puede ver.

### `sincronizar`

Entrada: ninguna. Salida: `{ "ok": bool, "estado": string, "sincronizado_en": string?, "detalle": string? }`

| `estado` | `ok` | Qué significa | Qué debe hacer Flutter |
|---|---|---|---|
| `ok` | `true` | Llegó a Luis y quedó guardado. `sincronizado_en` viene con el timestamp ISO 8601 | Confirmación normal |
| `encolado` | `false` | Sin red o backend caído. El día quedó en la cola local y se reintenta solo al volver del background (A8) | Aviso suave. **No** presentarlo como falla — el dato no se perdió |
| `sin_acceso_a_salud` | `false` | No se pudo leer HealthKit. Casi siempre permisos | Guiar a Ajustes › Salud › +Vida |
| `error_permanente` | `false` | URL mal configurada, o el backend rechazó el payload (4xx). No se reintenta | El usuario no puede resolverlo; registrar y reportar |

- `sincronizado_en` **solo viene cuando `ok` es `true`.** En v3.1 llegaba como
  string vacío en los fallos; ahora directamente no está en la respuesta.
  Leerlo como `String?`, no como `String`.
- `detalle` es texto técnico para logs. No mostrárselo crudo al usuario — el
  texto para él sale de `estado`.

**Por qué cambió:** `ok: false` aplastaba tres situaciones que el usuario
resuelve de forma completamente distinta. "Se reintenta solo" y "andá a
Ajustes" son mensajes opuestos, y Flutter no tenía con qué distinguirlos.

### Wrapper de Dart

`lib/datos/healthkit_bridge.dart` ya expone los dos métodos tipados, con
`EstadoPermisos` y `EstadoSync` como enums de Dart. Usándolo no hace falta
parsear strings a mano, y los estados desconocidos caen en un caso
`desconocido` en vez de romper.

### Backfill de los últimos 7 días

Nuevo en v3.2: cuando `solicitarPermisos` confirma acceso (`estado: concedido`),
el lado nativo dispara automáticamente la sincronización de los últimos 7 días,
**una sola vez por instalación**. No expone un tercer método — el contrato sigue
siendo de 2.

- No bloquea la respuesta de `solicitarPermisos`: son hasta 7 días × red, y
  Flutter no puede quedarse colgado esperando eso.
- Solo se dispara con acceso confirmado. Con permiso negado los 7 días saldrían
  vacíos, Luis respondería 200 a todos, y la bandera de "backfill ya hecho" se
  quemaría para siempre con cero datos guardados.
- Los días que fallen por red quedan en la cola de reintentos (A8) y drenan
  solos al volver del background.

---

## Días sin actividad — qué significa un día ausente

> **Nuevo en v3.2. Decisión pendiente con Luis.**

Hay tres caminos que mandan datos a `/api/v1/sync`, y hoy no se comportan igual
frente a un día completamente vacío (sin pasos, sin sesiones, sin FC):

| Camino | Día vacío |
|---|---|
| Sync de hoy (`sincronizar`) | **Lo manda igual** |
| Cola de reintentos (A8) | Lo salta |
| Backfill de 7 días (A9) | Lo salta |

Los dos últimos lo saltan por una razón concreta: un payload vacío puede ser un
día sin actividad, pero también un permiso de HealthKit denegado — y HealthKit
devuelve arrays vacíos en los dos casos, sin forma de distinguirlos. Mandarlo
haría que Luis lo dé por entregado con cero datos y ese día no se volviera a
mandar nunca.

**La consecuencia para el backend:** un día ausente en la base es ambiguo. Puede
ser "el usuario no se movió" o "el teléfono nunca sincronizó ese día".

Donde eso pega es en la **evaluación del reto semanal**. Para decidir si alguien
cumplió su meta de la semana, Luis suma los días de esa semana. Un día ausente
puede ser un cero que cuenta, o un día que todavía no llegó y que podría cambiar
el resultado. Y el ciclo semanal tiene un **corte duro** (domingo 23:59): si al
evaluar falta un día que termina llegando el martes, se degrada de nivel a
alguien que sí había cumplido — y una bajada de nivel es un evento visible para
el usuario, mucho más feo de revertir que un contador interno.

> +Vida **no tiene rachas diarias**: la consistencia se premia con los niveles de
> reto semanal, no con días consecutivos (ver la sección de retos). Eso hace que
> este problema ocurra **menos veces** —un día atrasado que llega antes del
> domingo no hace ningún daño— pero que **cueste más caro** cuando ocurre.

**Qué hay que decidir (Alvaro + Luis):** son dos cosas, no una.

1. **Emparejar los tres caminos.** Mandar siempre el día aunque esté vacío (y que
   Luis distinga "vacío" de "ausente"), o no mandarlo nunca (y que trate la
   ausencia como "sin datos", no como "cero"). Lo que no puede quedar es la
   inconsistencia actual.
2. **Cuándo se cierra la semana — DECIDIDO (5 sep 2026).** Cierra el domingo
   23:59 y se evalúa el **lunes 12:00**; los datos que lleguen en esas 12 horas
   todavía cuentan. Ver la sección de retos. Esto baja bastante la gravedad del
   punto 1, pero no lo elimina — ver abajo.

**El límite del período de gracia:** hoy la cola de reintentos drena cuando la
app vuelve al primer plano. **No hay sync en segundo plano** — la capability de
HealthKit Background Delivery está deliberadamente apagada. Entonces, si el
usuario no abre la app entre el domingo a la noche y el lunes al mediodía, sus
días atrasados no llegan y el período de gracia no compra nada. Y para alguien
que estuvo inactivo el fin de semana, ese es justamente el caso probable.

Si se quiere que la gracia sirva de verdad, hay que habilitar alguna forma de
sync en segundo plano. Es una decisión con costo real —más escrutinio de Apple
sobre permisos de salud, batería, complejidad— y hoy no está en ningún ticket.

---

## Notas para Luis (backend)

- **El contrato con vos no cambió en v3.2.** El JSON #1 y el JSON #2 están
  idénticos. Lo que sigue son efectos indirectos, no cambios de forma.
- **Nuevo en v3.2 — ráfagas de 7 días por usuario nuevo.** Hasta ahora el
  backfill no corría nunca y solo llegaba el día de hoy, uno por sync. Ahora
  cada usuario que concede permisos dispara 7 POSTs seguidos en segundos. Con
  50 personas del piloto entrando el mismo día son ~350 requests en ráfaga.
- **Nuevo en v3.2 — la idempotencia por fin se ejercita de verdad.** El
  constraint de L4 estaba escrito para esto pero casi nunca se probaba, porque
  el único camino era un día a la vez. Ahora el backfill y la cola de reintentos
  reenvían días repetidos de forma rutinaria. Vale verificarlo con un reenvío
  real antes del piloto.
- **Nuevo en v3.2 — un día ausente es ambiguo.** Ver la sección "Días sin
  actividad" arriba. Afecta directamente la evaluación del reto semanal.
- **Nuevo en v3.2 — cuándo evaluar la semana (decidido 5 sep).** La semana cierra
  el domingo 23:59 y se evalúa el **lunes 12:00**. Los datos que lleguen en esas
  12 horas cuentan para el reto; los que lleguen después suman al acumulado anual
  y al historial, pero ya no mueven el reto de esa semana. O sea: el motor de
  retos necesita una corrida programada del lunes al mediodía, no un cálculo en
  vivo al cierre del domingo.
- **Nuevo en v3.2 — endpoint de resumen para el dashboard (ticket por crear).**
  Decidido el 5 sep: `pasos_totales_dia` y el resto de lo que muestra el
  dashboard los pide Flutter por HTTP directo contra tu API, no por el
  MethodChannel. Los campos exactos los define Daniel. Ver "Puntos abiertos".
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
- **Cambiado en v3.2 — las dos respuestas traen `estado`.** Ver las tablas de
  la sección del MethodChannel. Los dos cambios que pueden romper código
  escrito contra v3.1:
  1. `concedido` cambió de significado aunque se llame igual. Antes era "se
     mostró el diálogo" (prácticamente siempre `true`); ahora es "confirmamos
     que hay acceso". Código que solo lea `concedido` sigue compilando pero
     ahora va a recibir `false` en casos donde antes recibía `true`.
  2. `sincronizado_en` ya no viene siempre — leerlo como `String?`.
- **Usá `lib/datos/healthkit_bridge.dart`**, que ya expone los dos métodos
  tipados con enums de Dart. Evita parsear strings a mano.
- **`pasos_totales_dia` no viene por el canal.** Se pide por HTTP al endpoint de
  resumen de Luis, junto con el resto de los datos del dashboard (decidido el
  5 sep — ver "Puntos abiertos"). El canal solo confirma que el sync ocurrió;
  los números para mostrar salen siempre de la API de Luis. Los campos de ese
  endpoint los definís vos.
- `ok: false` ya no es un solo caso. `encolado` **no** es una falla que mostrar
  como error — el dato quedó a salvo y se reintenta solo.
- El nivel de reto semanal (D12) sigue sin venir en la respuesta del sync —
  pedirlo aparte con `GET /api/v1/retos/estado` cuando se necesite mostrar en
  la pantalla de retos. No lo confundas con `nivel` (el anual, de cashback)
  que sí viene en la respuesta del sync.
- Nada de SDKs de terceros (ej. Firebase) puede tocar datos que vengan de
  HealthKit, ni siquiera indirectamente — Apple lo trata como filtración y
  causa remoción inmediata de la app.

---

## Puntos abiertos

Cosas que este documento **no** resuelve todavía y hay que cerrar entre los tres.

### 1. Dónde lee Flutter `pasos_totales_dia` — DECIDIDO (5 sep 2026)

**Decisión: Luis expone un endpoint de lectura y Flutter se lo pide por HTTP**,
igual que todo lo que no es HealthKit. El número lo sigue calculando el backend
exactamente como hasta ahora — lo único que cambia es por dónde llega a Flutter.

El problema era de ruta, no de cálculo. v3.1 se contradecía a sí mismo: la tabla
del MethodChannel decía que el lado nativo "lo cachea localmente para que Flutter
lo pida por HTTP normal en la siguiente pantalla", mientras que la nota para
Daniel decía que "ya viene en la respuesta de `sincronizar()`". No podían ser las
dos, y no era ninguna. El dato llega al teléfono como respuesta a un `POST` que
hace **Swift** (Flutter nunca le habla a `/sync`, no tiene qué mandarle), así que
aterriza del lado nativo y Flutter no lo ve nunca.

Se descartaron las otras dos salidas:

- **Que el canal devuelva el JSON #2 en la respuesta de `sincronizar`.** Más
  barato de implementar, pero hace que el dato viaje backend → Swift → canal →
  Flutter, con escala en una capa que no tiene nada que ver con él. Además solo
  sirve para el día recién sincronizado: el backfill descarta las respuestas de
  los otros seis.
- **Cache nativo consultable.** Requiere un tercer método en el canal, contra el
  principio de mantenerlo en 2.

**Lo que queda por definir:** los campos exactos del endpoint. Los define Daniel,
que es quien sabe qué está construyendo — **no** salen del PDF de pantallas, que
está desactualizado. Es un ticket de Luis que hoy no existe.

### 2. Días vacíos, y si hace falta sync en segundo plano

Lo de cuándo se cierra la semana **quedó decidido** el 5 sep: domingo 23:59,
evaluación el lunes 12:00 (ver la sección de retos). Queda pendiente:

- Emparejar los tres caminos frente a un día vacío — ver "Días sin actividad".
- Definir las tres cosas que abre el período de gracia: qué ve el usuario durante
  esas 12 horas, cuándo se fija la meta de la semana nueva, y en qué huso horario
  corre el mediodía.
- Decidir si se habilita sync en segundo plano. Sin eso, el período de gracia
  solo sirve para usuarios que abren la app en esa ventana — que no son los que
  más lo necesitan.

### 3. `usuario_id` sigue siendo un placeholder

El lado iOS manda un `usuario_id` fijo hardcodeado, porque el login real
(L10 / D6) todavía no existe. Todo lo que se sincronice antes de que el login
esté listo queda atribuido a ese id. Hay que definir si esos datos del piloto
temprano se migran, se descartan, o si el login llega antes de que importe.
