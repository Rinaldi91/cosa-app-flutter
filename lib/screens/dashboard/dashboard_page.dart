import 'dart:math';

import 'package:cosaapp/config/api_config.dart';
import 'package:cosaapp/screens/dashboard/widgets/fast_button.dart';
import 'package:cosaapp/screens/result/result_page.dart';
import 'package:cosaapp/screens/result/widgets/barcode_scanner_overlay.dart';
import 'package:cosaapp/screens/user/user_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'widgets/connection_status.dart';
import 'widgets/scan_button.dart';
import 'widgets/header.dart';
import 'utils/bluetooth_utils.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _selectedPatientId;
  String? _selectedPatientCode;
  int _selectedIndex = 0;
  String _username = "";
  String _comment = "";
  final TextEditingController _commentController = TextEditingController();
  BluetoothDevice? _connectedDevice;
  String? _connectedDeviceName;
  final List<ScanResult> _scanResults = [];
  List<GlucoseReading> glucoseReadings = [];
  bool _isContourDevice = false;
  Timer? _connectionCheckTimer;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  String _glucoseResult = "No Data";
  GlucoseReading? _latestReading;
  final TextEditingController _searchController = TextEditingController();

  bool _canSaveResult() {
    return _selectedPatientId != null &&
        _selectedPatientId!.isNotEmpty &&
        _glucoseResult != "No Data" &&
        _glucoseResult.isNotEmpty &&
        !_isSaved; // hanya jika belum disimpan
  }

  final Dio _dio = Dio();
  List<Patient> _patients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = false; // Add loading state
  bool _isSaved = false;
  bool _isValue = true;

  final TextEditingController nikController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController placeOfBirthController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController numberPhoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  int step = 0;

  TextEditingController searchController = TextEditingController();

  get deviceMacAddress => null;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    BluetoothUtils.checkPermissions();
    _startConnectionMonitoring();
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }

  // Fungsi untuk menyimpan hasil glukosa ke server
  Future<void> _saveGlucoseResult() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a patient.")),
      );
      return;
    }

    if (_glucoseResult == "No Data" || _glucoseResult.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid glucose result.")),
      );
      return;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please login again.")),
        );
        return;
      }

      final parts = _glucoseResult.split(' ');
      if (parts.length != 2 || int.tryParse(parts[0]) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Invalid glucose result format. Use 'unit value' (example: '91 mg/dL').")),
        );
        return;
      }

      DateTime dateTimeUtc =
          _latestReading?.timestamp ?? DateTime.now().toUtc();
      String formattedDateTime =
          DateFormat("yyyy-MM-dd HH:mm:ss").format(dateTimeUtc);

      // Tentukan apakah perangkat tersambung
      bool isConnected = _connectedDevice != null;
      // Ambil nama perangkat yang terhubung
      String deviceName = isConnected
          ? _connectedDevice?.name ?? 'Unknown Device'
          : 'No Device';

      // Tambahkan comment ke request data
      Map<String, dynamic> requestData = {
        "date_time": formattedDateTime,
        "glucos_value": int.parse(parts[0]),
        "unit": "mg/dL",
        "patient_id": _selectedPatientId,
        "patient_code": _selectedPatientCode,
        "device_name": deviceName,
        "comment":
            _comment.isNotEmpty ? _comment : null, // Tambah field comment
      };

      print("Request Data: $requestData");

      final Dio dio = ApiConfig.getDioClient(token: token);
      final String url = ApiConfig.getUrl(ApiConfig.testGlucosaEndpoint);

      final response = await dio.post(url, data: requestData);

      print("Response Status Code: ${response.statusCode}");
      print("Response Data: ${response.data}");

      // Menyesuaikan pengecekan sukses dengan status code 201 juga
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data["status"] == "success") {
        setState(() {
          _isSaved = true;
          // Reset comment setelah berhasil save
          _comment = "";
          _commentController.clear();
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                  Icons.check_circle,
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
                      const Text(
                        'Glucose results saved successfully!',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      } else {
        // Handle error response (kode existing)
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
                  Icons.warning,
                  color: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Failed to save glucose results. Status Code: ${response.statusCode}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Error saving glucose result: $e");
      // Handle catch error (kode existing)
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
                Icons.warning_amber_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Failed to Save Data.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'An error occurred while saving the glucose results. Please try again later.',
                      style: TextStyle(fontSize: 14),
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
        ),
      );
    }
  }

  Widget _buildSaveSection() {
    return Column(
      children: [
        // Tampilkan comment jika ada
        if (_comment.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.blue.shade700),
                    SizedBox(width: 8),
                    Text(
                      'Comment:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  _comment,
                  style: TextStyle(color: Colors.blue.shade800),
                ),
              ],
            ),
          ),
        ],

        // Tombol save
        if (!_isSaved && !_isValue) ...[
          Row(
            children: [
              // Tombol Add Comment
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.comment_outlined),
                  label: Text('Comment'),
                  onPressed: _showCommentDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color.fromARGB(255, 179, 4, 4),
                    side: BorderSide(color: Color.fromARGB(255, 179, 4, 4)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Tombol Save Result
              if (_canSaveResult())
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Save Result'),
                    onPressed: _saveGlucoseResult,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', userData['name']);
    print("Name saved: ${userData['name']}"); // Debugging
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedName = prefs.getString('name');
    print("Stored name: $storedName"); // Debugging
    setState(() {
      _username = storedName ?? 'Guest';
    });
  }

  void _startConnectionMonitoring() {
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => BluetoothUtils.checkDeviceConnection(
        _connectedDevice,
        onDisconnected: () {
          if (mounted) {
            setState(() {
              _connectedDevice = null;
              _isContourDevice = false;
            });
            BluetoothUtils.showDisconnectionSnackBar(context);
          }
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const ResultPage();
      case 2:
        return const UserPage();
      default:
        return _buildDashboardContent();
    }
  }

  Color _getGlucoseColor() {
    if (_glucoseResult == "No Data" ||
        _glucoseResult == "Invalid Data" ||
        _glucoseResult.contains("Error")) {
      return Colors.grey;
    }

    // Extract numeric value from string like "120 mg/dL"
    try {
      final parts = _glucoseResult.split(' ');
      if (parts.isEmpty) return Colors.grey;

      final value = int.parse(parts[0]);

      if (value < 70) {
        return Colors.red; // Low glucose
      } else if (value > 180) {
        return Colors.orange; // High glucose
      } else {
        return Colors.green; // Normal glucose
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  Future<void> saveConnectionLog({
    required BuildContext context, // Tambahkan context untuk SnackBar
    required String deviceId,
    required bool isConnected,
    required String details,
    String deviceType = 'ContourPlusElite',
  }) async {
    try {
      // Ambil token dari SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
                  Icons.login,
                  color: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session Ended.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'Please login again to continue.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue.shade800,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Login',
              textColor: Colors.white,
              onPressed: () {
                // Navigasi ke halaman login
                // Misalnya: Navigator.of(context).pushReplacementNamed('/login');
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        return;
      }

      // Prepare data for the connection log
      Map<String, dynamic> logData = {
        'deviceId': deviceId,
        'status': isConnected ? 'Connected' : 'Disconnected',
        'details': details,
        'deviceType': deviceType,
      };

      const String connectionLogEndpoint = ApiConfig.connectionStatus;

      // Kirim data dengan token yang valid
      final response = await ApiConfig.postData(
        endpoint: connectionLogEndpoint,
        data: logData,
        token: token, // Pastikan token dikirim
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Connection log saved successfully: ${response.data}');
      } else {
        print('Failed to save connection log: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving connection log: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device, bool isContourDevice,
      {String? deviceName}) async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      await _connectionStateSubscription?.cancel();
      await device.connect();
      final prefs = await SharedPreferences.getInstance();
      final String finalDeviceName = deviceName ?? device.name;
      await prefs.setString('last_connected_device_id', device.id.id);
      await prefs.setString('last_connected_device_name', device.name);

      if (!mounted) return;

      String errorMessage;
      if (e.toString().toLowerCase().contains('timeout')) {
        // Jika error disebabkan oleh timeout, kemungkinan besar perangkat tidak aktif
        errorMessage =
            "Device not active or out of range. Please turn it on and try again.";
      } else {
        // Untuk jenis error lainnya (misal: permission, bluetooth mati, dll)
        errorMessage = "Connection failed: ${e.toString()}";
      }

      // Log the successful connection
      saveConnectionLog(
        context: context,
        deviceId: device.id.toString(),
        isConnected: true,
        details: 'Device connected successfully. Device name: ${device.name}',
        deviceType: isContourDevice ? device.name : 'CounterPlusElite',
      );

      _connectionStateSubscription =
          device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _connectedDevice = null;
            _connectedDeviceName = null;
            _isContourDevice = false;
            _glucoseResult = "No Data";
            _latestReading = null;
          });

          // Log the disconnection
          saveConnectionLog(
            context: context, // Tambahkan parameter context
            deviceId: device.id.toString(),
            isConnected: false,
            details: 'Device disconnected. REMOTE_USER_TERMINATED_CONNECTION',
            deviceType: isContourDevice ? device.name : 'ContourPlusElite',
          );
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 6.0,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      errorMessage, // Tampilkan pesan yang sudah disesuaikan
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 4),
            ),
          );

          BluetoothUtils.showDisconnectionSnackBar(context);
        }
      });

      setState(() {
        _connectedDevice = device;
        _connectedDeviceName = finalDeviceName;
        _isContourDevice = isContourDevice;
        _selectedPatientId = null;
        _isSaved = false;
        _glucoseResult = "No Data";
        _latestReading = null;
      });

      if (isContourDevice) {
        try {
          await BluetoothUtils.setupGlucoseNotification(
            device,
            (GlucoseReading reading) {
              debugPrint('Received new reading: ${reading.toString()}');
              if (mounted) {
                setState(() {
                  _latestReading = reading;
                  _glucoseResult = "${reading.glucoseValue} ${reading.unit}";
                  debugPrint('Updated UI with glucose result: $_glucoseResult');
                });
              }
            },
          );
        } catch (e) {
          debugPrint('Error in glucose notification setup: $e');
          if (mounted) {
            setState(() {
              _glucoseResult = "Error: Cannot read glucose data";
            });
          }
        }
      }

      BluetoothUtils.showConnectionSuccessSnackBar(context, device.name);
    } catch (e) {
      if (!mounted) return;

      // Log connection error
      saveConnectionLog(
        context: context, // Tambahkan parameter context
        deviceId: device.id.toString(),
        isConnected: false,
        details: 'Connection error: ${e.toString()}',
        deviceType: isContourDevice ? 'CounterPlus' : 'Unknown',
      );

      BluetoothUtils.showConnectionErrorSnackBar(context, e.toString());
    }
  }

  Future<void> connectToSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceId = prefs.getString('last_connected_device_id');
      final savedDeviceName = prefs.getString('last_connected_device_name');

      if (savedDeviceId == null) {
        debugPrint("No devices saved.");
        BluetoothUtils.showConnectionErrorSnackBar(
            context, "There are no saved devices yet.");
        return;
      }

      final device = BluetoothDevice(
        remoteId: DeviceIdentifier(savedDeviceId),
      );

      debugPrint("Trying fast connection to: $savedDeviceId");

      await _connectToDevice(device, true); // true = diasumsikan alat contour
    } catch (e) {
      debugPrint("Fast connect failed: $e");
      if (mounted) {
        BluetoothUtils.showConnectionErrorSnackBar(
            context, "Fast connect failed: $e");
      }
    }
  }

  // Helper method to get the authentication token
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  //Scan barcode pasien
  Future<void> _scanBarcode() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerWithOverlay(),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _searchController.text = result;
        });

        // Cari pasien berdasarkan hasil scan
        await _searchPatient(result);

        // Pastikan _selectedPatientId diatur jika hanya ada satu hasil
        if (_filteredPatients.length == 1) {
          _selectPatient(_filteredPatients.first);
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error scanning barcode: $e');
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
                  Icons.qr_code_scanner,
                  color: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan Failed.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'Error reading barcode. Please try again.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Try again.',
              textColor: Colors.white,
              onPressed: () {
                // Di sini Anda bisa memanggil fungsi untuk mencoba pemindaian ulang
                // Misalnya: startBarcodeScanner();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  //Search data pasien
  Future<void> _searchPatient(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredPatients = List.from(_patients); // Reset jika input kosong
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isValue = false;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        print('Please login again.');
        return;
      }

      // Gunakan instance Dio dari ApiConfig
      final Dio dio = ApiConfig.getDioClient(token: token);

      // Gunakan URL lengkap dengan `getUrl`
      final String url = ApiConfig.getUrl(ApiConfig.patientEndpoint);

      final response = await dio.get(
        url,
        queryParameters: {'search': query},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _filteredPatients = (data['data']['patients'] as List)
              .map(
                  (item) => Patient.fromJson(item)) // Ensure mapping is correct
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching patient: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
                Icons.person_off,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Failed to Load Patient Data.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      e.toString(),
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
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              // Tampilkan dialog dengan error lengkap
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error Details'),
                  content: SingleChildScrollView(
                    child: Text(e.toString()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Modifikasi fungsi untuk memilih pasien
  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatientId = patient.id.toString(); // Simpan ID pasien
      _selectedPatientCode =
          patient.patientCode.toString(); // Simpan patient Code
      _isSaved = false;
      debugPrint(
          "Selected Patient ID: $_selectedPatientId"); // Tampilkan log untuk verifikasi
      debugPrint(
          "Patient Name: ${patient.name}"); // Opsional: Tampilkan nama pasien untuk referensi
    });
  }

  void _filterPatients(String query) {
    setState(() {
      _filteredPatients = _patients.where((patient) {
        return patient.name.toLowerCase().contains(query.toLowerCase()) ||
            patient.id.toString().contains(query.toLowerCase()) ||
            patient.patientCode.toLowerCase().contains(query.toLowerCase()) ||
            patient.barcode.toLowerCase().contains(query.toLowerCase()) ||
            patient.dateOfBirth.toLowerCase().contains(query.toLowerCase()) ||
            patient.address.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showAddPatientDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing when tapping outside
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Patient'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildStepFields(setState),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
                if (step > 0)
                  TextButton(
                    onPressed: () => setState(() => step--),
                    child: Text('Back'),
                  ),
                if (step < 6)
                  ElevatedButton(
                    onPressed: _canProceedToNextStep()
                        ? () => setState(() {
                              step++;
                              FocusScope.of(context)
                                  .unfocus(); // Close keyboard
                            })
                        : null,
                    child: Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Save'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  bool _canProceedToNextStep() {
    switch (step) {
      case 0:
        return nikController.text.isNotEmpty;
      case 1:
        return nameController.text.isNotEmpty;
      case 2:
        return placeOfBirthController.text.isNotEmpty;
      case 3:
        return dateOfBirthController.text.isNotEmpty;
      case 4:
        return addressController.text.isNotEmpty;
      case 5:
        return numberPhoneController.text.isNotEmpty;
      case 6:
        return emailController.text.isNotEmpty;
      default:
        return false;
    }
  }

  List<Widget> _buildStepFields(Function setState) {
    switch (step) {
      case 0:
        return [_buildNikField(setState)];
      case 1:
        return [_buildTextField('Name', nameController, TextInputType.text)];
      case 2:
        return [
          _buildTextField(
              'Place of Birth', placeOfBirthController, TextInputType.text)
        ];
      case 3:
        return [
          _buildTextField(
              'Date of Birth', dateOfBirthController, TextInputType.datetime)
        ];
      case 4:
        return [
          _buildTextField('Address', addressController, TextInputType.text)
        ];
      case 5:
        return [
          _buildTextField(
              'Phone Number', numberPhoneController, TextInputType.phone)
        ];
      case 6:
        return [
          _buildTextField('Email', emailController, TextInputType.emailAddress)
        ];
      default:
        return [];
    }
  }

  Widget _buildNikField(Function setState) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: nikController,
        keyboardType: TextInputType.number,
        maxLength: 16,
        decoration: InputDecoration(
          labelText: 'NIK',
          border: OutlineInputBorder(),
          counterText: '',
        ),
        onChanged: (value) {
          if (value.length > 16) {
            nikController.text = value.substring(0, 16);
            nikController.selection = TextSelection.fromPosition(
              TextPosition(offset: nikController.text.length),
            );
          }
        },
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      TextInputType keyboardType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // Fungsi untuk menampilkan dialog comment
  Future<void> _showCommentDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.comment, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add Comment'),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Add a comment for this glucose reading:',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter your comment here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 179, 4, 4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
              onPressed: () {
                _commentController.clear();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 179, 4, 4),
                foregroundColor: Colors.white,
              ),
              child: Text('Save Comment'),
              onPressed: () {
                setState(() {
                  _comment = _commentController.text.trim();
                });
                Navigator.of(context).pop();

                // Show confirmation snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Comment added successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardContent() {
    bool isConnected = _connectedDevice != null && _isContourDevice;
    String deviceName =
        isConnected ? _connectedDeviceName ?? 'Connected Device' : '';
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.home), // Icon for fan device
            SizedBox(width: 8), // Spacing between icon and text
            Text(
              'Fans Cosa',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 179, 4, 4),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            // Menggunakan ikon 'flash_on' untuk fast connection
            icon: const Icon(Icons.flash_on),

            // Fungsi yang dipanggil saat ikon ditekan
            onPressed: connectToSavedDevice,

            // Teks bantuan yang muncul saat ikon ditekan lama
            tooltip: 'Fast Connection',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              DashboardHeader(username: _username),
              Divider(),
              const SizedBox(height: 5),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConnectionStatus(
                            isConnected: isConnected,
                            deviceName: deviceName,
                          ),
                          const SizedBox(height: 3),
                          if (isConnected)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.bluetooth_connected,
                                    color: Colors.white, size: 24),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15.0),
                                ),
                                onPressed: () {},
                                label: Flexible(
                                  child: Text(
                                    deviceName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                            )
                          else
                            ScanButton(
                              isConnected: isConnected,
                              onScan: () => BluetoothUtils.scanAndShowDialog(
                                context,
                                onDeviceSelected: (device, isContour) {
                                  _connectToDevice(device, isContour);
                                },
                                // onDeviceSelected: _connectToDevice,
                              ),
                            ),
                          // const SizedBox(height: 8),
                          // FastConnectionButton(
                          //   text: 'Fast Connection',
                          //   iconData: Icons.flash_on,
                          //   backgroundColor: Colors.orange,
                          //   foregroundColor: Colors.white,
                          //   borderRadius: 12,
                          //   verticalPadding: 15,
                          //   horizontalPadding: 20,
                          //   onPressed: connectToSavedDevice,
                          // ),
                          const SizedBox(height: 10),
                          Divider(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, color: Colors.black),
                                  SizedBox(width: 5),
                                  Text(
                                    'Patient',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              // ElevatedButton(
                              //   onPressed: _showAddPatientDialog,
                              //   child: Text('Add Patient'),
                              // ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          // TextField(
                          //   controller: _searchController,
                          //   decoration: InputDecoration(
                          //     labelText: 'Scan QR Code Patient',
                          //     prefixIcon: const Icon(Icons.search),
                          //     suffixIcon: _searchController.text.isNotEmpty
                          //         ? Row(
                          //             mainAxisSize: MainAxisSize.min,
                          //             children: [
                          //               IconButton(
                          //                 icon: const Icon(Icons.clear),
                          //                 onPressed: () {
                          //                   setState(() {
                          //                     _searchController.clear();
                          //                     _filterPatients("");
                          //                     _isSaved = false;
                          //                     _glucoseResult =
                          //                         "No Data"; // Reset nilai hasil glukosa
                          //                     _latestReading =
                          //                         null; // Reset waktu jika perlu
                          //                   });
                          //                 },
                          //                 tooltip: 'Clear Search',
                          //               ),
                          //               IconButton(
                          //                 icon:
                          //                     const Icon(Icons.qr_code_scanner),
                          //                 onPressed: _scanBarcode,
                          //                 tooltip: 'Scan Barcode',
                          //               ),
                          //             ],
                          //           )
                          //         : IconButton(
                          //             icon: const Icon(Icons.qr_code_scanner),
                          //             onPressed: _scanBarcode,
                          //             tooltip: 'Scan Barcode',
                          //           ),
                          //     border: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(12),
                          //       borderSide: const BorderSide(
                          //           color: Color.fromARGB(255, 179, 4, 4)),
                          //     ),
                          //     focusedBorder: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(12),
                          //       borderSide: const BorderSide(
                          //         color: Color.fromARGB(255, 179, 4, 4),
                          //         width: 2,
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          TextField(
                            controller: _searchController,
                            readOnly:
                                true, // Tidak bisa diketik manual, tapi bisa di-tap
                            onTap:
                                _scanBarcode, // Tap di TextField langsung buka scanner
                            decoration: InputDecoration(
                              labelText: 'Scan QR Code Patient',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_searchController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _filterPatients(
                                              ""); // Reset daftar pasien
                                          _isSaved = false;
                                          _glucoseResult =
                                              "No Data"; // Reset hasil glukosa
                                          _latestReading = null;
                                        });
                                      },
                                      tooltip: 'Clear Search',
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    onPressed: _scanBarcode,
                                    tooltip: 'Scan Barcode',
                                  ),
                                ],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 179, 4, 4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 179, 4, 4),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                          _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : _filteredPatients.isEmpty
                                  ? const Text("")
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: _filteredPatients.length,
                                      itemBuilder: (context, index) {
                                        final patient =
                                            _filteredPatients[index];
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.2),
                                                spreadRadius: 1,
                                                blurRadius: 2,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              child: Text(
                                                patient.name[0],
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            title: Text(patient.name),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    "Code Patient: ${patient.patientCode}"),
                                                Text(
                                                    "Barcode: ${patient.barcode}"),
                                                Text(
                                                    "Address: ${patient.address}"),
                                              ],
                                            ),
                                            onTap: () =>
                                                _selectPatient(patient),
                                          ),
                                        );
                                      },
                                    ),
                          const SizedBox(height: 10),
                          Divider(),
                          const SizedBox(height: 10),
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'Glucose Level',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _glucoseResult == "No Data"
                                          ? Icons.hourglass_empty
                                          : Icons.water_drop,
                                      color: _getGlucoseColor(),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _glucoseResult,
                                        style: TextStyle(
                                          fontSize: isLandscape ? 16 : 20,
                                          fontWeight: FontWeight.bold,
                                          color: _getGlucoseColor(),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_latestReading != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Date & Time: ${_latestReading!.formattedTimestamp}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                if (_canSaveResult())
                                  ElevatedButton(
                                    onPressed: _saveGlucoseResult,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      alignment: Alignment.center,
                                    ),
                                    child: Text(
                                      "Save Result",
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              SizedBox(height: isLandscape ? 5.0 : 0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _getPage(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Results',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'User',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 179, 4, 4),
        onTap: _onItemTapped,
      ),
    );
  }

  String _getGlucoseRange() {
    try {
      final parts = _glucoseResult.split(' ');
      if (parts.isEmpty) return "";

      final value = int.parse(parts[0]);

      if (value < 70) {
        return "Rendah - Perlu perhatian segera";
      } else if (value < 100) {
        return "Normal";
      } else if (value < 125) {
        return "Pra-diabetes";
      } else if (value < 180) {
        return "Target setelah makan";
      } else {
        return "Tinggi - Konsultasikan dengan dokter";
      }
    } catch (e) {
      return "";
    }
  }
}
