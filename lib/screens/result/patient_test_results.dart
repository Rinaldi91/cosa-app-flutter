import 'package:cosaapp/config/api_config.dart';
import 'package:cosaapp/screens/result/result_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientTestResultPage extends StatefulWidget {
  final Patient patient;

  const PatientTestResultPage({super.key, required this.patient});

  @override
  _PatientTestResultPageState createState() => _PatientTestResultPageState();
}

class _PatientTestResultPageState extends State<PatientTestResultPage> {
  List<dynamic> _testResults = [];
  bool _isLoading = true;
  Map<String, dynamic>? _pagination;

  int _currentPage = 1;
  int _limit = 10; // Default tampilan 10 data
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPreviousPage = false;

  @override
  void initState() {
    super.initState();
    _fetchTestResults();
  }

  Future<void> _fetchTestResults() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        print('Token tidak ditemukan, silakan login kembali.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi Anda telah berakhir, silakan login kembali.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final Dio dio = ApiConfig.getDioClient(token: token);
      String endpoint = ApiConfig.testGlucosaPatientEndpoint
          .replaceAll('{patientId}', widget.patient.id.toString());
      final String url = ApiConfig.getUrl(endpoint);

      // final response = await dio.get(url);

      final response = await dio.get(
        url,
        queryParameters: {'page': _currentPage, 'limit': _limit},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['status'] == 'success') {
          setState(() {
            _testResults = data['data'] as List;
            //tambahan
            _pagination = data['pagination'];
            _currentPage = _pagination?['currentPage'] ?? 1;
            _totalPages = _pagination?['totalPages'] ?? 1;
            _hasNextPage = _pagination?['hasNextPage'] ?? false;
            _hasPreviousPage = _pagination?['hasPreviousPage'] ?? false;
          });
        }
      }
    } catch (e) {
      print('Error fetching test results: $e');
      if (e is DioException && e.response != null) {
        print('Response Text:\n${e.response?.data.toString()}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading test results: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.list_alt_rounded), // Icon for fan device
            SizedBox(width: 8), // Spacing between icon and text
            Text(
              'Glucose Test Results',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 179, 4, 4),
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTestResults,
        color: const Color.fromARGB(255, 179, 4, 4), // Warna indikator refresh
        backgroundColor: Colors.white,
        strokeWidth: 3.0,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Name:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.patient.name),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Patient Code:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.patient.patientCode),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('No RM:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.patient.noRM),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Age:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.patient.getAgeList().join(', ')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Glucose Test Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading && _testResults.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 179, 4, 4)),
                      ),
                    )
                  : _testResults.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 100),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.search_off,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No test results found',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Pull down for refresh',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _testResults.length,
                          itemBuilder: (context, index) {
                            final result = _testResults[index];

                            // Format tanggal dari string ISO
                            DateTime testDate;
                            try {
                              testDate = DateTime.parse(result['date_time']);
                            } catch (e) {
                              testDate =
                                  DateTime.now(); // Default if parsing fails
                              print('Error parsing date: $e');
                            }

                            String formattedDate =
                                DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID')
                                    .format(testDate.toLocal());

                            // Ensure safe access to numeric values
                            int bloodSugar = 0;
                            try {
                              var glucosValue = result['glucos_value'];
                              if (glucosValue is int) {
                                bloodSugar = glucosValue.toInt();
                              } else if (glucosValue is int) {
                                bloodSugar = glucosValue;
                              } else if (glucosValue is String) {
                                bloodSugar = int.tryParse(glucosValue) ?? 0;
                              }
                            } catch (e) {
                              print('Error parsing glucos_value: $e');
                            }

                            Color statusColor;
                            String statusText;

                            if (bloodSugar < 70) {
                              statusColor = Colors.blue;
                              statusText = 'Low';
                            } else if (bloodSugar < 140) {
                              statusColor = Colors.green;
                              statusText = 'Normal';
                            } else if (bloodSugar < 200) {
                              statusColor = Colors.orange;
                              statusText = 'High';
                            } else {
                              statusColor = Colors.red;
                              statusText = 'Very High';
                            }
                            String labNumber =
                                result['lab_number'] ?? 'No Order Lab';
                            String unit = result['unit'] ?? 'mg/dL';
                            String deviceName =
                                result['device_name'] ?? 'Unknown Device';
                            String metode = result['metode'] ?? 'Not specified';
                            bool isValidated = result['is_validation'] == 1;
                            Color validationColor =
                                isValidated ? Colors.green : Colors.orange;
                            String validationText =
                                isValidated ? 'Validated' : 'Not Validated';

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
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
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: statusColor,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Lab Number:'),
                                        Text(
                                          labNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Blood Sugar:'),
                                        Text(
                                          '${bloodSugar.toInt().toString()} $unit',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Device Name:'),
                                        Text(
                                          deviceName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Metode:'),
                                        Text(
                                          metode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: validationColor,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              validationText,
                                              style: TextStyle(
                                                color: validationColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Switch(
                                          value: isValidated,
                                          activeColor: Colors.green,
                                          onChanged: isValidated
                                              ? null
                                              : (value) async {
                                                  if (!isValidated) {
                                                    final theme =
                                                        Theme.of(context);
                                                    try {
                                                      // Menampilkan dialog konfirmasi dengan desain yang lebih elegan
                                                      bool confirm =
                                                          await showDialog(
                                                                context:
                                                                    context,
                                                                barrierDismissible:
                                                                    false,
                                                                builder:
                                                                    (BuildContext
                                                                        context) {
                                                                  return AlertDialog(
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              16.0), // Border radius untuk dialog
                                                                    ),
                                                                    title: Row(
                                                                      children: [
                                                                        const Icon(
                                                                            Icons
                                                                                .check_circle_outline,
                                                                            color:
                                                                                Colors.green,
                                                                            size: 30), // Ikon untuk judul
                                                                        const SizedBox(
                                                                            width:
                                                                                10),
                                                                        const Text(
                                                                          "Validation Confirmation",
                                                                          style: TextStyle(
                                                                              fontSize: 18,
                                                                              fontWeight: FontWeight.bold),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    content:
                                                                        const Text(
                                                                      "Are you sure you want to validate this test result?",
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          color:
                                                                              Colors.black87),
                                                                    ),
                                                                    actions: [
                                                                      Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceBetween, // Memastikan tombol sejajar kiri dan kanan
                                                                        children: [
                                                                          TextButton(
                                                                            onPressed: () =>
                                                                                Navigator.of(context).pop(false),
                                                                            style:
                                                                                OutlinedButton.styleFrom(
                                                                              side: BorderSide(color: theme.colorScheme.error),
                                                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                                            ),
                                                                            child:
                                                                                Row(
                                                                              mainAxisSize: MainAxisSize.min, // Agar Row hanya memakan ruang yang diperlukan
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.close, // Ikon "X"
                                                                                  color: theme.colorScheme.error, // Warna ikon sesuai dengan tema
                                                                                  size: 18, // Ukuran ikon (opsional, sesuaikan jika diperlukan)
                                                                                ),
                                                                                const SizedBox(width: 8), // Jarak antara ikon dan teks
                                                                                Text(
                                                                                  "Cancel",
                                                                                  style: TextStyle(color: theme.colorScheme.error),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                              width: 8),
                                                                          ElevatedButton
                                                                              .icon(
                                                                            onPressed: () =>
                                                                                Navigator.of(context).pop(true),
                                                                            icon: Icon(Icons.check,
                                                                                size: 16,
                                                                                color: Colors.white), // Ikon putih
                                                                            label:
                                                                                Text(
                                                                              'Validation',
                                                                              style: TextStyle(color: Colors.white), // Teks putih
                                                                            ),
                                                                            style:
                                                                                ElevatedButton.styleFrom(
                                                                              backgroundColor: Colors.green, // Warna latar tombol Validasi
                                                                              foregroundColor: Colors.white, // Warna teks tombol Validasi
                                                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              ) ??
                                                              false;

                                                      if (confirm) {
                                                        // Dapatkan token dari local storage
                                                        final prefs =
                                                            await SharedPreferences
                                                                .getInstance();
                                                        final token = prefs
                                                            .getString('token');
                                                        if (token == null) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  'Token is expired. Please login again.'),
                                                              backgroundColor:
                                                                  Colors.red,
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        // Ambil ID dari hasil tes
                                                        final testId =
                                                            result['id']
                                                                .toString();
                                                        // Buat endpoint dengan mengganti parameter
                                                        final endpoint = ApiConfig
                                                            .replacePathParameters(
                                                          ApiConfig
                                                              .updateIsValidation,
                                                          {'id': testId},
                                                        );
                                                        // Kirim permintaan update
                                                        final response =
                                                            await ApiConfig
                                                                .updateData(
                                                          endpoint: endpoint,
                                                          data: {
                                                            'is_validation': 1
                                                          },
                                                          token: token,
                                                        );
                                                        if (response.statusCode ==
                                                                200 ||
                                                            response.statusCode ==
                                                                201) {
                                                          // Update data lokal
                                                          setState(() {
                                                            _testResults[index][
                                                                'is_validation'] = 1;
                                                          });
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  'Data successfully validated'),
                                                              backgroundColor:
                                                                  Colors.green,
                                                            ),
                                                          );
                                                        } else {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  'Failed to validate data'),
                                                              backgroundColor:
                                                                  Colors.red,
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    } catch (e) {
                                                      print(
                                                          'Error updating validation status: $e');
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              'Error: ${e.toString()}'),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            // Pagination information
            if (_pagination != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _hasPreviousPage
                          ? () {
                              setState(() {
                                _currentPage--;
                              });
                              _fetchTestResults();
                            }
                          : null,
                      child: const Text("Previous"),
                    ),
                    Text("Page $_currentPage of $_totalPages"),
                    ElevatedButton(
                      onPressed: _hasNextPage
                          ? () {
                              setState(() {
                                _currentPage++;
                              });
                              _fetchTestResults();
                            }
                          : null,
                      child: const Text("Next"),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
