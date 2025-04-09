import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanButton extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onScan;

  const ScanButton(
      {super.key, required this.isConnected, required this.onScan});

  Future<void> _checkBluetooth(BuildContext context) async {
    // Cek permission Bluetooth terlebih dahulu
    var bluetoothStatus = await Permission.bluetooth.status;
    var bluetoothConnectStatus = await Permission.bluetoothConnect.status;
    var bluetoothScanStatus = await Permission.bluetoothScan.status;

    // Jika belum mendapat izin, minta izin dulu
    if (!bluetoothStatus.isGranted ||
        !bluetoothConnectStatus.isGranted ||
        !bluetoothScanStatus.isGranted) {
      await Permission.bluetooth.request();
      await Permission.bluetoothConnect.request();
      await Permission.bluetoothScan.request();
    }

    // Mengambil status terbaru dari Bluetooth adapter
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;

    if (state != BluetoothAdapterState.on) {
      try {
        // Mencoba mengaktifkan Bluetooth secara langsung
        await FlutterBluePlus.turnOn();
        // Tunggu sampai Bluetooth benar-benar aktif
        await Future.delayed(const Duration(seconds: 2));
        onScan();
      } catch (e) {
        // Jika gagal mengaktifkan secara langsung, tampilkan dialog
        if (context.mounted) {
          _showBluetoothDialog(context);
        }
      }
    } else {
      onScan();
    }
  }

  void _showBluetoothDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Bluetooth Activation Failed"),
        content: const Text("Cannot turn on Bluetooth automatically. "
            "Please enable Bluetooth manually via settings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(
          Icons.search,
          color: Colors.white,
          size: 24,
        ),
        label: const Text(
          'Scan Device',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 255, 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _checkBluetooth(context),
      ),
    );
  }
}
