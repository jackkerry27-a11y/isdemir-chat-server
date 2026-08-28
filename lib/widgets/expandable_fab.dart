import 'package:flutter/material.dart';
import 'dart:math' as math;

class ExpandableFab extends StatefulWidget {
  final double distance;
  final List<ActionButton> children;

  const ExpandableFab({
    super.key,
    this.distance = 100.0,
    required this.children,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300, // Menünün taşmaması için geniş bir alan
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          _buildTapToCloseFab(),
          ..._buildExpandingActionButtons(),
          _buildTapToOpenFab(),
        ],
      ),
    );
  }

  Widget _buildTapToCloseFab() {
    return Positioned(
      bottom: 25, // Docked FAB ile hizalamak için biraz yukarıda
      child: SizedBox(
        width: 56.0,
        height: 56.0,
        child: Center(
          child: Material(
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 4.0,
            child: InkWell(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.close,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    // Eğer 3 buton varsa açılar: -150, -90, -30 veya -135, -90, -45 (Radyan cinsinden)
    // Yelpaze için başlangıç ve bitiş açılarını (derece olarak) ayarlayalım.
    // 0 derece sağ, -90 yukarı, -180 soldur.
    const double startAngle = -160.0;
    const double endAngle = -20.0;
    final double step = (endAngle - startAngle) / (count - 1);

    for (int i = 0; i < count; i++) {
      final double angle = startAngle + (i * step);
      children.add(
        _ExpandingActionButton(
          directionInDegrees: angle,
          maxDistance: widget.distance,
          progress: _expandAnimation,
          child: widget.children[i],
        ),
      );
    }
    return children;
  }

  Widget _buildTapToOpenFab() {
    return Positioned(
      bottom: 25, // BottomNavigationBar ile senkronize etmek için bottom offset
      child: IgnorePointer(
        ignoring: _open,
        child: AnimatedContainer(
          transformAlignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            _open ? 0.7 : 1.0,
            _open ? 0.7 : 1.0,
            1.0,
          ),
          duration: const Duration(milliseconds: 250),
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          child: AnimatedOpacity(
            opacity: _open ? 0.0 : 1.0,
            curve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
            duration: const Duration(milliseconds: 250),
            child: FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: const Color(0xFF4338CA),
              shape: const CircleBorder(),
              elevation: 8,
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandingActionButton extends StatelessWidget {
  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  const _ExpandingActionButton({
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (math.pi / 180.0),
          progress.value * maxDistance,
        );
        return Positioned(
          bottom: 25 + 28, // Merkez
          child: Transform.translate(
            offset: offset,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5), // Merkeze hizala
              child: Transform.scale(
                scale: progress.value,
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;

  const ActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.iconColor = Colors.white,
    this.backgroundColor = const Color(0xFF1A202C),
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          color: backgroundColor,
          elevation: 6.0,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: iconColor),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}
