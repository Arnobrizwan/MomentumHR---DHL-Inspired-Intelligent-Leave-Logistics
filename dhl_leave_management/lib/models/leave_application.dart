import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveApplication {
  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? reason;
  final String? rejectReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  LeaveApplication({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
    this.rejectReason,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  /// Safely creates a LeaveApplication from Firestore doc
  factory LeaveApplication.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      
      // Debug print to verify data
      print('Parsing doc ${doc.id}: ${data != null ? 'Data exists' : 'No data'}');
      
      if (data == null) {
        throw Exception('Document data is null for doc: ${doc.id}');
      }

      // Safe extraction of field values with debug logs
      final String employeeId = data['employeeId']?.toString() ?? '';
      final String employeeName = data['employeeName']?.toString() ?? '';
      final String leaveType = data['leaveType']?.toString() ?? 'Unknown';
      final String status = data['status']?.toString() ?? 'Pending';
      
      // Debug logs for important fields
      print('Doc ${doc.id} fields: employeeId=$employeeId, employeeName=$employeeName, status=$status');
      
      // Safe conversion of timestamps
      DateTime? startDate;
      DateTime? endDate;
      DateTime? createdAt;
      DateTime? updatedAt;
      
      try {
        startDate = (data['startDate'] as Timestamp?)?.toDate();
        endDate = (data['endDate'] as Timestamp?)?.toDate();
        createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
        
        print('Doc ${doc.id} dates parsed successfully');
      } catch (dateError) {
        print('Error parsing dates for doc ${doc.id}: $dateError');
      }
      
      return LeaveApplication(
        id: doc.id,
        employeeId: employeeId.trim(),
        employeeName: employeeName.trim(),
        leaveType: leaveType.trim(),
        startDate: startDate ?? DateTime.now(),
        endDate: endDate ?? DateTime.now().add(const Duration(days: 1)),
        status: status.trim(),
        reason: data['reason']?.toString(),
        rejectReason: data['rejectReason']?.toString(),
        createdAt: createdAt,
        updatedAt: updatedAt ?? createdAt,
        createdBy: data['createdBy']?.toString(),
        updatedBy: data['updatedBy']?.toString(),
      );
    } catch (e) {
      print('Failed to parse LeaveApplication document ${doc.id}: $e');
      
      // Instead of throwing, which would break the entire list, 
      // return a placeholder object that can at least be displayed
      return LeaveApplication(
        id: doc.id,
        employeeId: '',
        employeeName: 'Data Error',
        leaveType: 'Unknown',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        status: 'Error',
        reason: 'Error parsing document: $e',
      );
    }
  }

  /// Converts to Firestore-ready map
  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveType': leaveType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'reason': reason,
      'rejectReason': rejectReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : Timestamp.now(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : Timestamp.now(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  /// Calculates duration excluding weekends
  int calculateDuration() {
    int days = 0;
    DateTime date = startDate;
    while (!date.isAfter(endDate)) {
      if (date.weekday < 6) days++;
      date = date.add(const Duration(days: 1));
    }
    return days;
  }

  /// Returns a new instance with updated fields
  LeaveApplication copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? reason,
    String? rejectReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return LeaveApplication(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      rejectReason: rejectReason ?? this.rejectReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}