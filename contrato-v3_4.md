# Contrato v3 — +Vida

Este documento define cómo se comunican las tres capas del proyecto: iOS (Alvaro),
backend (Luis) y Flutter (Daniel). Una vez congelado, los tres construyen contra
este documento — no contra lo que cada quien tenga corriendo en su máquina.

Cualquier cambio de campo, tipo o forma es un **v4**, no un parche silencioso a este
archivo. Si algo no está aquí, no existe todavía. Este documento es autocontenido:
no hace falta abrir `contrato-v2.md` ni `contrato-v1.md` para nada de lo que sigue.

> **Qué cambió de v3.3 a v3.4 (6 sep 2026):** se cierra **L14 — la ventana de
> datos rezagados**, que hasta ahora era un ticket suelto que nunca se cruzó con
> el comportamiento real del cliente. Es el primer cambio desde v3 que **sí le
> pide algo a Luis**, aunque los dos JSON de éxito siguen intactos.
>
> 1. **La ventana de aceptación queda en 14 días**, no en 3 como estaba planteado
>    el ticket. Con 3 días el backfill de 7 se rompía: sus días 4 a 7 rebotaban,
>    el cliente los leía como "payload inválido", los descartaba, y abortaba el
>    procesamiento de todos los días que venían después.
> 2. **La cola de reintentos pasa a caducar por edad (14 días), no por cantidad
>    (30 entradas).** Ventana y cola quedan en la misma cifra a propósito.
> 3. **Un rechazo por antigüedad devuelve 422 con motivo identificable**, no un
>    400 genérico. Sin eso el cliente no puede distinguir "esto llegó tarde" de
>    "esto está mal formado", y trata las dos cosas como un defecto.
>
> El backfill se queda en 7 días a propósito: no contesta la misma pregunta que
> la ventana, y tiene que ser menor para tener holgura de reintentos. Ver la
> sección "Ventana de aceptación de datos rezagados".
>
> **Qué cambió de v3.2 a v3.3 (6 sep 2026):** otra vez **solo el MethodChannel**.
> El JSON #1 y el JSON #2 siguen byte por byte iguales — tercera versión seguida
> en que Luis no se entera de nada.
>
> 1. **`solicitarPermisos` ahora dice QUÉ tipos de dato ve, no solo si ve
>    alguno.** La sonda de v3.2 consultaba únicamente pasos y emitía un veredicto
>    sobre los tres tipos. Pero los permisos de HealthKit son **por tipo**: el
>    usuario puede conceder pasos y negar ritmo cardíaco en el mismo diálogo. En
>    ese caso v3.2 respondía `concedido` y el usuario nunca ganaba un solo punto
>    de intensidad — sin señal para él, para Daniel ni para Luis. Ahora la
>    respuesta trae un mapa `tipos`.
> 2. **Se eliminan los booleanos `concedido` y `ok`.** Cada uno era exactamente
>    `estado == "concedido"` y `estado == "ok"`: un segundo lugar donde la misma
>    verdad podía desincronizarse, que es literalmente el bug que arreglamos en
>    v3.2. Se sacan ahora porque Daniel todavía no había escrito la pantalla —
>    es el único momento en que quitar un campo cuesta cero.
> 3. **Se agrega logging (`os.Logger`) a la capa de HealthKit.** No cambia el
>    contrato; se anota acá porque es lo que va a permitir diagnosticar un
>    "no me contó los pasos del martes" durante el piloto sin reproducirlo.
>    Regla fija: al log nunca entra un valor de salud, solo hechos estructurales.
>
> Se evaluó y **se descartó** exponer `statusForAuthorizationRequest` (el API que
> dice si iOS va a mostrar diálogo). Para servir de algo, Flutter tendría que
> consultarlo **antes** de llamar a `solicitarPermisos`, y eso exige un tercer
> método en el canal — el contrato de 2 métodos es una decisión cerrada del
> proyecto. Su otro uso (detectar tipos nuevos en v2) ya lo resuelve solo
> `requestAuthorization`, que presenta el diálogo del tipo nuevo sin ayuda.
>
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

**Sin cambios desde v3.1** — ni en v3.2, ni en v3.3, ni en v3.4.

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

**El cuerpo de éxito no cambia desde v3.1.** Nuevo en v3.4: la respuesta de
**rechazo por antigüedad** — ver "Ventana de aceptación de datos rezagados".

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
  semana** — pero sí sigue sumando al acumulado anual de puntos y al historial,
  **siempre que llegue dentro de la ventana de 14 días** (nuevo en v3.4 — ver
  "Ventana de aceptación de datos rezagados"). Dentro de esa ventana los datos
  tardíos nunca se descartan; solo dejan de poder cambiar un reto ya evaluado.
  Pasados los 14 días sí se rechazan.

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

> **Cambiado en v3.2 y otra vez en v3.3.** Los nombres de los métodos y sus
> entradas (ninguna) no cambian, y siguen siendo 2. Lo que cambió son **las dos
> respuestas**: en v3.2 pasaron a traer `estado`, y en v3.3 se les quitaron los
> booleanos redundantes (`concedido`, `ok`) y `solicitarPermisos` ganó el mapa
> `tipos`. Nada de esto toca a Luis.

Todo lo que no sea leer HealthKit va por HTTP directo de Daniel contra la API
de Luis. El puente nativo se reduce a estos 2 métodos — nada de dashboard,
niveles, retos ni historial pasa por acá.

```dart
final bridge = HealthKitBridge();

// 1. Pide permiso de HealthKit la primera vez (o revalida si el usuario lo cambió en Ajustes)
final permisos = await bridge.solicitarPermisos();
// permisos.estado → EstadoPermisos.concedido
// permisos.tipos  → TiposVisibles(pasos: true, ritmoCardiaco: false, entrenamientos: false)

// 2. Lee HealthKit, arma el JSON #1 y lo manda a /api/v1/sync
final sync = await bridge.sincronizar();
// sync.estado         → EstadoSync.ok
// sync.sincronizadoEn → "2026-09-05T20:15:00-06:00"
```

Usá el wrapper, no `canal.invokeMethod` crudo. La forma que viaja por el canal
es esta, y está acá solo como referencia del contrato:

```json
// solicitarPermisos
{ "estado": "concedido",
  "tipos": { "pasos": true, "ritmo_cardiaco": false, "entrenamientos": false } }

// sincronizar
{ "estado": "ok", "sincronizado_en": "2026-09-05T20:15:00-06:00" }
```

### `solicitarPermisos`

Entrada: ninguna.
Salida: `{ "estado": string, "tipos": {string: bool}?, "detalle": string? }`

| `estado` | Qué significa | Qué debe hacer Flutter |
|---|---|---|
| `concedido` | Se ven pasos: la app puede puntuar | Seguir el flujo normal, **pero mirar `tipos`** — ver abajo |
| `sin_datos_visibles` | No se ven pasos, que son el piso del puntaje. Puede ser permiso negado **o** un usuario real sin actividad en 30 días — HealthKit no permite distinguirlos | Mensaje del tipo "No vemos datos de actividad. Si negaste el acceso, activalo en Ajustes › Salud › +Vida". **Nunca** un "listo" ni un "permiso denegado" categórico |
| `no_disponible` | El dispositivo no soporta HealthKit (iPad, simulador) | Ocultar la función. Caso terminal |

Si falla la solicitud en sí, llega como `FlutterError` con código `PERMISOS_ERROR`
— no como un `estado`.

#### El mapa `tipos` — nuevo en v3.3

```json
{ "pasos": true, "ritmo_cardiaco": false, "entrenamientos": false }
```

Viaja **solo** en `concedido` y `sin_datos_visibles`, que son los dos estados en
los que la sonda efectivamente corrió. En `no_disponible` no hay HealthKit en el
aparato y nunca se consultó nada: inventar ahí un mapa de `false` diría "miramos
y no había", que no es lo mismo que "no se pudo mirar". Cuando viaja, trae
**siempre las tres claves** — el lado nativo las serializa desde `allCases`, así
que Flutter nunca tiene que distinguir `false` de "no vino la clave".

**Cómo NO leerlo.** La ambigüedad no es igual en los tres tipos, y tratarlos
parejo produce un mensaje equivocado para casi todo el piloto:

| tipo | qué significa `false` |
|---|---|
| `pasos` | Casi seguro **permiso negado**. Con permiso, cualquier usuario tiene pasos en 30 días |
| `ritmo_cardiaco` | Lo más probable es que **no tenga reloj**, no que haya negado. Es también el tipo que hace falta para las sesiones intensas |
| `entrenamientos` | Igual que el anterior: sale del reloj o de que registre workouts a mano |

Por eso el texto para el usuario tiene que ser **condicional, no acusatorio**:
"No vemos datos de ritmo cardíaco. Si usás un reloj, revisá que +Vida tenga
permiso en Ajustes › Salud." Mandar a arreglar un permiso a todo el que no tiene
reloj sería ruido para la mayoría.

**Por qué cambió (v3.2):** `HKHealthStore.requestAuthorization` termina **sin
error** aunque el usuario haya negado todos los permisos — HealthKit nunca
informa un permiso de lectura negado. El `concedido: true` de v3.1 solo
significaba "se mostró el diálogo", así que la app le decía "listo" a alguien que
había negado todo y después nunca sincronizaba nada sin explicación.

**Por qué volvió a cambiar (v3.3):** la sonda de v3.2 consultaba solo pasos. Como
el permiso se concede por tipo, un usuario que concedía pasos y negaba ritmo
cardíaco recibía `concedido` y nunca ganaba un punto de intensidad, en silencio.
Ahora se sondean los tres tipos en paralelo y se reporta cada uno.

### `sincronizar`

Entrada: ninguna.
Salida: `{ "estado": string, "sincronizado_en": string?, "detalle": string? }`

| `estado` | Qué significa | Qué debe hacer Flutter |
|---|---|---|
| `ok` | Llegó a Luis y quedó guardado. `sincronizado_en` viene con el timestamp ISO 8601 | Confirmación normal |
| `encolado` | Sin red o backend caído. El día quedó en la cola local y se reintenta solo al volver del background (A8) | Aviso suave. **No** presentarlo como falla — el dato no se perdió |
| `sin_acceso_a_salud` | No se pudo leer HealthKit. Casi siempre permisos | Guiar a Ajustes › Salud › +Vida |
| `error_permanente` | URL mal configurada, o el backend rechazó el payload (4xx). No se reintenta | El usuario no puede resolverlo; registrar y reportar |

- `sincronizado_en` **solo viene cuando `estado` es `ok`.** En v3.1 llegaba como
  string vacío en los fallos; ahora directamente no está en la respuesta.
  Leerlo como `String?`, no como `String`.
- `detalle` es texto técnico para logs. No mostrárselo crudo al usuario — el
  texto para él sale de `estado`.

**Por qué cambió:** `ok: false` aplastaba tres situaciones que el usuario
resuelve de forma completamente distinta. "Se reintenta solo" y "andá a
Ajustes" son mensajes opuestos, y Flutter no tenía con qué distinguirlos.

### Wrapper de Dart

`lib/datos/healthkit_bridge.dart` ya expone los dos métodos tipados, con
`EstadoPermisos` y `EstadoSync` como enums de Dart y `TiposVisibles` como clase.
Usándolo no hace falta parsear strings ni mapas a mano, y los estados
desconocidos caen en un caso `desconocido` en vez de romper.

Ese archivo es la **frontera del contrato**, no UI: lo mantiene Alvaro junto con
el lado Swift, porque los dos tienen que moverse a la vez. Daniel lo consume, no
lo edita — si algo le falta ahí, es un cambio de contrato, no un parche local.

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

**Decidido (5 sep 2026): no se habilita sync en segundo plano.** El período de
gracia es un extra sobre lo que el usuario ya debería haber hecho —sincronizar
antes de que cerrara la semana—, no una garantía. Quien no abra la app en esas 12
horas simplemente no lo aprovecha, y eso es aceptable. Se descarta HealthKit
Background Delivery por ahora: tiene costo real en escrutinio de Apple sobre
permisos de salud, batería y complejidad, a cambio de cubrir un caso que es
responsabilidad del usuario.

---

## Ventana de aceptación de datos rezagados

> **Nuevo en v3.4 (6 sep 2026).** Cierra el ticket **L14**, que estaba planteado
> en 3 días sin haberse cruzado nunca con el comportamiento del cliente.

**La cifra es 14 días.** Un payload cuyo `fecha` tenga más de 14 días de
antigüedad al momento de llegar al servidor se rechaza.

### De dónde sale el 14

```
ventana ≥ día más viejo del backfill + holgura para reintentos
        = 6 días + 7 días de gracia
        = 13 → 14
```

El backfill manda hasta `hoy − 6`. Ese día nace con 6 días de antigüedad, así que
necesita margen para reintentarse si falla la red. Siete días de holgura es lo
mínimo razonable, dado que la cola solo drena cuando el usuario abre la app.

### Las tres cifras y cómo se relacionan

| Cifra | Valor | Qué contesta |
|---|---|---|
| **Ventana del servidor** | 14 días | ¿Hasta qué tan viejo acepto un dato? |
| **Cola de reintentos (cliente)** | 14 días | ¿Cuánto sigo intentando mandar un día que falló? |
| **Backfill (cliente)** | 7 días | ¿Cuánto historial le traigo a un usuario nuevo? |

**Ventana y cola son la misma cifra a propósito.** Si la cola fuera más corta,
tiraría días que el servidor todavía aceptaría — pérdida de datos gratis. Si
fuera más larga, guardaría días que ya nunca van a entrar, reintentándolos en
vano.

**El backfill es deliberadamente menor.** Contesta otra pregunta y necesita
holgura: si también fuera 14, su día más viejo nacería pegado al límite y
cualquier fallo de red lo mataría.

> Antes de v3.4 estas tres cifras eran **7, 3 y 30**, sin ninguna relación entre
> sí — y el 30 de la cola ni siquiera era un límite de antigüedad: era un tope de
> cantidad de entradas con desalojo FIFO. No había ningún límite de edad del lado
> del cliente, y por eso un día que nunca lograba enviarse se quedaba en la cola
> indefinidamente.

### La respuesta de rechazo

Un rechazo por antigüedad **debe ser distinguible** de un rechazo por payload
inválido:

```
HTTP 422
{ "error": "fuera_de_ventana", "fecha": "2026-08-15" }
```

Motivo: el cliente clasifica los errores para decidir si reintenta. Un `4xx`
genérico significa "mandaste algo mal, reintentar no sirve" — y con esa lectura
el cliente descarta el día **y aborta el procesamiento de los días que venían
después**. Con un motivo identificable lo trata como esperado: descarta ese día y
sigue con el resto.

### Ninguno de los dos lados puede verificar al otro

El 14 está hardcodeado por separado en el backend y en el cliente. Si uno lo
cambia sin avisar, los días del rango de diferencia empiezan a rebotar en
silencio. Por eso la cifra vive acá, en el contrato, y por eso el 422 con motivo
importa: es la única señal de que los dos lados se desincronizaron.

### Lo que la ventana NO resuelve

Una ventana rodante no protege un ciclo ya cerrado. Un dato del 29 de septiembre
que llega el 10 de octubre cae dentro de los 14 días y **reabriría la liga de
septiembre**. Eso no se arregla con ningún número de días.

**Son dos reglas distintas, y hay que implementar las dos:**

| Pregunta | Regla |
|---|---|
| ¿Entra el dato a la base? | Ventana de 14 días |
| ¿Puede mover un ciclo ya cerrado? | Frontera de ciclo — ver la sección de retos |

Sobre el argumento anti-fraude que motivó L14: la ventana **no frena la inyección
de datos falsos**. Quien pueda escribir muestras fabricadas en HealthKit las
escribe con fecha de hoy igual de fácil. Lo que la ventana sí hace es impedir que
se reabran libros ya cerrados — y para eso la regla de ciclo es más precisa que
contar días.

---

## Notas para Luis (backend)

- **v3.2 y v3.3 no te tocaron.** El JSON #1 y el JSON #2 siguen idénticos desde
  v3.1; lo de esas dos versiones fueron efectos indirectos, no cambios de forma.
- **v3.4 SÍ te pide dos cosas** (ver "Ventana de aceptación de datos rezagados"):
  1. **La ventana de L14 va en 14 días, no en 3.** Con 3 se rompe el backfill de
     7 días del cliente: sus días 4 a 7 rebotan, el cliente los interpreta como
     payload inválido, los descarta, y aborta el resto de la pasada. Con 14 el
     backfill entra completo y le quedan 8 días de holgura para reintentos.
  2. **Un rechazo por antigüedad devuelve `422` con `{"error":
     "fuera_de_ventana"}`**, no un `400` genérico. El cliente usa el código para
     decidir si reintenta; sin un motivo identificable trata "llegó tarde" igual
     que "está mal formado" y corta el procesamiento de los días siguientes.
- **La ventana no reemplaza la regla de ciclo, la complementa.** 14 días decide
  qué entra a la base. Que un dato tardío no recalcule un reto o una liga ya
  cerrados es una regla aparte, por frontera de ciclo — un dato del 29 de
  septiembre que llega el 10 de octubre está dentro de la ventana y reabriría la
  liga de septiembre si no existe esa segunda regla.
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
- **La forma final es la de v3.3.** Si empezás la pantalla ahora, arrancá
  directo contra esta y olvidate de v3.1/v3.2 — nada de lo anterior llegó a
  código tuyo. Lo que tenés que saber:
  1. **Los booleanos `concedido` y `ok` ya no existen.** Cada uno era
     exactamente `estado == "concedido"` / `estado == "ok"`. Se leen desde
     `estado` y punto.
  2. **`solicitarPermisos` trae un mapa `tipos`** con `pasos`,
     `ritmo_cardiaco` y `entrenamientos`. `estado: concedido` significa que se
     ven pasos — no que se vean los tres. Leé los tres antes de decirle al
     usuario que quedó todo listo.
  3. **`ritmo_cardiaco: false` casi nunca significa "negó el permiso"** —
     significa que probablemente no tiene reloj, y en el piloto eso va a ser la
     mayoría. El mensaje va condicional ("si usás un reloj, revisá..."), nunca
     imperativo. Ver la tabla de la sección del canal.
  4. **`sincronizado_en` solo viene con `estado: ok`** — leerlo como `String?`.
- **Usá `lib/datos/healthkit_bridge.dart`**, que ya expone los dos métodos
  tipados con enums de Dart y `TiposVisibles`. Evita parsear strings y mapas a
  mano. Ese archivo lo mantiene Alvaro junto con el Swift — si te falta algo
  ahí, es un cambio de contrato, no un parche local.
- **Cómo probar el canal sin escribir UI:** `lib/debug/pantalla_prueba_healthkit.dart`
  es un banco de pruebas con los dos botones y el resultado crudo. No está
  ruteado (no llega al build); las instrucciones para conectarlo están en la
  cabecera del archivo. Necesita iPhone físico — HealthKit no existe en el
  simulador.
- **`pasos_totales_dia` no viene por el canal.** Se pide por HTTP al endpoint de
  resumen de Luis, junto con el resto de los datos del dashboard (decidido el
  5 sep — ver "Puntos abiertos"). El canal solo confirma que el sync ocurrió;
  los números para mostrar salen siempre de la API de Luis. Los campos de ese
  endpoint los definís vos.
- Fallar no es un solo caso. `encolado` **no** es una falla que mostrar como
  error — el dato quedó a salvo y se reintenta solo.
- **No implementes reintentos.** Ya corren solos del lado nativo cuando la app
  vuelve a primer plano (`SceneDelegate`). Vos solo disparás el sync manual.
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

El sync en segundo plano quedó **descartado** el 5 sep — ver "Días sin actividad".

### 3. La regla de ciclo no está en el alcance de ningún ticket

La ventana de 14 días (v3.4) resuelve **qué datos entran**. La otra mitad —que un
dato tardío no recalcule un reto o una liga ya cerrados— no aparece en el criterio
de aceptación de **L11** ("el corte del domingo cierra la semana") ni de **L12**.
Tampoco aparece la corrida programada del lunes 12:00, que se decidió el 5 sep.

Hay que ampliar el alcance de L11 o abrir un ticket propio. Sin eso, la mitad de
la protección de libros cerrados queda sin construir.

### 4. `usuario_id` sigue siendo un placeholder

El lado iOS manda un `usuario_id` fijo hardcodeado, porque el login real
(L10 / D6) todavía no existe. Todo lo que se sincronice antes de que el login
esté listo queda atribuido a ese id. Hay que definir si esos datos del piloto
temprano se migran, se descartan, o si el login llega antes de que importe.
