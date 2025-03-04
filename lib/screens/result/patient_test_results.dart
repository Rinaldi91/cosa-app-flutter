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
        return;
      }

      final Dio dio = ApiConfig.getDioClient(token: token);
      String endpoint = ApiConfig.testGlucosaPatientEndpoint
          .replaceAll('{patientId}', widget.patient.id.toString());
      final String url = ApiConfig.getUrl(endpoint);

      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['status'] == 'success') {
          setState(() {
            _testResults = data['data'] as List;
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patient.name} - Blood Sugar Test'),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(10),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
                      const Text('Code:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(widget.patient.patientCode),
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
                'Test Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _testResults.isEmpty
                    ? const Center(
                        child: Card(
                          margin: EdgeInsets.all(20),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No test results found',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
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

                          // Safely get unit value with fallback
                          String unit = result['unit'] ?? 'mg/dL';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            elevation: 2,
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
    );
  }
}
