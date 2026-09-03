import 'package:flutter/material.dart';

/// Marco decorativo estilo iPhone 17 Pro Max, solo para previsualizar la
/// app "como celular" cuando se corre en Web/desktop. No se usa en el
/// build real de iOS (ahí la app ya corre a pantalla completa).
class IPhoneFrame extends StatelessWidget {
  const IPhoneFrame({super.key, required this.child});

  final Widget child;

  static const double _screenWidth = 430;
  static const double _screenHeight = 932;
  static const double _bezelWidth = 14;
  static const double _outerRadius = 66;

  @override
  Widget build(BuildContext context) {
    const outerWidth = _screenWidth + _bezelWidth * 2;
    const outerHeight = _screenHeight + _bezelWidth * 2;
    const innerRadius = _outerRadius - _bezelWidth;

    return SizedBox(
      width: outerWidth,
      height: outerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bezel / chasis metálico.
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(_outerRadius),
              border: Border.all(color: const Color(0xFF3A3A3C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 50,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),

          // Pantalla (contenido real de la app).
          Positioned(
            left: _bezelWidth,
            top: _bezelWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: SizedBox(
                width: _screenWidth,
                height: _screenHeight,
                child: Stack(
                  children: [
                    Positioned.fill(child: child),
                    // Home indicator.
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 140,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dynamic Island.
          const Positioned(
            top: _bezelWidth + 11,
            left: 0,
            right: 0,
            child: Center(child: _DynamicIsland()),
          ),

          // Botones laterales (decorativos).
          const Positioned(
            left: -2,
            top: outerHeight * 0.16,
            child: _SideButton(height: 30),
          ),
          const Positioned(
            left: -2,
            top: outerHeight * 0.23,
            child: _SideButton(height: 58),
          ),
          const Positioned(
            left: -2,
            top: outerHeight * 0.31,
            child: _SideButton(height: 58),
          ),
          const Positioned(
            right: -2,
            top: outerHeight * 0.21,
            child: _SideButton(height: 92),
          ),
        ],
      ),
    );
  }
}

class _DynamicIsland extends StatelessWidget {
  const _DynamicIsland();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 37,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
