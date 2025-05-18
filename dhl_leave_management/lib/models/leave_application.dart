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
  final DateTime createdAt;
  final DateTime updatedAt;
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
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // Create from Firestore document
  factory LeaveApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return LeaveApplication(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      leaveType: data['leaveType'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'Pending',
      reason: data['reason'],
      rejectReason: data['rejectReason'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
        ? (data['updatedAt'] as Timestamp).toDate() 
        : (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  // Convert to Firestore document
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  // Calculate leave duration in working days
  int calculateDuration() {
    int days = 0;
    DateTime date = startDate;
    while (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) {
      if (date.weekday < 6) { // Weekdays only (1=Monday, 7=Sunday)
        days++;
      }
      date = date.add(const Duration(days: 1));
    }
    return days;
  }

  // Create a copy with updated fields
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