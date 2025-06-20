import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String glucoseStatus;
  final String deviceStatusIndicator;

  GlucoseReading(
      {required this.sequenceNumber,
      required this.timestamp,
      required this.glucoseValue,
      required this.unit,
      required this.formattedTimestamp,
      required this.mealContext,
      required this.glucoseStatus,
      required this.deviceStatusIndicator});

  @override
  String toString() {
    return 'GlucoseReading{'
        'sequenceNumber: $sequenceNumber, '
        'timestamp: $timestamp, '
        'glucoseValue: $glucoseValue, '
        'unit: $unit, '
        'formattedTimestamp: $formattedTimestamp, '
        'mealContext: $mealContext,'
        'mealContext: $glucoseStatus,'
        'deviceStatusIndicator: $deviceStatusIndicator'
        '}';
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
    // Hapus snackbar yang sedang ditampilkan (jika ada)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Tampilkan snackbar disconnection yang lebih modern
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 6.0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Disconnected.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Connection with the device has been lost.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showConnectionSuccessSnackBar(
      BuildContext context, String deviceName) {
    // Hapus snackbar yang sedang ditampilkan (jika ada)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Tampilkan snackbar yang lebih modern
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 6.0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.bluetooth_connected,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Success',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    deviceName,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade800,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showConnectionErrorSnackBar(BuildContext context, String error) {
    // Hapus snackbar yang sedang ditampilkan (jika ada)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Tampilkan snackbar error yang lebih modern
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 6.0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Filed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    error,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Close',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
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

  // Fungsi untuk parsing data glukosa
  static GlucoseReading parseGlucoseData(List<int> rawData) {
    try {
      debugPrint('Raw Data Bytes: $rawData');
      debugPrint('Raw Data Length: ${rawData.length}');

      final buffer = Uint8List.fromList(rawData).buffer;
      final dataView = ByteData.view(buffer);

      final flags = dataView.getUint8(0);
      debugPrint('Flags (binary): ${flags.toRadixString(2).padLeft(8, '0')}');
      int offset = 1;

      final sequenceNumber = dataView.getUint16(offset, Endian.little);
      debugPrint('Sequence Number: $sequenceNumber');
      offset += 2;

      final baseYear = dataView.getUint16(offset, Endian.little);
      final month = dataView.getUint8(offset + 2) - 1;
      final day = dataView.getUint8(offset + 3);
      final hours = dataView.getUint8(offset + 4);
      final minutes = dataView.getUint8(offset + 5);
      final seconds = dataView.getUint8(offset + 6);
      debugPrint(
          'Decoded Timestamp from device: {baseYear: $baseYear, month: ${month + 1}, day: $day, hours: $hours, minutes: $minutes, seconds: $seconds}');
      offset += 7;

      int glucoseValue = 0;
      String glucoseStatus;
      String deviceStatusIndicator = 'Unknown'; // Default status indicator

      if ((flags & 0x01) != 0) {
        if (offset + 2 < rawData.length) {
          debugPrint(
              'Byte at offset $offset: ${dataView.getUint8(offset)} (0x${dataView.getUint8(offset).toRadixString(16)})');
          debugPrint(
              'Byte at offset ${offset + 1}: ${dataView.getUint8(offset + 1)} (0x${dataView.getUint8(offset + 1).toRadixString(16)})');
          debugPrint(
              'Byte at offset ${offset + 2}: ${dataView.getUint8(offset + 2)} (0x${dataView.getUint8(offset + 2).toRadixString(16)})');

          final baseValueSfloat =
              dataView.getUint16(offset, Endian.little); // 401
          final typeAndLocationByte =
              dataView.getUint8(offset + 2); // 121, 131, 132

          debugPrint('Base value (SFLOAT 16-bit LE): $baseValueSfloat');
          debugPrint('Type and Location byte: $typeAndLocationByte');

          // --- LOG UNTUK MENGIDENTIFIKASI ICON STATUS ---
          // Kita asumsikan byte indikator berada di rawData[13]
          final statusIndicatorByteOffset =
              offset + 3; // Mengarah ke rawData[13]
          int statusIndicatorByte = 0;

          if (statusIndicatorByteOffset < rawData.length) {
            statusIndicatorByte = dataView.getUint8(statusIndicatorByteOffset);
            debugPrint(
                '**STATUS INDICATOR BYTE (rawData[13]): ${statusIndicatorByte} (0x${statusIndicatorByte.toRadixString(16).toUpperCase()})**');
            debugPrint(
                '**STATUS INDICATOR BINARY: ${statusIndicatorByte.toRadixString(2).padLeft(8, '0')}**');

            final bit0 = statusIndicatorByte & 0x01; // Ambil bit 0
            final bit1 = (statusIndicatorByte >> 1) & 0x01; // Ambil bit 1
            final bit2 = (statusIndicatorByte >> 2) & 0x01; // Ambil bit 2
            debugPrint('Bit 0: $bit0');
            debugPrint('Bit 1: $bit1');
            debugPrint('Bit 2: $bit2');

            // --- LOGIKA PERBAIKAN FINAL UNTUK PENENTUAN STATUS ICON DAN NILAI GLUKOSA ---
            if (statusIndicatorByte == 0xB1) {
              // 177 desimal -> Indikator "Panah Atas (High)"
              glucoseValue = baseValueSfloat + typeAndLocationByte - 145;
              deviceStatusIndicator = 'Panah Atas (High)';
              debugPrint(
                  'Mengambil Nilai Tinggi (HI) berdasarkan indikator: $glucoseValue');
            } else if (statusIndicatorByte == 0xB0) {
              // 176 desimal -> Indikator "Ceklist (Normal)"
              glucoseValue = typeAndLocationByte;
              deviceStatusIndicator = 'Ceklist (Normal)';
              debugPrint(
                  'Mengambil Nilai Normal berdasarkan indikator: $glucoseValue');
            } else {
              // Ini adalah tempat untuk menambahkan kondisi "LOW" setelah Anda mendapatkan lognya
              // Saat ini, asumsikan ini sebagai LOW atau kondisi lain yang tidak dikenal.
              // Jika Anda mendapatkan log LOW dan statusIndicatorByte-nya berbeda,
              // tambahkan 'else if (statusIndicatorByte == YOUR_LOW_VALUE)' di sini.
              glucoseValue =
                  typeAndLocationByte; // Ambil nilai normal secara default
              deviceStatusIndicator =
                  'Panah Bawah (Low) atau Tidak Dikenal'; // Default atau jika belum teridentifikasi
              debugPrint(
                  'Indikator LOW/Tidak Dikenal, mengambil nilai normal secara default: $glucoseValue');
            }
            // --- AKHIR LOGIKA PERBAIKAN FINAL ---
          } else {
            glucoseValue = 0; // Handle jika statusIndicatorByte tidak ada
            deviceStatusIndicator = 'No Indicator Byte';
          }

          offset += 3; // Maju 2 byte SFLOAT + 1 byte Type & Location
          offset +=
              1; // Maju 1 byte untuk statusIndicatorByte / Meal Marker Raw Byte
        } else {
          glucoseValue = 0;
          deviceStatusIndicator = 'Data length too short for glucose';
        }
      }

      debugPrint('Final Glucose Value: $glucoseValue mg/dL');

      // Tentukan status glukosa berdasarkan final glucoseValue (ini adalah status rentang)
      if (glucoseValue < 70) {
        glucoseStatus = 'Low';
      } else if (glucoseValue >= 70 && glucoseValue <= 140) {
        glucoseStatus = 'Normal';
      } else if (glucoseValue > 140 && glucoseValue <= 200) {
        glucoseStatus = 'Elevated';
      } else {
        glucoseStatus = 'High';
      }
      debugPrint('Glucose Status (by range): $glucoseStatus');
      debugPrint('Device Status Indicator (by icon): $deviceStatusIndicator');

      // Parse meal context (ini terpisah dari logika penentuan nilai HIGH/NORMAL)
      String mealContext = 'no-meal';
      if (offset < rawData.length) {
        // Karena kita sudah membaca byte ini di statusIndicatorByte,
        // kita bisa menggunakannya kembali tanpa membaca ulang dari dataView.
        // Asumsi rawData[13] adalah byte yang kita pakai untuk meal context.
        final mealMarkerRawForContext =
            dataView.getUint8(13); // Langsung ambil dari rawData[13]
        debugPrint(
            'Meal Marker Raw Byte for Context (from rawData[13]): 0x${mealMarkerRawForContext.toRadixString(16).toUpperCase()}');
        debugPrint(
            'Meal Marker Binary for Context: ${mealMarkerRawForContext.toRadixString(2).padLeft(8, '0')}');

        final mealBits = (mealMarkerRawForContext >> 6) & 0x03;
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

      DateTime timestamp =
          DateTime.utc(baseYear, month + 1, day, hours, minutes, seconds);
      debugPrint('Original device timestamp (UTC): ${timestamp.toString()}');

      timestamp = timestamp.subtract(const Duration(minutes: 17));
      debugPrint(
          'Timestamp after -17 minute correction: ${timestamp.toString()}');

      final indonesiaTime = timestamp.toUtc().add(const Duration(hours: 7));
      debugPrint('Local timestamp (Jakarta): ${indonesiaTime.toString()}');

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
        glucoseStatus: glucoseStatus,
        deviceStatusIndicator: deviceStatusIndicator, // Sertakan di sini
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
    final dialogWidth = size.width;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 16), // Menghapus padding dialog default
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: double.infinity, // Lebar penuh
                ),
                child: Container(
                  height: min(size.height * 0.4, 320.0),
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
                                color: Color.fromARGB(255, 179, 4, 4),
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
                                          ? Colors.green
                                          : theme.colorScheme.surfaceVariant,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.bluetooth,
                                      size: 16,
                                      color: isContourDevice
                                          ? Colors.white
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
                                          color: Colors.green,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      backgroundColor: const Color.fromARGB(255, 179, 4, 4),
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
}
