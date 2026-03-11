import 'dart:convert';

class AttendanceModel {
  final String subjectName;
  final int attended;
  final int total;
  final double percentage;
  final Map<String, String> dailyStatus;

  AttendanceModel({
    required this.subjectName,
    required this.attended,
    required this.total,
    required this.percentage,
    required this.dailyStatus,
  });

  Map<String, dynamic> toMap() => {
        'subjectName': subjectName,
        'attended': attended,
        'total': total,
        'percentage': percentage,
        'dailyStatus': jsonEncode(dailyStatus),
      };

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      subjectName: map['subjectName'] as String,
      attended: map['attended'] as int,
      total: map['total'] as int,
      percentage: map['percentage'] as double,
      dailyStatus: Map<String, String>.from(
        jsonDecode(map['dailyStatus'] as String? ?? '{}') as Map,
      ),
    );
  }
}