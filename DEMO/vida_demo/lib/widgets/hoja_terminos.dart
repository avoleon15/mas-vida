import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'acceso_widgets.dart';

// ============================================================
// LOS TÉRMINOS Y CONDICIONES COMPLETOS.
//
// Se abren desde el último paso del registro y desde el pie del login.
// El resumen corto vive en el registro; acá va todo, en el mismo tono de
// la app y sin jerga legal, pero sin esconder nada.
//
// Lo que dice sobre los datos tiene que ser la VERDAD de lo que hace la
// app (CLAUDE.md, "Datos que se comparten con la aseguradora"): a la
// aseguradora le llega un resumen diario POR PERSONA, no solo agregados
// de grupo. El texto viejo de D11 prometía otra cosa; no copiarlo.
//
// [PENDIENTE: revisión legal antes del piloto. El contenido sale de las
// reglas vivas del proyecto; la forma legal la pone quien corresponda.]
// ============================================================

/// Abre los términos completos en una hoja.
void mostrarHojaTerminos(BuildContext context) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => const HojaTerminos(),
  );
}

/// Una sección de los términos: un título y sus párrafos.
class SeccionTerminos {
  const SeccionTerminos(this.titulo, this.parrafos);

  final String titulo;
  final List<String> parrafos;
}

/// El texto completo. Público para que los tests puedan revisar que lo
/// que se promete sigue ahí.
const List<SeccionTerminos> seccionesTerminos = [
  SeccionTerminos('Qué es +Vida', [
    '+Vida convierte lo que te mueves en puntos. Con tus puntos subes de '
        'nivel cada año y, si tienes una póliza de gastos médicos '
        'vinculada, recibes cashback y puedes canjear premios con comercios '
        'aliados.',
    'Usar la app es gratis. Todo lo que implica dinero o premios necesita '
        'una póliza vinculada y verificada por tu aseguradora.',
  ]),
  SeccionTerminos('Tu cuenta', [
    'Para crear tu cuenta te pedimos tu nombre, tu correo, una contraseña '
        'y tu fecha de nacimiento. Cada persona puede tener una sola cuenta.',
    'Tu contraseña es solo tuya. No la compartas: quien entre con ella '
        'puede ver tu actividad y canjear tus monedas.',
  ]),
  SeccionTerminos('Los datos de Salud que leemos', [
    'Al aceptar estos términos autorizas a +Vida a leer de la app Salud de '
        'tu iPhone (Apple HealthKit) tres tipos de datos: tus pasos, tu '
        'ritmo cardíaco y tus entrenamientos. Pueden venir de tu teléfono o '
        'de un reloj conectado.',
    'No leemos nada más: ni tu sueño, ni tu peso, ni tus registros médicos, '
        'ni ningún otro dato de Salud.',
    '+Vida solo lee. Nunca escribe, cambia ni borra nada en Salud.',
    'Después de crear tu cuenta, iOS te va a preguntar por cada tipo de '
        'dato. Puedes quitar el permiso cuando quieras en Ajustes › Salud › '
        'Acceso a datos y dispositivos › +Vida. Sin acceso a tus pasos no '
        'podemos darte puntos.',
  ]),
  SeccionTerminos('Para qué usamos tus datos', [
    'Con tus pasos calculamos tus puntos de cada día. Con tu ritmo cardíaco '
        'y tus entrenamientos reconocemos cuándo entrenaste con intensidad, '
        'que también da puntos, y contamos los minutos de tus objetivos de '
        'la semana.',
    'Si usas un reloj, sus datos tienen prioridad sobre los del teléfono '
        'ese día. Nunca sumamos los dos: así un mismo paso no cuenta doble.',
    'No usamos herramientas de publicidad ni de análisis de terceros sobre '
        'tus datos de Salud, y no los usamos para nada distinto de lo que '
        'dice acá.',
  ]),
  SeccionTerminos('Tu edad', [
    'Tu fecha de nacimiento ajusta cómo medimos la intensidad de tu '
        'ejercicio, para que un entrenamiento cuente según lo que es '
        'intenso para alguien de tu edad. También define con quién compites '
        'en La Liga, que se arma por grupos de edad.',
    'Cuando vinculas tu póliza, tu aseguradora confirma tu fecha de '
        'nacimiento. Si coincide, conservas todos los puntos y monedas que '
        'hayas ganado. Si no coincide, empiezas de cero desde el día en que '
        'la vinculas.',
  ]),
  SeccionTerminos('Lo que ve tu aseguradora', [
    'Solo si lo autorizas aparte, en su propia pantalla, le mandamos a tu '
        'aseguradora un resumen de cada día: tus pasos totales del día, tu '
        'ritmo cardíaco promedio del día y los entrenamientos que hiciste.',
    'Nunca le mandamos el detalle minuto a minuto ni los registros sueltos '
        'de Salud.',
    'Puedes quitar esa autorización cuando quieras desde Perfil.',
  ]),
  SeccionTerminos('Lo que ven otros usuarios', [
    'En La Liga y en Tus Ligas los demás participantes ven tu nombre y tu '
        'posición en la tabla. Nunca ven tus datos de Salud.',
  ]),
  SeccionTerminos('Puntos y niveles', [
    'Tus puntos nunca se gastan: definen tu nivel del año, del 0 al 4, y '
        'con él el porcentaje de cashback.',
    'Hay un máximo de puntos por día y un máximo por año.',
    'Aceptamos datos que lleguen tarde hasta 14 días después. Revisamos los '
        'datos que se salen de lo normal, y los puntos se pueden corregir '
        'hasta 2 semanas después de acreditados.',
  ]),
  SeccionTerminos('Cashback', [
    'El cashback es dinero que se te devuelve DESPUÉS de pagar tu prima. '
        'Nunca es un descuento sobre la prima.',
    'Necesitas una póliza vinculada y verificada para recibirlo.',
  ]),
  SeccionTerminos('Monedas y premios', [
    'Ganas monedas cuando cumples los dos objetivos de la semana y cuando '
        'quedas entre los 3 primeros de La Liga. Se canjean por premios en '
        'la tienda.',
    'Cada moneda dura 90 días desde que la ganas. Puedes juntar hasta 100: '
        'lo que pase de 100 se pierde.',
    'Un cupón canjeado dura 60 días desde que lo canjeas.',
    'Sin póliza verificada ganas monedas igual, pero no las puedes canjear.',
  ]),
  SeccionTerminos('Uso justo', [
    'Los puntos tienen que salir de tu propia actividad. Si detectamos '
        'datos alterados, cuentas compartidas o cualquier forma de hacer '
        'trampa, podemos quitar los puntos, las monedas y los premios que '
        'salieron de ahí.',
  ]),
  SeccionTerminos('Tu información es tuya', [
    'Puedes pedir que borremos tu cuenta y todos tus datos cuando quieras.',
    'Si cambiamos estos términos, te lo vamos a avisar en la app antes de '
        'que empiecen a regir.',
  ]),
];

class HojaTerminos extends StatelessWidget {
  const HojaTerminos({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BarritaHoja(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Términos y condiciones', style: AppTheme.display(24)),
                  const SizedBox(height: 6),
                  Text(
                    'Incluye el aviso de privacidad y el permiso de Salud · '
                    'Versión del 30 de septiembre de 2026',
                    style: tema.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: AppColors.separador),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                itemCount: seccionesTerminos.length,
                itemBuilder: (context, i) {
                  final s = seccionesTerminos[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.grupo),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // El número en azul medio: ordena sin pesar
                            // más que el título.
                            SizedBox(
                              width: 26,
                              child: Text(
                                '${i + 1}',
                                style: AppTheme.display(
                                  15,
                                ).copyWith(color: AppColors.azulMedio),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.titulo,
                                style: tema.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final p in s.parrafos)
                          Padding(
                            padding: const EdgeInsets.only(left: 26, bottom: 8),
                            child: Text(
                              p,
                              style: tema.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: BotonPildora(
                texto: 'Entendido',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
