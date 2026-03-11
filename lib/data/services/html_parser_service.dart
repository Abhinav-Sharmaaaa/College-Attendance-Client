import 'package:html/parser.dart' show parse;
import '../models/attendance_model.dart';

class HtmlParserService {
  Map<String, String> extractParams(String html) {
    var doc = parse(html);

    var nameNodes = doc.querySelectorAll('#lblStudentName');
    String studentName =
        nameNodes.length > 1 ? nameNodes[1].text.trim() : 'Student';

    return {
      'CollegeId':
          doc.querySelector('#hdnCollegeId')?.attributes['value'] ?? '',
      'CourseId':
          doc.querySelector('#hdnCourseId')?.attributes['value'] ?? '',
      'BranchId':
          doc.querySelector('#hdnBranchId')?.attributes['value'] ?? '',
      'StudentAdmissionId':
          doc.querySelector('#hdnStudentAdmissionId')?.attributes['value'] ?? '',
      'RollNo': doc.querySelector('#RollNo')?.attributes['value'] ?? '',
      'DOB': doc.querySelector('#DateOfBirth')?.attributes['value'] ?? '',
      'StudentName': studentName,
    };
  }

  bool hasValidParams(Map<String, String> params) {
    return (params['CollegeId'] ?? '').isNotEmpty &&
        (params['CourseId'] ?? '').isNotEmpty &&
        (params['BranchId'] ?? '').isNotEmpty &&
        (params['StudentAdmissionId'] ?? '').isNotEmpty;
  }

  List<AttendanceModel> parseAttendance(String html) {
    List<AttendanceModel> list = [];
    var document = parse(html);
    var rows = document.querySelectorAll('tr');

    for (var row in rows) {
      var cells = row.querySelectorAll('td');
      var totalHeld = row.querySelector('.clsTCH')?.text.trim();
      var totalAttended = row.querySelector('.clsTP')?.text.trim();

      if (cells.length > 4 && totalHeld != null && totalAttended != null) {
        String name =
            cells[0].text.trim().replaceAll(RegExp(r'\[.*?\]'), '').trim();
        if (name.toLowerCase().contains('total') || name.isEmpty) continue;

        int held = int.tryParse(totalHeld) ?? 0;
        int present = int.tryParse(totalAttended) ?? 0;

        Map<String, String> daily = {};

        int tchIndex = -1;
        for (int i = 0; i < cells.length; i++) {
          if (cells[i].classes.contains('clsTCH')) {
            tchIndex = i;
            break;
          }
        }

        int endIndex = tchIndex > 1 ? tchIndex : cells.length - 4;

        for (int i = 1; i < endIndex; i++) {
          String status = cells[i].text.trim();
          if (status.isNotEmpty) {
            daily[i.toString()] = status.replaceAll(RegExp(r'\s+|,+'), '');
          }
        }

        if (held > 0) {
          list.add(AttendanceModel(
            subjectName: name,
            attended: present,
            total: held,
            percentage:
                double.parse(((present / held) * 100).toStringAsFixed(1)),
            dailyStatus: daily,
          ));
        }
      }
    }
    return list;
  }
}