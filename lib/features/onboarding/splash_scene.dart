import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// First screen: wordmark fades in while a hairline draws across, ~1.5s total,
/// then calls [onDone]. No external packages.
class SplashScene extends StatefulWidget {
  const SplashScene({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScene> createState() => _SplashSceneState();
}

class _SplashSceneState extends State<SplashScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final Animation<double> _logo = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
  );

  late final Animation<double> _line = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.35, 1.0, curve: Curves.easeInOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _logo.value,
                  child: Text(
                    'Akiba',
                    style: TextStyle(
                      fontFamily: AkibaFonts.sans,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: c.text,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // The drawn line.
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: _line.value.clamp(0.0, 1.0),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
