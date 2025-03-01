import 'package:cosaapp/screens/dashboard/utils/greeting_utils.dart';
import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final String username;

  const DashboardHeader({super.key, required this.username});

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
                'Hi, $username',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          Image.asset(
            'assets/images/cosaapp.png',
            width: logoSize,
            height: logoSize,
          ),
        ],
      ),
    );
  }
}
