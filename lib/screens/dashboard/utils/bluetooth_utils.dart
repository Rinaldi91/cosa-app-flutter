import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String glucoseService = '00001808-0000-1000-8000-00805f9b34fb';
const String glucoseServiceUuid = "00001808-0000-1000-8000-00805f9b34fb";
const String glucoseMeasurementUuid = "00002A18-0000-1000-8000-00805f9b34fb";

// Di bagian atas file bluetooth_utils.dart, ubah format UUID
final GLUCOSE_SERVICE = '1808'; // Shortened version
final GLUCOSE_MEASUREMENT = '2a18'; // Shortened version
final GLUCOSE_CONTEXT = '2a34'; // Shortened version

class GlucoseReading {
  final int sequenceNumber;
  final DateTime timestamp;
  final int glucoseValue;
  final String unit;
  final String formattedTimestamp;
  final String mealContext;

  GlucoseReading({
    required this.sequenceNumber,
    required this.timestamp,
    required this.glucoseValue,
    required this.unit,
    required this.formattedTimestamp,
    required this.mealContext,
  });

  get value => null;

  @override
  String toString() {
    return 'GlucoseReading(sequenceNumber: $sequenceNumber, timestamp: $timestamp, glucoseValue: $glucoseValue $unit, mealContext: $mealContext)';
  }
}

class BluetoothUtils {
  static StreamSubscription? _scanSubscription;
  static get math => null;

  static Future<void> checkPermissions() async {
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
  }

  // Fungsi helper untuk UUID
  static String normalizeUUID(String uuid) {
    uuid = uuid.toLowerCase().replaceAll('-', '');
    if (uuid.length == 4) {
      return '0000$uuid-0000-1000-8000-00805f9b34fb';
    }
    return uuid;
  }

  static Future<void> checkDeviceConnection(
    BluetoothDevice? device, {
    required VoidCallback onDisconnected,
  }) async {
    if (device != null) {
      try {
        final isConnected = device.isConnected;
        if (!isConnected) {
          onDisconnected();
        }
      } catch (e) {
        onDisconnected();
      }
    }
  }

  static void showDisconnectionSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device disconnected'),
        backgroundColor: Colors.red,
      ),
    );
  }

  static void showConnectionSuccessSnackBar(
      BuildContext context, String deviceName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connected to $deviceName'),
        backgroundColor: Colors.green,
      ),
    );
  }

  static void showConnectionErrorSnackBar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection failed: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  static Future<void> scanAndShowDialog(
    BuildContext context, {
    required Function(BluetoothDevice device, bool isContourDevice)
        onDeviceSelected,
  }) async {
    await checkPermissions();
    await _showDeviceSelectionDialog(context, onDeviceSelected);
  }

  static Future<void> _showDeviceSelectionDialog(
    BuildContext context,
    Function(BluetoothDevice device, bool isContourDevice) onDeviceSelected,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return DeviceSelectionDialog(
          onDeviceSelected: onDeviceSelected,
        );
      },
    );
  }

  static Future<List<ScanResult>> performScan() async {
    List<ScanResult> scanResults = [];

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        scanResults =
            results.where((result) => result.device.name.isNotEmpty).toList();
      });

      await Future.delayed(const Duration(seconds: 5));
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();

      return scanResults;
    } catch (e) {
      debugPrint("Scan error: $e");
      return [];
    }
  }

  static Future<void> readGlucoseData(
      BluetoothDevice device, Function(GlucoseReading) onDataReceived) async {
    try {
      debugPrint('Starting glucose service discovery...');
      List<BluetoothService> services = await device.discoverServices();

      // Cari karakteristik glukosa (2a18)
      BluetoothCharacteristic? glucoseChar;
      for (var service in services) {
        debugPrint('Checking service: ${service.uuid}');
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase().contains('2a18')) {
            debugPrint('Found glucose characteristic: ${char.uuid}');
            glucoseChar = char;
            break;
          }
        }
        if (glucoseChar != null) break;
      }

      if (glucoseChar == null) {
        debugPrint('Glucose characteristic not found!');
        return;
      }

      // Setup notifikasi untuk karakteristik glukosa
      await setupGlucoseNotification(
          glucoseChar as BluetoothDevice, onDataReceived);
    } catch (e) {
      debugPrint('Error in readGlucoseData: $e');
    }
  }

  static GlucoseReading parseGlucoseData(List<int> rawData) {
    try {
      // Menampilkan data byte mentah untuk debugging
      debugPrint('Raw Data Bytes: $rawData');

      final buffer = Uint8List.fromList(rawData).buffer;
      final dataView = ByteData.view(buffer);

      // Flags byte menentukan format data yang tersedia
      final flags = dataView.getUint8(0);
      debugPrint('Flags (binary): ${flags.toRadixString(2).padLeft(8, '0')}');
      int offset = 1;

      // Sequence Number (2 bytes, Little Endian)
      final sequenceNumber = dataView.getUint16(offset, Endian.little);
      offset += 2;

      // Base Time (7 bytes)
      final baseYear = dataView.getUint16(offset, Endian.little);
      final month =
          dataView.getUint8(offset + 2) - 1; // Month is 0-based in DateTime
      final day = dataView.getUint8(offset + 3);
      final hours = dataView.getUint8(offset + 4);
      final minutes = dataView.getUint8(offset + 5);
      final seconds = dataView.getUint8(offset + 6);
      debugPrint(
          'Decoded Timestamp from device: {baseYear: $baseYear, month: ${month + 1}, day: $day, hours: $hours, minutes: $minutes, seconds: $seconds}');
      offset += 7;
      // Parse glucose concentration - nilai glukosa ada pada posisi offset = 12 (byte ke-12)
      int glucoseValue;
      if ((flags & 0x01) != 0) {
        // Berdasarkan kode Next.js dan data debug, nilai glukosa ada di byte ke-12
        glucoseValue = dataView
            .getUint8(offset + 2); // Offset +2 untuk menuju ke byte ke-12
        offset += 3; // Sesuaikan offset untuk mencapai meal marker
      } else {
        glucoseValue = 0;
      }

      debugPrint('Glucose Value: $glucoseValue');

      // Parse meal context
      String mealContext = 'no-meal';
      if (offset < rawData.length) {
        final mealMarker = dataView.getUint8(offset);
        debugPrint(
            'Meal Marker Raw Byte: ${mealMarker.toRadixString(2).padLeft(8, '0')}');
        final mealBits = (mealMarker >> 6) & 0x03;
        switch (mealBits) {
          case 0x02:
            mealContext = 'pre-meal';
            break;
          case 0x03:
            mealContext = 'post-meal';
            break;
          default:
            mealContext = 'no-meal';
        }

        debugPrint('Meal Context: $mealContext');
      }

      // Buat timestamp UTC dari data alat
      DateTime timestamp =
          DateTime.utc(baseYear, month + 1, day, hours, minutes, seconds);
      debugPrint('Original device timestamp (UTC): ${timestamp.toString()}');

      // Koreksi waktu: kurangi 7 menit dari waktu alat
      // Ini akan menghasilkan waktu yang sesuai dengan yang ditampilkan di alat
      timestamp = timestamp.subtract(const Duration(minutes: 7));
      debugPrint(
          'Timestamp after -7 minute correction: ${timestamp.toString()}');

      // Ubah ke zona waktu Jakarta (UTC+7)
      final indonesiaTime = timestamp.toUtc().add(const Duration(hours: 7));
      debugPrint('Local timestamp (Jakarta): ${indonesiaTime.toString()}');

      // Format timestamp untuk Indonesia dengan format 24 jam
      final formattedTimestamp =
          DateFormat('dd/MM/yyyy HH:mm:ss', 'id_ID').format(indonesiaTime);
      debugPrint('Formatted Timestamp (Jakarta): $formattedTimestamp');

      return GlucoseReading(
        sequenceNumber: sequenceNumber,
        timestamp: indonesiaTime,
        glucoseValue: glucoseValue,
        unit: 'mg/dL',
        formattedTimestamp: formattedTimestamp,
        mealContext: mealContext,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing glucose data: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to parse glucose data: $e');
    }
  }

  static Future<void> setupGlucoseNotification(BluetoothDevice device,
      Function(GlucoseReading) onReadingReceived) async {
    try {
      debugPrint('Setting up glucose notifications for ${device.id}');

      // Connect to device if not connected
      if (device.state != BluetoothDeviceState.connected) {
        await device.connect();
        // Tambahkan delay setelah koneksi
        await Future.delayed(const Duration(seconds: 2));
      }

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find glucose service dengan normalisasi UUID
      BluetoothService? glucoseService;
      String targetUUID = normalizeUUID(GLUCOSE_SERVICE);

      for (var service in services) {
        String serviceUUID = service.uuid.toString().toLowerCase();
        developer
            .log('Checking service: $serviceUUID against target: $targetUUID');

        if (serviceUUID.contains('1808')) {
          glucoseService = service;
          debugPrint('Found glucose service: ${service.uuid}');
          break;
        }
      }

      if (glucoseService == null) {
        throw Exception(
            'Glucose service not found. Available services: ${services.map((s) => s.uuid.toString()).join(", ")}');
      }

      // Find glucose measurement characteristic
      BluetoothCharacteristic? glucoseCharacteristic;
      for (var characteristic in glucoseService.characteristics) {
        String charUUID = characteristic.uuid.toString().toLowerCase();
        if (charUUID.contains('2a18')) {
          glucoseCharacteristic = characteristic;
          debugPrint(
              'Found glucose measurement characteristic: ${characteristic.uuid}');
          break;
        }
      }

      if (glucoseCharacteristic == null) {
        throw Exception('Glucose measurement characteristic not found');
      }

      // Setup notifications with retry mechanism
      int retryCount = 0;
      while (retryCount < 3) {
        try {
          await glucoseCharacteristic.setNotifyValue(false);
          await Future.delayed(const Duration(milliseconds: 500));
          await glucoseCharacteristic.setNotifyValue(true);
          debugPrint('Glucose notifications enabled');
          break;
        } catch (e) {
          retryCount++;
          debugPrint('Retry $retryCount: Error enabling notifications: $e');
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // Listen for notifications
      glucoseCharacteristic.value.listen(
        (List<int> rawData) {
          try {
            if (rawData.isNotEmpty) {
              GlucoseReading? reading = parseGlucoseData(rawData);
              debugPrint('New glucose reading: $reading');
              onReadingReceived(reading);
            }
          } catch (e) {
            debugPrint('Error parsing glucose data: $e');
          }
        },
        onError: (error) {
          debugPrint('Error in glucose notification stream: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error setting up glucose notifications: $e');
      rethrow;
    }
  }
}

class DeviceSelectionDialog extends StatefulWidget {
  final Function(BluetoothDevice device, bool isContourDevice) onDeviceSelected;

  const DeviceSelectionDialog({
    super.key,
    required this.onDeviceSelected,
  });

  @override
  State<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<DeviceSelectionDialog> {
  List<ScanResult> scanResults = [];
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    _startInitialScan();
  }

  Future<void> _startInitialScan() async {
    setState(() => isScanning = true);
    final results = await BluetoothUtils.performScan();
    if (mounted) {
      setState(() {
        scanResults = results;
        isScanning = false;
      });
    }
  }

  Future<void> _refreshScan() async {
    setState(() => isScanning = true);
    final results = await BluetoothUtils.performScan();
    if (mounted) {
      setState(() {
        scanResults = results;
        isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    // Buat dialog lebih responsif dengan lebar maksimum
    final dialogWidth =
        min(size.width * 0.85, 600.0); // Lebar maksimum untuk tablet

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      backgroundColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        // Gunakan SingleChildScrollView untuk menghindari overflow
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul yang responsif
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bluetooth_searching,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Select Bluetooth Device",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Area konten dengan tinggi dan lebar responsif
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      dialogWidth - 40, // Sesuaikan lebar konten dengan dialog
                ),
                child: Container(
                  height: min(
                      size.height * 0.4, 320.0), // Tinggi maksimum disesuaikan
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isScanning
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Scanning for devices...",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : scanResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bluetooth_disabled,
                                    size: 36,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No devices found",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: scanResults.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                indent: 8,
                                endIndent: 8,
                                color:
                                    theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              itemBuilder: (context, index) {
                                final device = scanResults[index].device;
                                final bool isContourDevice = device.name
                                    .toLowerCase()
                                    .contains('contour');

                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isContourDevice
                                          ? Colors
                                              .green // Ubah warna background menjadi hijau untuk Contour
                                          : theme.colorScheme.surfaceVariant,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.bluetooth,
                                      size: 16,
                                      color: isContourDevice
                                          ? Colors
                                              .white // Ikon putih untuk background hijau
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  title: Text(
                                    device.name.isEmpty
                                        ? "Unnamed Device"
                                        : device.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    device.id.toString(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isContourDevice
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Colors
                                              .green, // Warna ikon checklist menjadi hijau
                                          size: 16,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onDeviceSelected(
                                        device, isContourDevice);
                                  },
                                );
                              },
                            ),
                ),
              ),
              const SizedBox(height: 20),
              // Tombol dengan layout yang responsif
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Posisikan tombol di tengah
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close,
                        size: 16, color: theme.colorScheme.error),
                    label: Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.error),
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: isScanning ? null : _refreshScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(Icons.refresh, size: 16, color: Colors.white),
                    label: Text('Rescan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Widget build(BuildContext context) {
  //   return AlertDialog(
  //     title: const Text("Select Bluetooth Device"),
  //     content: SizedBox(
  //       height: 200,
  //       width: 300,
  //       child: isScanning
  //           ? const Center(
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   CircularProgressIndicator(),
  //                   SizedBox(height: 16),
  //                   Text("Scanning for devices..."),
  //                 ],
  //               ),
  //             )
  //           : scanResults.isEmpty
  //               ? const Center(
  //                   child: Text("No devices found"),
  //                 )
  //               : ListView.builder(
  //                   itemCount: scanResults.length,
  //                   itemBuilder: (context, index) {
  //                     final device = scanResults[index].device;
  //                     final bool isContourDevice =
  //                         device.name.toLowerCase().contains('contour');

  //                     return ListTile(
  //                       title: Text(
  //                         device.name,
  //                         style: const TextStyle(fontWeight: FontWeight.bold),
  //                       ),
  //                       subtitle: Text(device.id.toString()),
  //                       trailing: isContourDevice
  //                           ? const Icon(Icons.check_circle,
  //                               color: Colors.green)
  //                           : null,
  //                       onTap: () {
  //                         Navigator.of(context).pop();
  //                         widget.onDeviceSelected(device, isContourDevice);
  //                       },
  //                     );
  //                   },
  //                 ),
  //     ),
  //     actions: [
  //       TextButton(
  //         onPressed: () => Navigator.of(context).pop(),
  //         child: const Text('Cancel'),
  //       ),
  //       TextButton(
  //         onPressed: isScanning ? null : _refreshScan,
  //         child: const Text('Scan Again'),
  //       ),
  //     ],
  //   );
  // }
}
