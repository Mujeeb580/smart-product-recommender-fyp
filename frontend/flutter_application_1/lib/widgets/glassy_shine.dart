import 'dart:math' as math;
import 'package:flutter/material.dart';

class GlassyShine extends StatefulWidget {
  final double opacity;

  const GlassyShine({super.key, this.opacity = 0.18});

  @override
  State<GlassyShine> createState() => _GlassyShineState();
}

class _GlassyShineState extends State<GlassyShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final dx = (t * 2 - 1) * MediaQuery.of(context).size.width;
          return Transform.translate(
            offset: Offset(dx, -80),
            child: Transform.rotate(
              angle: -math.pi / 12,
              child: Opacity(
                opacity: widget.opacity,
                child: Container(
                  width: MediaQuery.of(context).size.width * 1.6,
                  height: MediaQuery.of(context).size.height * 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.2, 0.5, 0.8],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
