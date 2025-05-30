import 'package:flutter/material.dart';

class FastConnectionButton extends StatelessWidget {
  /// Fungsi yang akan dipanggil ketika tombol ditekan
  final VoidCallback onPressed;

  /// Teks yang akan ditampilkan pada tombol
  final String text;

  /// Warna latar belakang tombol
  final Color backgroundColor;

  /// Warna teks dan ikon
  final Color foregroundColor;

  /// Icon yang akan ditampilkan
  final IconData iconData;

  /// Radius sudut tombol
  final double borderRadius;

  /// Padding horizontal tombol
  final double horizontalPadding;

  /// Padding vertikal tombol
  final double verticalPadding;

  const FastConnectionButton({
    super.key,
    required this.onPressed,
    this.text = "Fast Connection",
    this.backgroundColor = Colors.orange,
    this.foregroundColor = Colors.white,
    this.iconData = Icons.flash_on,
    this.borderRadius = 12.0,
    this.horizontalPadding = 20.0,
    this.verticalPadding = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(iconData, color: foregroundColor),
      label: Text(
        text,
        style: TextStyle(color: foregroundColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
      ),
      onPressed: onPressed,
    );
  }
}
