import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../data/models/attendance_model.dart';

class SubjectCard extends StatelessWidget {
  final AttendanceModel data;
  const SubjectCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    Color color =
        data.percentage < 75 ? Colors.redAccent : Colors.greenAccent;
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 30.0,
            lineWidth: 5.0,
            percent: (data.percentage / 100).clamp(0, 1),
            center: Text(
              '${data.percentage.toInt()}%',
              style: TextStyle(color: color, fontSize: 12),
            ),
            progressColor: color,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              data.subjectName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${data.attended}/${data.total}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}