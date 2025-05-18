import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ExcelImportUtility {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Prompt user to pick an Excel file and process it.
  Future<Map<String, dynamic>> importExcelData(_) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (result == null || result.files.isEmpty) {
      return {
        'success': false,
        'message': 'No file selected',
        'stats': null,
      };
    }
    final Uint8List? bytes = result.files.first.bytes;
    if (bytes == null) {
      return {
        'success': false,
        'message': 'Could not read file bytes',
        'stats': null,
      };
    }
    return _processExcelData(bytes);
  }

  /// Process raw Excel bytes (from assets or pick).
  Future<Map<String, dynamic>> importExcelDataFromBytes(
      Uint8List fileBytes) async {
    try {
      return await _processExcelData(fileBytes);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing Excel data: $e',
        'stats': null,
      };
    }
  }

  Future<Map<String, dynamic>> _processExcelData(
      Uint8List fileBytes) async {
    try {
      final excel = Excel.decodeBytes(fileBytes);
      if (excel.tables.isEmpty) {
        return {
          'success': false,
          'message': 'No sheets found',
          'stats': null,
        };
      }

      final sheet = excel.tables.values.first;
      final List<List<Data?>> rows = sheet.rows;
      if (rows.length < 2) {
        return {
          'success': false,
          'message': 'Sheet contains no data rows',
          'stats': null,
        };
      }

      // Header row mapping
      final header = rows.first;
      final idxName = header.indexWhere((c) => c?.value.toString().trim() == 'Employee Name');
      final idxId = header.indexWhere((c) => c?.value.toString().trim() == 'Staff ID');
      final idxType = header.indexWhere((c) => c?.value.toString().trim() == 'Leave Type');
      final idxStart = header.indexWhere((c) => c?.value.toString().trim() == 'Start Date');
      final idxEnd = header.indexWhere((c) => c?.value.toString().trim() == 'End Date');
      final idxStatus = header.indexWhere((c) => c?.value.toString().trim() == 'Status');

      if ([idxName, idxId, idxType, idxStart, idxEnd, idxStatus]
          .any((i) => i < 0)) {
        return {
          'success': false,
          'message': 'Missing required columns',
          'stats': null,
        };
      }

      final WriteBatch empBatch = _firestore.batch();
      final WriteBatch leaveBatch = _firestore.batch();
      int total = 0, success = 0, failed = 0;
      final List<String> errors = [];
      final Map<String, Map<String, dynamic>> uniqueEmps = {};

      // Process each data row
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row[idxId]?.value == null) continue;
        total++;

        try {
          final String name = row[idxName]!.value.toString();
          final String staffId = row[idxId]!.value.toString();
          final String leaveType = row[idxType]!.value.toString();
          final String status = row[idxStatus]?.value?.toString() ?? 'Pending';

          // Parse Start Date cell value
          final dynamic rawStart = row[idxStart]?.value;
          DateTime? startDate;
          if (rawStart is DateTime) {
            startDate = rawStart;
          } else if (rawStart != null) {
            startDate = DateTime.parse(rawStart.toString());
          }

          // Parse End Date cell value
          final dynamic rawEnd = row[idxEnd]?.value;
          DateTime? endDate;
          if (rawEnd is DateTime) {
            endDate = rawEnd;
          } else if (rawEnd != null) {
            endDate = DateTime.parse(rawEnd.toString());
          }

          if (name.isEmpty || staffId.isEmpty || leaveType.isEmpty ||
              startDate == null || endDate == null) {
            throw Exception('Missing required field(s)');
          }

          // Collect unique employees
          uniqueEmps.putIfAbsent(staffId, () => {
                'id': staffId,
                'name': name,
                'department': 'Unassigned',
                'email': '${staffId.toLowerCase()}@dhl.com',
              });

          // Build unique leave application ID
          final String leaveId =
              '${staffId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';

          leaveBatch.set(
            _firestore.collection('leaveApplications').doc(leaveId),
            {
              'employeeId': staffId,
              'employeeName': name,
              'leaveType': leaveType,
              'startDate': Timestamp.fromDate(startDate),
              'endDate': Timestamp.fromDate(endDate),
              'status': status,
              'createdAt': Timestamp.now(),
              'updatedAt': Timestamp.now(),
            },
          );

          success++;
        } catch (e) {
          failed++;
          errors.add('Row ${i + 1}: $e');
        }
      }

      // Commit employee batch
      uniqueEmps.forEach((id, data) {
        empBatch.set(_firestore.collection('employees').doc(id), data);
      });

      await empBatch.commit();
      await leaveBatch.commit();

      return {
        'success': true,
        'message': 'Import completed',
        'stats': {
          'totalRows': total,
          'successfulImports': success,
          'failedImports': failed,
          'uniqueEmployees': uniqueEmps.length,
          'errors': errors,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing Excel data: $e',
        'stats': null,
      };
    }
  }
}

