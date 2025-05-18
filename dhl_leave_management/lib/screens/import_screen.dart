import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dhl_leave_management/utils/excel_import_utility.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ExcelImportUtility _excelImportUtility = ExcelImportUtility();
  // <-- Updated to match your pubspec.yaml
  final String _assetFilePath = 'assets/Employee_Leave_Data_v1.xlsx';

  bool _isImporting = false;
  String _importStatus = '';
  Map<String, dynamic>? _importStats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Import'),
        backgroundColor: const Color(0xFFD40511), // DHL Red
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // DHL Logo – now using your local PNG asset
                  Image.asset(
                    'assets/DHL_Express_logo_rgb.png',
                    height: 60,
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Welcome, Nina',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Import your Excel data to the leave management system',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // File path indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.file_present,
                            color: Color(0xFFD40511)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _assetFilePath,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Import button
                  ElevatedButton.icon(
                    onPressed: _isImporting
                        ? null
                        : () async {
                            setState(() {
                              _isImporting = true;
                              _importStatus = 'Importing data…';
                              _importStats = null;
                            });

                            final result = await _importAssetExcelData();

                            setState(() {
                              _isImporting = false;
                              _importStatus =
                                  result['message'] ?? 'Import completed';
                              _importStats = result['stats'];
                            });
                          },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Excel Data'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      backgroundColor: const Color(0xFFD40511),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status text
                  if (_importStatus.isNotEmpty)
                    Text(
                      _importStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _importStats != null
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Import statistics
                  if (_importStats != null) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Import Results',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                        'Total Rows', _importStats!['totalRows'].toString()),
                    _buildStatCard('Successful Imports',
                        _importStats!['successfulImports'].toString()),
                    _buildStatCard('Failed Imports',
                        _importStats!['failedImports'].toString()),
                    _buildStatCard('Unique Employees',
                        _importStats!['uniqueEmployees'].toString()),

                    if ((_importStats!['errors'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Errors',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: (_importStats!['errors'] as List).length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            child: Text(
                              (_importStats!['errors'] as List)[index],
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _importAssetExcelData() async {
    try {
      final ByteData data = await rootBundle.load(_assetFilePath);
      final Uint8List bytes = data.buffer.asUint8List();
      return await _excelImportUtility.importExcelDataFromBytes(bytes);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error loading Excel file: $e',
        'stats': null,
      };
    }
  }

  Widget _buildStatCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}