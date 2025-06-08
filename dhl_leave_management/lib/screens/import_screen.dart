import 'dart:io';
import 'dart:convert';
import 'package:dhl_leave_management/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  // Use the centralized FirebaseService for all database operations
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  bool _isProcessing = false;
  String? _fileName;
  List<List<dynamic>>? _rows;
  int _totalRows = 0;
  int _processed = 0;
  double _progress = 0.0;

  final List<String> _log = [];
  int _successCount = 0;
  int _failCount = 0;
  int _duplicateCount = 0;
  final Set<String> _newEmployees = {};

  // Column indices for data mapping
  final Map<String, int> _colIdx = {
    'employeeName': 0,
    'employeeId': 1,
    'leaveType': 2,
    'startDate': 3,
    'endDate': 4,
    'status': 5,
  };

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _fileName = null;
      _rows = null;
      _log.clear();
      _successCount = _failCount = _duplicateCount = 0;
      _newEmployees.clear();
      _processed = 0;
      _progress = 0.0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.single;
      _fileName = file.name;
      _log.add('📁 Selected file: $_fileName');

      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        await _parseFileBytes(bytes);
      } else if (file.path != null) {
        final path = file.path!;
        try {
          final fileBytes = await File(path).readAsBytes();
          await _parseFileBytes(fileBytes);
        } catch (e) {
          _log.add('❌ Failed to read file from path: $e');
        }
      } else {
        _log.add('❌ No file data available');
      }

      if (_rows != null && _rows!.isNotEmpty) {
        _totalRows = _rows!.length;
        _log.add('📋 Found $_totalRows records for import');
      } else {
        _log.add('⚠️ No valid data rows were found after parsing');
      }
    } catch (e) {
      _log.add('❌ Failed to read file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _parseFileBytes(List<int> bytes) async {
    String content = '';
    try {
      content = utf8.decode(bytes);
      _log.add('✅ Successfully decoded file as UTF-8');
    } catch (_) {
      try {
        content = latin1.decode(bytes);
        _log.add('✅ Successfully decoded file as Latin-1');
      } catch (e) {
        _log.add('❌ File decoding failed: $e');
        return;
      }
    }

    if (content.isEmpty) {
      _log.add('❌ Could not extract any text from the file');
      return;
    }

    await _parseTextContent(content);
  }

  Future<void> _parseTextContent(String content) async {
    try {
      final lines = LineSplitter.split(content).toList();
      if (lines.isEmpty) {
        _log.add('❌ No content lines found');
        return;
      }

      _log.add('📄 Found ${lines.length} lines in file');

      final delimiter = _detectDelimiter(lines[0]);
      _log.add('📄 Using ${delimiter == '\t' ? 'tab' : 'comma'} as delimiter');

      final List<List<String>> parsedRows = [];

      // Skip the header row (index 0)
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final fields = _splitLine(line, delimiter);

        if (fields.length < 6) {
          _log.add(
              '⚠️ Row ${i + 1}: Skipped due to insufficient data (${fields.length} columns)');
          continue;
        }

        parsedRows.add(fields);
      }

      if (parsedRows.isEmpty) {
        _log.add('❌ No valid data rows found after parsing');
        return;
      }

      _rows = parsedRows;
      _log.add('✅ Successfully parsed ${parsedRows.length} data rows');

      if (parsedRows.isNotEmpty) {
        _log.add('📝 Sample: ${parsedRows[0].join(" | ")}');
      }
    } catch (e) {
      _log.add('❌ Text parsing error: $e');
    }
  }

  String _detectDelimiter(String line) {
    return line.contains('\t') ? '\t' : ',';
  }

  List<String> _splitLine(String line, String delimiter) {
    return line
        .split(delimiter)
        .map((field) => field.trim().replaceAll('"', ''))
        .toList();
  }

  Future<void> _importToFirestore() async {
    if (_rows == null || _rows!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No data to import'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _log.clear();
      _log.add('🚀 Starting import process...');
    });

    final List<Map<String, dynamic>> applicationsToImport = [];
    final List<Map<String, dynamic>> employeesToImport = [];

    for (int i = 0; i < _rows!.length; i++) {
      final row = _rows![i];
      try {
        if (row.length <= _colIdx['status']!) {
          _log.add('❌ Row ${i + 1}: Skipped due to insufficient columns.');
          _failCount++;
          continue;
        }

        final name = row[_colIdx['employeeName']!].toString().trim();
        final id = row[_colIdx['employeeId']!].toString().trim();
        final type = row[_colIdx['leaveType']!].toString().trim();
        final startDateStr = row[_colIdx['startDate']!].toString().trim();
        final endDateStr = row[_colIdx['endDate']!].toString().trim();
        final status = row[_colIdx['status']!].toString().trim();

        if (id.isEmpty ||
            name.isEmpty ||
            startDateStr.isEmpty ||
            endDateStr.isEmpty) {
          _log.add(
              '❌ Row ${i + 1}: Skipped due to missing essential data (ID, Name, or Dates).');
          _failCount++;
          continue;
        }

        final startDate = _tryParse(startDateStr);
        final endDate = _tryParse(endDateStr);

        if (startDate == null || endDate == null) {
          _log.add(
              '❌ Row ${i + 1}: Failed to parse dates ($startDateStr, $endDateStr).');
          _failCount++;
          continue;
        }

        // Add employee data for batch import
        employeesToImport.add({'id': id, 'name': name});

        // Add leave application data for batch import
        applicationsToImport.add({
          'employeeId': id,
          'employeeName': name,
          'leaveType': type,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'status': status,
        });
      } catch (e) {
        _log.add('❌ Row ${i + 1}: An unexpected error occurred: $e');
        _failCount++;
      }
    }

    // Batch import employees first
    _log.add(
        '👥 Importing/updating ${_newEmployees.length} unique employees...');
    final empResult =
        await _firebaseService.batchImportEmployees(employeesToImport);
    if (empResult['success']) {
      _log.add(
          '✅ Employee import successful. Processed: ${empResult['count']}');
    } else {
      _log.add('❌ Employee import failed: ${empResult['error']}');
    }

    // Now, batch import the leave applications using the robust service method
    _log.add(
        '📄 Importing ${applicationsToImport.length} leave applications...');
    final result = await _firebaseService
        .batchImportLeaveApplications(applicationsToImport);

    setState(() {
      if (result['success']) {
        _successCount = result['count'] ?? 0;
        _duplicateCount = result['duplicates'] ?? 0;
        _log.add('🎉 Import finished!');
        _log.add('   - Successful: $_successCount');
        _log.add('   - Duplicates Skipped: $_duplicateCount');
        _log.add('   - Failed: $_failCount');
      } else {
        _log.add('❌ Import failed: ${result['error']}');
      }
      _isProcessing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Import finished: $_successCount added, $_duplicateCount skipped, $_failCount failed'),
        backgroundColor: _failCount == 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  DateTime? _tryParse(String s) {
    s = s.trim();
    final formats = [
      'M/d/yy',
      'M/d/yyyy',
      'MM/dd/yy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'd-MMM-yyyy',
      'd-MMM-yy',
      'dd-MMM-yyyy',
      'dd-MMM-yy',
      'dd.MM.yyyy'
    ];

    for (var fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(s);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Leave Data'),
        backgroundColor: const Color(0xFFD40511),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(
                _fileName ?? 'No file selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isLoading || _isProcessing ? null : _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select File'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD40511)),
            ),
          ]),
          const SizedBox(height: 16),
          if (!_isLoading && _rows != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Found $_totalRows records.'),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _importToFirestore,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Import'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isProcessing)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: _progress),
                      Text('Processing: $_processed of $_totalRows')
                    ],
                  )),
          ] else if (_isLoading) ...[
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 16),
          if (!_isProcessing &&
              (_successCount > 0 || _failCount > 0 || _duplicateCount > 0)) ...[
            Text('✅ Imported: $_successCount'),
            if (_duplicateCount > 0)
              Text('📘 Skipped duplicates: $_duplicateCount'),
            Text('❌ Failed: $_failCount'),
            const Divider(),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (ctx, i) => Text(_log[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
