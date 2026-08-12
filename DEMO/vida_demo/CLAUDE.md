# +Vida — Contexto del Proyecto

Este archivo se carga automáticamente en cada sesión de Claude Code dentro de
este proyecto. Contiene las reglas de negocio, sistema de diseño, y estado
del proyecto que SIEMPRE deben respetarse al escribir o modificar código.

Si algo que se pide en el chat contradice una regla dura de este documento,
señalalo antes de proceder — no asumas que se quiere romper la regla sin
confirmarlo primero.

## Qué es +Vida

App iOS (construida en Flutter) que lee pasos/actividad de Apple Health, los
convierte en puntos, y esos puntos dan cashback sobre la póliza de gastos
médicos del usuario + premios canjeables con comercios aliados. Referente:
Discovery Vitality, adaptado a Guatemala. Es a la vez entrega de tesis (UFM)
y producto comercial real.

**Modelo de negocio:** B2B2C — el usuario final (asegurado) usa el producto,
pero el cliente que paga es la aseguradora.

**3 vías de ingreso:**
1. Cuota por usuario cobrada a la aseguradora
2. Membresía freemium: la versión premium multiplica los PASOS contados (no
   los puntos). El multiplicador debe aplicarse DESPUÉS de las validaciones
   anti-fraude, nunca antes.
3. Alianzas: comercios pagan por aparecer con cupones en Premios

## Idioma — regla dura

Toda la app en **español latinoamericano**, tono natural y humano (nunca
traducción literal ni robótica). Es para el mercado guatemalteco. Excepción:
los nombres de categorías de cashback (Bronze, Silver, Gold, Platinum)
SIEMPRE quedan en inglés.

## Las 2 monedas — regla dura, nunca mezclar

1. **PUNTOS** — nunca se gastan. Determinan categoría anual y % de cashback.
   Nunca aparecen en Premios.
2. **MONEDAS** (antes "medallas" — si ves ese término en código viejo,
   migralo) — se gastan en Premios, caducan a los 90 días. Nunca aparecen
   en Mi Plan.

Los **duelos** (Social) NO dan ninguna moneda ni premio por ahora — son
puramente competitivos/sociales.

Existe además una **liga de duelos cosmética** (Bronce → Plata → Oro →
Diamante, en español) separada de las categorías de cashback — solo estado
social, sin beneficio real.

## Categorías anuales de cashback (siempre en inglés)

| Categoría | Puntos anuales | % Cashback |
|---|---|---|
| Bronze | 5,000 – 9,999 | 5% |
| Silver | 10,000 – 19,999 | 7.5% |
| Gold | 20,000 – 29,999 | 10% |
| Platinum | 30,000+ | 20% |

**Regla regulatoria dura:** el cashback SIEMPRE se devuelve como dinero
DESPUÉS del pago de la prima. NUNCA se descuenta directamente (regulación de
la Superintendencia de Bancos de Guatemala). Siempre "cashback", nunca
"descuento en tu prima" ni "ahorro en tu póliza".

## Cálculo de puntos diarios

**Por pasos — población general, menores de 65 años** (máximo 200 pts/día):
- Menos de 7,499 pasos = 0 pts
- 7,500 – 9,999 = 50 pts
- 10,000 – 14,999 = 100 pts
- 15,000+ = 200 pts

**Por pasos — usuarios de 65 años o más** (máximo 200 pts/día):
- Menos de 5,000 pasos = 0 pts
- 5,000 – 6,999 = 50 pts
- 7,000 – 9,999 = 100 pts
- 10,000+ = 200 pts

Notas sobre los umbrales 65+:
- La edad DEBE venir de los datos de la póliza que provee la aseguradora,
  NUNCA autodeclarada por el usuario (autodeclararla es un vector de fraude
  obvio).
- Estos umbrales son un punto de partida basado en literatura de actividad
  física en adultos mayores y REQUIEREN validación médica/actuarial antes
  de salir a piloto. No son definitivos.
- En la UI, cualquier mención a metas ajustadas por edad debe tener tono
  cálido, nunca clínico ni condescendiente.

**Por ritmo cardíaco** (máximo 300 pts/día, FCmáx = 220 − edad — esta tabla
ya se autoajusta por edad, no necesita variante para 65+):
- 30min–1h al 60% = 100 pts
- 30min–1h al 70% = 200 pts
- 1h+ al 60% = 200 pts
- 1h+ al 70% = 300 pts
- 1h30+ al 60% = 300 pts

**Techo diario absoluto: 500 pts** (igual para todas las edades). Ningún
dato de ejemplo debe superar esto para un solo día. **Techo anual: 25,000
pts.**

**Meta semanal adaptativa:** arranca en 300 pts, oscila 200-800. Ciclo:
lunes 00:00 a domingo 23:59. Se autoajusta por actividad, no por edad.

## Recompensas por constancia (streaks)

Al alcanzar hitos de semanas consecutivas cumpliendo la meta semanal, el
usuario recibe MONEDAS extra (nunca puntos — los puntos no se otorgan por
rachas):

| Semanas seguidas | Monedas |
|---|---|
| 4 | +5 |
| 8 | +10 |
| 12 | +20 |
| 24 | +40 |
| 52 | +100 |

La racha se muestra en Home (saludo), Progress (historial de 8 semanas +
progreso al próximo hito) y Social (alerta de racha en riesgo).

## Anti-fraude

- HealthKit registra qué app escribió cada muestra — guardar ese campo
- Lista blanca de fuentes confiables (Apple, Garmin, Whoop)
- Una sola actividad cuenta por día (la de mayor puntaje)
- Ventanas de sincronización de 6 días, una cuenta por persona
- Deduplicación: SIEMPRE consultar el total agregado, nunca sumar muestras
  crudas (ej. Apple Watch + Whoop a la vez)
- La edad para umbrales 65+ viene de la póliza, nunca del usuario

## Sistema de diseño (lib/theme.dart)

Tema CLARO. La app debe transmitir paz, tranquilidad y ambiente sano.
(Nota: el proyecto arrancó con tema oscuro; si encontrás restos de negro
`#000000` o gris `#1A1A1A` en el código, son del tema viejo y hay que
migrarlos.)

- **background:** blanco con tinte verdoso sutil `#F7FAF8`
- **card:** blanco puro `#FFFFFF` con borde sutil gris muy claro `#E5E9E7`
  (necesario para que las tarjetas no se pierdan contra el fondo claro)
- **accent (azul, calma):** `#4A90D9` — botones principales, links,
  elementos interactivos
- **accentSecondary (verde, salud/vitalidad):** `#5FAE85` — progreso,
  estados de éxito, checks completados
- **textPrimary:** azul marino oscuro `#1A2E35` (NO negro puro, se ve muy
  duro sobre fondo claro)
- **textSecondary:** gris medio `#6B7280`
- **Tipografía:** SF Pro (o la más parecida disponible)

Reglas visuales:
- **Nunca bordes punteados** en botones, tabs, o nav — corregir siempre a
  sólido o sin borde
- **Sin glows brillantes** — sobre fondo claro se ven mal. Usar sombras
  suaves grises/verdes en su lugar
- **Colores por categoría de cashback:** progresión de verdes (Bronze =
  verde muy pálido → Platinum = verde profundo/saturado). El azul queda
  reservado para elementos de acción, no para categorías
- **Barras de progreso:** fondo vacío en `#E5E9E7`, relleno en verde
  (progreso/logros) o azul (informativo/neutro)
- **Header** (`lib/widgets/app_header.dart`, reutilizado en TODAS las
  pantallas): "+VIDA" pegado a la esquina superior IZQUIERDA, foto de
  perfil pegada a la DERECHA
- **Barra inferior** (`lib/widgets/bottom_nav_bar.dart`, reutilizada en
  TODAS las pantallas): 5 ítems fijos en este orden: Home, Progress,
  Social, Premios, Mi Plan. El ítem activo necesita fondo de píldora sutil
  (verde muy pálido) — sobre fondo claro ya no basta el contraste solo

## Pantallas — estado y contenido

**Home** (`lib/screens/home_screen.dart`) — construida
- Header + saludo dinámico + racha activa (con aviso si está a 1 semana de
  un hito de monedas)
- Anillo de pasos (color según categoría, gradiente, marcadores 25%), meta
  diaria, tiempo restante del día
- Tarjeta de puntos totales (SIN botón de canje)
- "Tu Cashback": monto acumulado, camino de categorías, link a Mi Plan
- "Metas Mensuales": meta base + 4 metas elegidas (progreso/monedas/check),
  selección de 8 opciones el día 1, contador de monedas vs. techo mensual

**Progress** (`lib/screens/progress_screen.dart`) — construida
- Selector Semana/Mes/Año con contenido real por pestaña
- Meta del período + comparación vs. período anterior
- Gráfico de actividad (nunca 30+ barras finitas sin etiqueta)
- Racha con historial de 8 semanas (cada casilla refleja si se cumplió) +
  progreso al próximo hito de monedas
- Sección "Recompensas por constancia": los 5 hitos con check en los
  alcanzados
- "Nivel Actual", Monedas del período, Ritmo Cardíaco (obligatorio si se
  pide permiso `.heartRate`)
- CTA "Ver mis récords" (pantalla de Récords Personales — pendiente)

**Social** (`lib/screens/social_screen.dart`) — construida, dos pestañas
- Amigos: alerta de racha en riesgo, Duelo (activo/invitación), superación
  del propio baseline (nunca comparación directa), historial W/L, lista de
  conexiones (racha, categoría, monedas — NUNCA pasos ni historial crudo),
  bloquear/eliminar
- Ranking: selector de grupos, posición propia, cuánto falta para subir,
  lista completa

**Premios** — construida
- Catálogo (filtros, saldo de monedas, costo en monedas)
- Detalle (condiciones, vencimiento, canje)
- Canje exitoso (QR, resumen de monedas descontadas)

**Mi Plan** — diseñada, confirmar si está construida en Flutter
- Cashback acumulado, proyección de fin de año, calendario de cálculo,
  nota regulatoria, tabla de categorías
- Sección "Detalles de tu Póliza" (datos que la aseguradora expone al
  asegurado, agrupados en 2-3 tarjetas por tema): número de póliza,
  titular y dependientes, tipo de plan, suma asegurada, deducible,
  coaseguro, vigencia, renovación, prima y forma de pago, red de
  hospitales/cobertura, estado de la póliza

**Perfil y Configuración + Consentimiento aseguradora** — diseñadas en
Stitch, pendiente pasar a Flutter

## Datos que se comparten con la aseguradora

Límite duro: nada de HealthKit crudo a terceros. Solo datos agregados, con
consentimiento explícito del usuario en pantalla propia y revocable.

Lo que SÍ se comparte (agregado, nivel de cohorte):
- % de asegurados en cada categoría y tendencia de actividad del pool
- Tasa de adherencia: % con rachas activas, % que sube vs. baja de categoría
- Segmentación por edad/categoría para proyección de siniestralidad

Lo que NUNCA se comparte:
- Pasos diarios individuales, ritmo cardíaco crudo, ubicación, ni nada a
  nivel de persona identificable más allá de categoría/cashback (que ya es
  parte del contrato con el asegurado)

Esto NO es una pantalla de la app del asegurado — sería un dashboard B2B
separado o un reporte periódico. [PENDIENTE: definir si se construye como
producto o queda solo como material de pitch comercial]

## Decisiones técnicas cerradas

- Frontend: **Flutter** (decisión final, no solo demo)
- Backend: Python — [COMPLETAR: framework que decidió Luis]
- Fuente de datos: Apple HealthKit únicamente
- Datos leídos: pasos, ritmo cardíaco, workouts (NO elevación)
- Distribución piloto: TestFlight
- [COMPLETAR: quién del equipo tiene Mac para builds de iOS]

## Decisiones pendientes

- El "twist propio" del proyecto
- Validación médica/actuarial de los umbrales 65+
- Si el dashboard para la aseguradora se construye o queda como pitch
