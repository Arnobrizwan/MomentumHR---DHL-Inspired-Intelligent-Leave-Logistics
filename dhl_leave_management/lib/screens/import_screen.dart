import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
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
        withData: true, // Always load file bytes
      );
      
      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final fileName = result.files.single.name;
      _fileName = fileName;
      
      _log.add('📁 Selected file: $fileName');

      // Get file bytes directly
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        // Try to read from path if available
        if (result.files.single.path != null) {
          final path = result.files.single.path!;
          try {
            final fileBytes = await File(path).readAsBytes();
            await _parseFileBytes(fileBytes);
          } catch (e) {
            _log.add('❌ Failed to read file from path: $e');
          }
        } else {
          _log.add('❌ No file data available');
        }
      } else {
        // Use bytes directly
        await _parseFileBytes(bytes);
      }

      if (_rows != null && _rows!.isNotEmpty) {
        _totalRows = _rows!.length;
        _log.add('📋 Found $_totalRows records for import');
      } else {
        _log.add('⚠️ No data rows were found after parsing');
      }
    } catch (e) {
      _log.add('❌ Failed to read file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _parseFileBytes(List<int> bytes) async {
    // Skip Excel parsing completely and try direct text extraction
    String content = '';
    
    // Try different encodings to extract text content
    try {
      content = utf8.decode(bytes);
      _log.add('✅ Successfully decoded file as UTF-8');
    } catch (_) {
      try {
        content = latin1.decode(bytes);
        _log.add('✅ Successfully decoded file as Latin-1');
      } catch (_) {
        // Last resort: try to extract printable ASCII characters
        _log.add('⚠️ Standard decoding failed, trying ASCII extraction');
        content = _extractPrintableAscii(bytes);
      }
    }
    
    if (content.isEmpty) {
      _log.add('❌ Could not extract any text from the file');
      return;
    }
    
    await _parseTextContent(content);
  }
  
  String _extractPrintableAscii(List<int> bytes) {
    // Extract printable ASCII characters and common delimiters
    return String.fromCharCodes(bytes.where((byte) => 
      (byte >= 32 && byte <= 126) || // Printable ASCII
      byte == 9 ||  // Tab
      byte == 10 || // Line feed
      byte == 13)); // Carriage return
  }

  Future<void> _parseTextContent(String content) async {
    try {
      // Split into lines
      final lines = LineSplitter.split(content).toList();
      if (lines.isEmpty) {
        _log.add('❌ No content lines found');
        return;
      }
      
      _log.add('📄 Found ${lines.length} lines in file');
      
      // Detect delimiter - try tab first, then comma
      String delimiter = _detectDelimiter(lines[0]);
      _log.add('📄 Using ${delimiter == '\t' ? 'tab' : delimiter == ',' ? 'comma' : 'custom'} delimiter');
      
      final List<List<String>> parsedRows = [];
      
      // Parse header row to validate expected columns
      if (lines.isNotEmpty) {
        final headerFields = _splitLine(lines[0], delimiter);
        _log.add('📑 Header: ${headerFields.join(" | ")}');
        
        // Check expected columns are present
        if (headerFields.length < _colIdx.length) {
          _log.add('⚠️ Warning: Header has fewer columns (${headerFields.length}) than expected (${_colIdx.length})');
        }
      }
      
      // Skip the header row
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final fields = _splitLine(line, delimiter);
        
        // Skip rows with insufficient data
        if (fields.length < _colIdx.length) {
          _log.add('⚠️ Row ${i+1} has insufficient data (${fields.length} columns)');
          continue;
        }
        
        // Add row
        parsedRows.add(fields);
      }
      
      if (parsedRows.isEmpty) {
        _log.add('❌ No valid data rows found after parsing');
        return;
      }
      
      _rows = parsedRows;
      _log.add('✅ Successfully parsed ${parsedRows.length} data rows');
      
      // Show sample of first row
      if (parsedRows.isNotEmpty) {
        _log.add('📝 Sample: ${parsedRows[0].join(" | ")}');
      }
    } catch (e) {
      _log.add('❌ Text parsing error: $e');
    }
  }
  
  String _detectDelimiter(String line) {
    // Try to auto-detect the delimiter
    final delimiters = ['\t', ',', ';', '|'];
    Map<String, int> counts = {};
    
    for (var delimiter in delimiters) {
      counts[delimiter] = line.split(delimiter).length - 1;
    }
    
    // Find the delimiter that appears most frequently
    String? maxDelimiter;
    int maxCount = 0;
    
    counts.forEach((delimiter, count) {
      if (count > maxCount) {
        maxCount = count;
        maxDelimiter = delimiter;
      }
    });
    
    return maxDelimiter ?? '\t'; // Default to tab if no clear winner
  }
  
  List<String> _splitLine(String line, String delimiter) {
    // Handle quoted fields when using comma as delimiter
    if (delimiter == ',' && line.contains('"')) {
      return _parseCSVLine(line);
    }
    
    // Standard split
    return line.split(delimiter)
        .map((field) => field.trim())
        .toList();
  }
  
  // Advanced CSV parsing with quote handling
  List<String> _parseCSVLine(String line) {
    List<String> result = [];
    bool inQuotes = false;
    String currentField = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (i < line.length - 1 && line[i + 1] == '"') {
          // Handle escaped quotes (two consecutive quotes)
          currentField += '"';
          i++; // Skip the next quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // End of field
        result.add(currentField.trim());
        currentField = '';
      } else {
        currentField += char;
      }
    }
    
    // Add the last field
    result.add(currentField.trim());
    return result;
  }

  Future<void> _importToFirestore() async {
    if (_rows == null || _rows!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to import'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processed = 0;
      _successCount = 0;
      _failCount = 0;
      _duplicateCount = 0;
      _log.clear();
      _newEmployees.clear();
      _progress = 0;
    });

    final col = FirebaseFirestore.instance.collection('leaveApplications');
    final empCol = FirebaseFirestore.instance.collection('employees');

    // First, get all existing leave records to check for duplicates
    _log.add('📊 Checking for existing records...');
    
    // Create a map to store document IDs for faster duplicate checking
    // This avoids making a separate Firestore query for each row
    final Map<String, bool> existingDocIds = {};
    
    try {
      // Query all leave applications
      final leaveSnapshot = await col.get();
      
      for (var doc in leaveSnapshot.docs) {
        existingDocIds[doc.id] = true;
      }
      
      _log.add('📊 Found ${existingDocIds.length} existing leave records');
    } catch (e) {
      _log.add('⚠️ Error fetching existing records: $e');
      // Continue with import, but duplicate checking may not work correctly
    }

    for (int i = 0; i < _rows!.length; i++) {
      final row = _rows![i];
      try {
        // Safety check for row length
        if (row.length <= _colIdx['status']!) {
          throw 'Row has insufficient data';
        }

        final name = row[_colIdx['employeeName']!].toString().trim();
        final id = row[_colIdx['employeeId']!].toString().trim();
        final type = row[_colIdx['leaveType']!].toString().trim();
        final s = row[_colIdx['startDate']!].toString().trim();
        final e = row[_colIdx['endDate']!].toString().trim();
        final st = row[_colIdx['status']!].toString().trim();

        // Skip rows with empty essential fields
        if (name.isEmpty || id.isEmpty || type.isEmpty || s.isEmpty || e.isEmpty || st.isEmpty) {
          _log.add('⚠️ Row ${i + 1}: Skipped due to missing data');
          _failCount++;
          continue;
        }
        
        DateTime? start = _tryParse(s);
        if (start == null) {
          _log.add('⚠️ Failed to parse start date: $s');
          throw 'Invalid start date [$s]';
        }
        
        DateTime? end = _tryParse(e);
        if (end == null) {
          _log.add('⚠️ Failed to parse end date: $e');
          throw 'Invalid end date [$e]';
        }

        // Generate document ID using the same logic as before
        final docId = '${id}_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';

        // Check if this record already exists
        if (existingDocIds.containsKey(docId)) {
          _log.add('📘 Row ${i + 1}: Skipped duplicate entry for $name / $id');
          _duplicateCount++;
          _processed++;
          _progress = _processed / _totalRows;
          setState(() {});
          continue;
        }

        // Update employee record
        await empCol.doc(id).set({
          'id': id,
          'name': name,
          'updatedAt': Timestamp.now(),
          'createdAt': Timestamp.now(),
        }, SetOptions(merge: true));

        // Create leave application
        await col.doc(docId).set({
          'employeeId': id,
          'employeeName': name,
          'leaveType': type,
          'startDate': Timestamp.fromDate(start),
          'endDate': Timestamp.fromDate(end),
          'status': st,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        // Add to our local tracking of existing docs to avoid double-imports in the same batch
        existingDocIds[docId] = true;

        _log.add('✅ Row ${i + 1}: $name / $id → $type [$st]');
        _successCount++;
        _newEmployees.add('$name ($id)');
      } catch (err) {
        _log.add('❌ Row ${i + 1}: $err');
        _failCount++;
      } finally {
        _processed++;
        _progress = _processed / _totalRows;
        setState(() {});
        
        // Add a small delay to avoid overwhelming Firestore
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Import finished: $_successCount added, $_duplicateCount skipped (duplicates), $_failCount failed'
        ),
        backgroundColor: _failCount == 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  DateTime? _tryParse(String s) {
    // Clean up the string
    s = s.trim();
    
    // Try multiple date formats to handle different Excel formats
    final formats = [
      'M/d/yy', 'M/d/yyyy', 
      'MM/dd/yy', 'MM/dd/yyyy',
      'yyyy-MM-dd', 'dd/MM/yyyy', 
      'yyyy/MM/dd', 'd-MMM-yyyy',
      'd-MMM-yy', 'dd-MMM-yyyy',
      'dd-MMM-yy', 'dd.MM.yyyy'
    ];
    
    for (var fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(s);
      } catch (_) {
        // Try next format
      }
    }
    
    // If all formats fail, try a more flexible approach
    try {
      return DateTime.parse(s);
    } catch (_) {}
    
    // Last resort: try some manual parsing for common formats
    try {
      // Check for MM/DD/YY format
      if (s.contains('/')) {
        final parts = s.split('/');
        if (parts.length == 3) {
          final month = int.tryParse(parts[0]);
          final day = int.tryParse(parts[1]);
          var year = int.tryParse(parts[2]);
          
          // Handle 2-digit years
          if (year != null && year < 100) {
            year += (year >= 50) ? 1900 : 2000;
          }
          
          if (month != null && day != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
    } catch (_) {}
    
    return null;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD40511)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isProcessing) LinearProgressIndicator(value: _progress),
          ] else if (_isLoading) ...[
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 16),
          if (!_isProcessing && (_successCount > 0 || _failCount > 0 || _duplicateCount > 0)) ...[
            Text('✅ Imported: $_successCount'),
            if (_duplicateCount > 0) Text('📘 Skipped duplicates: $_duplicateCount'),
            Text('❌ Failed: $_failCount'),
            if (_newEmployees.isNotEmpty)
              Text('👤 Updated/Created Employees: ${_newEmployees.length}'),
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