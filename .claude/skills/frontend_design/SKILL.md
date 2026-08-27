---
name: frontend_design
description: Úsala siempre que se construya o rediseñe una interfaz frontend, componente, página o app — guía la creación de UI distintiva, de calidad de producción y con sensación humana, que evita las estéticas genéricas de "AI slop" (fuentes Inter/Roboto, gradientes morados, layouts de molde). Asegúrate de usar esta skill siempre que el usuario mencione construir una app, una pantalla, una UI, una landing page, o cualquier interfaz visual, incluso si no piden "diseño" explícitamente.
---

# Diseño Frontend

Esta skill guía la creación de interfaces frontend distintivas y de calidad de producción que se sientan como si hubieran sido diseñadas y construidas por un equipo de producto real — no generadas por IA. Antes de escribir cualquier código, reúne el contexto necesario para tomar decisiones de diseño deliberadas, y luego implementa con una atención excepcional al detalle estético y de interacción.

## Paso 1: Preguntar antes de construir

Antes de escribir código para una nueva app, pantalla, o rediseño significativo, pregúntale al usuario sobre las decisiones de abajo. No preguntes sobre cosas ya mencionadas u obvias por el contexto (p. ej. si ya dijeron "oscuro, minimalista, blanco y negro" no necesitas volver a preguntar sobre tono o color). Sáltate este paso por completo para ajustes pequeños y bien especificados a código existente ("haz este botón más grande", "arregla el padding aquí") — ve directo a implementar.

Usa preguntas cortas y concretas — idealmente con un set de opciones seleccionables cuando sea posible — en lugar de un párrafo largo y abierto. Pregunta en uno o dos bloques, no una pregunta a la vez en ida y vuelta.

Cubre:

1. **¿Para qué es la app/pantalla, y quién la usa?** (p. ej. una app de chat para amigos cercanos, un rastreador de hábitos, un dashboard administrativo interno, un marketplace). Esto determina casi todo lo que viene después.
2. **Dirección de tono/estética.** Empuja hacia una dirección específica y comprometida en lugar de "limpio y moderno" — ofrece opciones como: brutalmente minimalista, maximalista/expresivo, retro-futurista, editorial/revista, lujo/refinado, juguetón/tipo juguete, industrial/utilitario, cálido y orgánico, brutalista/crudo.
3. **Preferencias de color.** Pregunta si tienen colores específicos/de marca en mente, o un mood (p. ej. "cálido y terroso" vs "frío y clínico" vs "alto contraste y audaz"). Si no tienen preferencia, propón 2-3 direcciones de paleta concretas en lugar de decidir en silencio.
4. **Puntos de referencia.** Pregunta qué apps existentes les gustan en cuanto a sensación (patrones de interacción, densidad de información, ritmo) — ver "Referenciar apps reales" abajo. Esta es una de las señales más útiles que puedes obtener.
5. **Claro u oscuro, o ambos.**
6. **Restricciones de plataforma/framework**, si no son ya obvias (React web, React Native, Flutter, HTML plano, etc.) y cualquier sistema de diseño o librería de componentes existente que se deba respetar.
7. **Cualquier cosa que explícitamente quieran evitar** — p. ej. "sin gradientes morados", "que no se vea corporativo", "que no se parezca a ChatGPT".

Una vez tengas suficiente para comprometerte con una dirección, repítela de vuelta en una o dos oraciones antes de programar ("Entendido — una app de journaling cálida y con sensación editorial, paleta crema y terracota, modo oscuro opcional, inspirada en el ritmo de las Historias de Instagram y la tipografía de una revista impresa") para que el usuario pueda corregir el rumbo antes de que escribas algo.

## Paso 2: Pensamiento de diseño

- **Propósito**: ¿Qué problema resuelve esta interfaz? ¿Cuál es la acción principal que un usuario hace más seguido? — esa acción debe sentirse sin esfuerzo.
- **Tono**: Comprométete con el extremo de la dirección elegida en lugar de un término medio seguro. Tanto el maximalismo audaz como el minimalismo refinado funcionan — la clave es la intencionalidad, no la intensidad.
- **Restricciones**: Requisitos técnicos (framework, rendimiento, accesibilidad).
- **Diferenciación**: ¿Cuál es el único detalle que alguien va a recordar o capturar en pantalla?

## Paso 3: Hacer que se sienta humano, no generado por IA

La señal más grande de una UI generada por IA es que se ve como una plantilla, no como un producto que alguien realmente lanzó. A menos que el usuario diga lo contrario, por defecto haz que todo se sienta hecho a mano y considerado:

- **Sin señales de código hecho por IA.** Evita: Inter/Roboto/system-ui como fuente protagonista, gradientes morado-a-azul, tarjetas genéricas de esquinas redondeadas con sombra y sin ninguna otra personalidad, el layout plantilla de hero centrado + 3 tarjetas de features + testimonios, emojis usados como íconos, copy que se siente lorem-ipsum, grillas espaciadas uniformemente sin jerarquía visual.
- **Señales reales de oficio de producto**: layouts imperfectos/asimétricos donde eso sirve al contenido, micro-copy con personalidad en lugar de etiquetas genéricas ("Todavía no hay nada aquí" en lugar de "No hay datos disponibles"), estados vacíos y de error diseñados con el mismo cuidado que el camino feliz, estados de carga que se sienten pensados (skeletons que igualan la forma del contenido real, no spinners genéricos), contenido de relleno realista (nombres que suenan reales, timestamps, texto de mensajes) en lugar de "Lorem ipsum" o "Usuario 1".
- **Detalles que solo un diseñador humano se molesta en cuidar**: alineación óptica consistente (no solo centrado matemáticamente), letter-spacing ajustado según el tamaño de fuente, estados de hover/press con feedback real (escala, cambio de color, movimiento que se siente háptico), tamaños de área táctil correctos en móvil, manejo de safe-area, y copy que suena como si lo hubiera escrito una persona.

## Paso 4: Referenciar apps reales

Cuando el usuario nombre una app de referencia (WhatsApp, Instagram, X, Facebook, u otras), estudia qué es lo que realmente hace que la UI de esa app funcione y toma prestado el *patrón*, no la piel literal — nunca reproduzcas el logo exacto, el wordmark, o el trade dress de una marca.

- **WhatsApp**: densidad de información extrema hecha con calma — las filas de la lista de chats empacan mucho pero nunca se sienten saturadas; padding generoso en las burbujas y salto de línea permisivo; uso de color apagado y utilitario para que el contenido (la conversación) siga siendo el foco visual; affordances de estado inconfundibles (checkmarks, "escribiendo…") mantenidos pequeños y discretos.
- **Instagram**: contenido primero, chrome mínimo — la UI se aparta del camino de las imágenes/video; uso confiado del espacio en blanco entre unidades de contenido distintas; iconografía audaz y simple; transiciones rápidas que se sienten físicas (barras de progreso de historias, like con doble tap, transiciones de sheet con física de resorte real).
- **X (Twitter)**: densidad de escaneo rápido — ritmo vertical ajustado, jerarquía de texto fuerte (nombre/usuario/timestamp/cuerpo todos con pesos distintos), fila de acciones ligera y persistente, ritmo de feed infinito que premia el scroll rápido sobre la lectura deliberada.
- **Facebook**: modularidad basada en tarjetas para tipos de contenido heterogéneos (foto, texto, evento, anuncio) dentro de un mismo shell de feed consistente; uso más pesado de divisores y fondos sutiles para separar bloques de contenido no relacionados; escala tipográfica utilitaria, ligeramente más densa que la de Instagram.

Extrae los principios subyacentes de interacción y layout (densidad, jerarquía, sensación de movimiento, cuánto se retira el chrome) hacia la dirección estética propia del usuario — el resultado debe sentirse tan cuidado como esas apps, no como un clon de ninguna de ellas.

## Paso 5: Guías de estética frontend

- **Tipografía**: Elige fuentes que sean hermosas, únicas e interesantes. Evita fuentes genéricas como Arial e Inter; opta por elecciones distintivas que eleven la interfaz. Combina una fuente de display distintiva con una fuente de cuerpo refinada.
- **Color y Tema**: Comprométete con una estética cohesiva usando la paleta establecida en el Paso 1. Usa variables CSS (o el sistema de theming de la plataforma) para mantener consistencia. Los colores dominantes con acentos definidos superan a las paletas tímidas y distribuidas de forma uniforme.
- **Movimiento**: Usa animación para efectos y micro-interacciones. Prioriza soluciones solo-CSS para HTML; usa la librería Motion para React cuando esté disponible; usa las APIs de animación nativas de la plataforma para React Native/Flutter. Enfócate en los momentos de alto impacto: una carga de página bien orquestada con revelaciones escalonadas crea más deleite que micro-interacciones dispersas. El movimiento debe sentirse físico (resortes, easing que imita peso real), no lineal/robótico.
- **Composición Espacial**: Layouts inesperados donde sea apropiado. Asimetría. Superposición. Flujo diagonal. Elementos que rompen la grilla. Espacio negativo generoso O densidad controlada — elige deliberadamente según las apps de referencia elegidas.
- **Fondos y Detalles Visuales**: Crea atmósfera y profundidad en lugar de recurrir por defecto a colores sólidos. Agrega texturas contextuales que coincidan con la estética general — mallas de gradiente, texturas de ruido, patrones geométricos, transparencias en capas, sombras dramáticas, bordes decorativos, cursores personalizados, overlays de grano — usados con moderación, no como decoración por sí misma.

NUNCA uses estéticas genéricas generadas por IA como familias de fuentes sobreusadas (Inter, Roboto, Arial, fuentes del sistema), esquemas de color trillados (particularmente gradientes morados sobre fondos blancos), layouts y patrones de componentes predecibles, y diseño de molde que carece de carácter específico al contexto.

Interpreta con creatividad y toma decisiones inesperadas que se sientan genuinamente diseñadas para el contexto. Ningún diseño debería ser igual. Varía entre temas claros y oscuros, distintas fuentes, distintas estéticas. NUNCA converjas en las elecciones comunes (Space Grotesk, por ejemplo) a través de generaciones.

IMPORTANTE: Iguala la complejidad de la implementación con la visión estética. Los diseños maximalistas necesitan código elaborado con animaciones y efectos extensos. Los diseños minimalistas o refinados necesitan contención, precisión, y atención cuidadosa al espaciado, la tipografía y los detalles sutiles. La elegancia viene de ejecutar bien la visión.

## Paso 6: Implementar

Escribe código real, funcional, de calidad de producción (HTML/CSS/JS, React, Vue, Flutter, etc.) que sea:

- Funcional y completo, no una maqueta
- Visualmente llamativo, memorable, y cohesivo con la dirección estética comprometida
- Meticulosamente refinado en cada detalle — espaciado, estados, movimiento, copy

Recuerda: no te contengas. Comprométete por completo con la visión distintiva establecida con el usuario antes de empezar a programar.
