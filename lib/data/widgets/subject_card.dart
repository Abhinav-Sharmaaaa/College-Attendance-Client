import 'package:flutter/material.dart';
import '../../data/models/attendance_model.dart';

class SubjectCard extends StatelessWidget {
  final AttendanceModel data;
  const SubjectCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isGood = data.percentage >= 75;
    final Color statusColor = isGood ? theme.colorScheme.primary : theme.colorScheme.error;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: ListTile(
        leading: Icon(Icons.book, color: statusColor),
        title: Text(
          data.subjectName,
          style: theme.textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Attended: ${data.attended} / ${data.total}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          '${data.percentage.toStringAsFixed(1)}%',
          style: theme.textTheme.titleMedium!
              .copyWith(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}