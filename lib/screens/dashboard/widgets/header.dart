import 'dart:math';
import 'package:cosaapp/screens/dashboard/utils/greeting_utils.dart';
import 'package:flutter/material.dart';

class DashboardHeader extends StatefulWidget {
  final String username;

  const DashboardHeader({super.key, required this.username});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create a rotation animation that goes from 0 to 2π (360 degrees)
    _animation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Schedule periodic animations to occur randomly
    _scheduleNextAnimation();
  }

  void _scheduleNextAnimation() {
    // Generate a random delay between 5-15 seconds before next animation
    final int randomDelay = 5000 + Random().nextInt(10000);

    Future.delayed(Duration(milliseconds: randomDelay), () {
      if (mounted) {
        _controller.reset();
        _controller.forward().then((_) {
          _scheduleNextAnimation();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final double logoSize = isSmallScreen ? 80 : 110;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min, // Mengurangi jarak antar elemen
                children: [
                  Text(
                    GreetingUtils.getGreeting(),
                    style: const TextStyle(
                      fontSize:
                          16, // Ukuran font sedikit lebih kecil agar lebih rapat
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(
                      width: 4), // Mengurangi jarak antara teks dan ikon
                  Icon(
                    GreetingUtils.getGreetingIcon(),
                    color: Colors.orange,
                    size:
                        20, // Ukuran ikon sedikit lebih kecil agar lebih seimbang
                  ),
                ],
              ),
              Text(
                'Hi, ${widget.username}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          // Animated logo using AnimatedBuilder
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Adds perspective
                  ..rotateY(_animation
                      .value), // Rotate around Y axis for coin flip effect
                child: child,
              );
            },
            child: Image.asset(
              'assets/images/cosaapp.png',
              width: logoSize,
              height: logoSize,
            ),
          ),
        ],
      ),
    );
  }
}
