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
      subjectName: map['subjectName'],
      attended: map['attended'],
      total: map['total'],
      percentage: map['percentage'],
      dailyStatus: Map<String, String>.from(jsonDecode(map['dailyStatus'] ?? '{}')),
    );
  }
}