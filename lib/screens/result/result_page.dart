import 'package:cosaapp/config/api_config.dart';
import 'package:cosaapp/screens/result/patient_test_results.dart';
import 'package:cosaapp/screens/result/widgets/barcode_scanner_overlay.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/locale.dart';
import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';

class Patient {
  final int id;
  final String name;
  final String patientCode;
  final String barcode;
  final String dateOfBirth;
  final String address;

  Patient(
      {required this.id,
      required this.name,
      required this.patientCode,
      required this.barcode,
      required this.dateOfBirth,
      required this.address});

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      patientCode: json['patient_code'],
      barcode: json['barcode'],
      dateOfBirth: json['date_of_birth'],
      address: json['address'],
    );
  }

  String getFormattedDate() {
    DateTime dob = DateFormat('yyyy-MM-dd').parse(dateOfBirth);
    return DateFormat('dd MMMM yyyy', 'id_ID').format(dob);
  }

  List<String> getAgeList() {
    DateTime dob = DateFormat('yyyy-MM-dd').parse(dateOfBirth);
    DateTime today = DateTime.now();
    Duration diff = today.difference(dob);
    int years = (diff.inDays / 365).floor();
    int months = ((diff.inDays % 365) / 30).floor();
    int days = (diff.inDays % 30);
    return ['$years Year', '$months Month', '$days Day'];
  }
}

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final Dio _dio = Dio();
  List<Patient> _patients = [];
  List<Patient> _filteredPatients = [];
  int _currentPage = 1;
  int _totalPages = 1;
  final int _itemsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false; // Add loading state
  List<dynamic> _testResults = [];
  int _totalPatients = 0;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  // Di file yang menggunakan scanner (misalnya di screen Anda):
  Future<void> _scanBarcode() async {
    try {
      // Pastikan ada delay kecil antara scan
      await Future.delayed(const Duration(milliseconds: 100));
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerWithOverlay(),
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _searchController.text = result; // Set hasil scan ke search bar
          _filterPatients(result); // Lakukan pencarian dengan hasil scan
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error scanning barcode: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error scanning barcode. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchPatients({String? search}) async {
    setState(() {
      _isLoading = true; // Set loading to true when fetching starts
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        print('Token tidak ditemukan, silakan login kembali.');
        return;
      }
      final Dio dio = ApiConfig.getDioClient(token: token);
      final String url = ApiConfig.getUrl(ApiConfig.patientEndpoint);
      final response = await dio.get(
        url,
        queryParameters: {
          'page': _currentPage, // Nomor halaman
          'limit': _itemsPerPage, // Jumlah item per halaman
          if (search != null && search.isNotEmpty)
            'search': search, // Pencarian
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _patients = (data['data']['patients'] as List)
              .map((item) => Patient.fromJson(item))
              .toList();
          _filteredPatients = List.from(_patients); // Reset filtered patients
          _totalPages = data['data']['pagination']['totalPages'];
          _totalPatients = data['data']['pagination']['totalPatients'] ?? 0;
        });
      }
    } catch (e) {
      print('Error fetching patients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false; // Set loading to false when fetching ends
      });
    }
  }

  void _filterPatients(String query) {
    setState(() {
      _currentPage = 1; // Reset ke halaman pertama saat melakukan pencarian
      _searchController.text = query; // Update teks pencarian
    });
    _fetchPatients(search: query); // Panggil API dengan parameter pencarian
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Result'),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear(); // Hapus teks input
                                _filterPatients(
                                    ""); // Reset data ke kondisi awal
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
                      )
                    : IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanBarcode,
                        tooltip: 'Scan Barcode',
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color.fromARGB(255, 0, 122, 255)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color.fromARGB(255, 0, 122, 255), width: 2),
                ),
              ),
              onChanged: (value) {
                setState(
                    () {}); // Perbarui UI agar ikon "X" muncul saat input terisi
                _filterPatients(value); // Lakukan pencarian
              },
            ),
          ),
          // Daftar Pasien
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 0, 122, 255)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading Data...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : _filteredPatients.isEmpty
                    ? const Center(
                        child: Card(
                          margin: EdgeInsets.all(20),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Data Not Found',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PatientTestResultPage(
                                    patient: patient,
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Name:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(patient.name),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Code:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(patient.patientCode),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Barcode:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(patient.barcode),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('DOB:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(patient.getFormattedDate()),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Age:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(patient.getAgeList().join(', ')),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'View Test Results',
                                            style: TextStyle(
                                                color: Colors.blueAccent,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(width: 5),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: Colors.blueAccent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Tombol Navigasi Halaman
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                        _fetchPatients();
                      }
                    : null, // Nonaktifkan tombol jika sudah di halaman pertama
              ),
              Text(
                  'Showing page $_currentPage to $_totalPages of $_totalPatients'),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                        _fetchPatients();
                      }
                    : null, // Nonaktifkan tombol jika sudah di halaman terakhir
              ),
            ],
          ),
        ],
      ),
    );
  }
}
