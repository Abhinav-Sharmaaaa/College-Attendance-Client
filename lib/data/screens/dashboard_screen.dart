import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../data/local/database_helper.dart';
import '../../data/services/auth_interceptor.dart';
import '../../data/services/html_parser_service.dart';
import '../../data/models/attendance_model.dart';
import '../widgets/subject_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<AttendanceModel> _list = [];
  bool _isSyncing = false;
  bool _isTableView = false;
  String _studentName = 'Loading...';
  String _syncStatusText = '';

  String _selectedMonth = '12';
  String _selectedYear = '2025';
  String _selectedSession = '2025';
  String _selectedSemester = '373';

  final _storage = const FlutterSecureStorage();

  static const String _attendancePageUrl =
    'https://online.uktech.ac.in/ums/Student/User/ViewAttendance';

  final List<Map<String, String>> _sessions = [
    {'id': '2024', 'name': '2024-25'},
    {'id': '2025', 'name': '2025-26'},
    {'id': '2026', 'name': '2026-27'},
  ];

  final List<Map<String, String>> _months = [
    {'id': '0', 'name': 'Full Sem 🌟'},
    {'id': '1', 'name': 'Jan'},
    {'id': '2', 'name': 'Feb'},
    {'id': '3', 'name': 'Mar'},
    {'id': '4', 'name': 'Apr'},
    {'id': '5', 'name': 'May'},
    {'id': '6', 'name': 'Jun'},
    {'id': '7', 'name': 'Jul'},
    {'id': '8', 'name': 'Aug'},
    {'id': '9', 'name': 'Sep'},
    {'id': '10', 'name': 'Oct'},
    {'id': '11', 'name': 'Nov'},
    {'id': '12', 'name': 'Dec'},
  ];

  final List<Map<String, String>> _semesters = [
    {'id': '371', 'name': 'Sem 1'},
    {'id': '372', 'name': 'Sem 2'},
    {'id': '373', 'name': 'Sem 3'},
    {'id': '374', 'name': 'Sem 4'},
    {'id': '375', 'name': 'Sem 5'},
    {'id': '376', 'name': 'Sem 6'},
    {'id': '377', 'name': 'Sem 7'},
    {'id': '378', 'name': 'Sem 8'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await _loadPreferences();
    _list = await DatabaseHelper.instance.getCached();
    _studentName = await _storage.read(key: 'student_name') ?? 'Student';
    setState(() {});

    await _sync();
  }

  // Load persisted UI preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedSession = prefs.getString('selectedSession') ?? _selectedSession;
      _selectedSemester = prefs.getString('selectedSemester') ?? _selectedSemester;
      _selectedMonth = prefs.getString('selectedMonth') ?? _selectedMonth;
      _selectedYear = prefs.getString('selectedYear') ?? _selectedYear;
      _isTableView = prefs.getBool('isTableView') ?? _isTableView;
    });
  }

  // Save UI preferences after changes
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedSession', _selectedSession);
    await prefs.setString('selectedSemester', _selectedSemester);
    await prefs.setString('selectedMonth', _selectedMonth);
    await prefs.setString('selectedYear', _selectedYear);
    await prefs.setBool('isTableView', _isTableView);
  }

  // NOTE: _clearSession was previously defined but never used in the UI.
  // It has been removed to keep the codebase clean.

  Future<void> _sync() async {
    setState(() {
      _isSyncing = true;
      _syncStatusText = 'Connecting...';
    });
    try {
      final auth = AuthInterceptorService();
      final headers = await auth.getAuthHeaders();

      headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/121.0.0.0';
      headers['Referer'] = _attendancePageUrl;
      headers['X-Requested-With'] = 'XMLHttpRequest';

      var pageRes =
          await http.get(Uri.parse(_attendancePageUrl), headers: headers);
      var params = HtmlParserService().extractParams(pageRes.body);

      if (!HtmlParserService().hasValidParams(params)) {
        throw Exception(
          'Could not extract student params from the portal page. '
          'The session may have expired — please re-login.',
        );
      }

      if ((params['StudentName'] ?? '').isNotEmpty) {
        _studentName = params['StudentName']!;
        await _storage.write(key: 'student_name', value: _studentName);
        if (mounted) setState(() {});
      }

      if (_selectedMonth == '0') {
        await _aggregateFullSemester(headers, params);
      } else {
        await _fetchSingleMonth(headers, params, _selectedMonth, _selectedYear);
      }
    } catch (e) {
      debugPrint('Sync error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatusText = '';
        });
      }
    }
  }

  Uri _buildAttendanceUri(
    Map<String, String> params, {
    required String month,
    required String year,
  }) {
    return Uri.https(
      'online.uktech.ac.in',
      '/ums/Student/User/ShowStudentAttendanceListByRollNoDOB',
      {
        'CollegeId': params['CollegeId']!,
        'CourseId': params['CourseId']!,
        'BranchId': params['BranchId']!,
        'CourseBranchDurationId': _selectedSemester,
        'StudentAdmissionId': params['StudentAdmissionId']!,
        'DateOfBirth': params['DOB'] ?? '',
        'SessionYear': _selectedSession,
        'RollNo': params['RollNo'] ?? '',
        'Year': year,
        'MonthId': month,
      },
    );
  }

  String _decodeResponseBody(String raw) {
    if (raw.startsWith('"') && raw.endsWith('"')) {
      try {
        return jsonDecode(raw) as String;
      } catch (_) {}
    }
    return raw;
  }

  Future<void> _aggregateFullSemester(
    Map<String, String> headers,
    Map<String, String> params,
  ) async {
    Map<String, AttendanceModel> mergedData = {};
    int baseYear = int.parse(_selectedSession);

    List<Map<String, int>> scanList = [
      {'m': 8, 'y': baseYear},
      {'m': 9, 'y': baseYear},
      {'m': 10, 'y': baseYear},
      {'m': 11, 'y': baseYear},
      {'m': 12, 'y': baseYear},
      {'m': 1, 'y': baseYear + 1},
      {'m': 2, 'y': baseYear + 1},
      {'m': 3, 'y': baseYear + 1},
      {'m': 4, 'y': baseYear + 1},
      {'m': 5, 'y': baseYear + 1},
      {'m': 6, 'y': baseYear + 1},
    ];

    for (var target in scanList) {
      if (!mounted) return;
      setState(
        () => _syncStatusText = "Scanning ${target['m']}/${target['y']}...",
      );

      final uri = _buildAttendanceUri(
        params,
        month: target['m'].toString(),
        year: target['y'].toString(),
      );

      var response = await http.get(uri, headers: headers);
      final rawHtml = _decodeResponseBody(response.body);
      var monthData = HtmlParserService().parseAttendance(rawHtml);

      for (var subject in monthData) {
        if (mergedData.containsKey(subject.subjectName)) {
          var existing = mergedData[subject.subjectName]!;
          int newHeld = existing.total + subject.total;
          int newAttended = existing.attended + subject.attended;
          mergedData[subject.subjectName] = AttendanceModel(
            subjectName: subject.subjectName,
            total: newHeld,
            attended: newAttended,
            percentage: double.parse(
              ((newAttended / newHeld) * 100).toStringAsFixed(1),
            ),
            dailyStatus: {},
          );
        } else {
          mergedData[subject.subjectName] = AttendanceModel(
            subjectName: subject.subjectName,
            total: subject.total,
            attended: subject.attended,
            percentage: subject.percentage,
            dailyStatus: {},
          );
        }
      }

      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (mounted) setState(() => _list = mergedData.values.toList());
  }

  Future<void> _fetchSingleMonth(
    Map<String, String> headers,
    Map<String, String> params,
    String m,
    String y,
  ) async {
    final uri = _buildAttendanceUri(params, month: m, year: y);
    var response = await http.get(uri, headers: headers);
    final rawHtml = _decodeResponseBody(response.body);

    var fresh = HtmlParserService().parseAttendance(rawHtml);
    if (fresh.isNotEmpty) {
      await DatabaseHelper.instance.saveAttendance(fresh);
      if (mounted) setState(() => _list = fresh);
    } else {
      if (mounted) {
        setState(() => _list = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No data found for Month $m / $y'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }
  }

  double get _overallPercentage {
    if (_list.isEmpty) return 0.0;
    int totalHeld = _list.fold(0, (sum, item) => sum + item.total);
    int totalAttended = _list.fold(0, (sum, item) => sum + item.attended);
    return totalHeld == 0 ? 0.0 : (totalAttended / totalHeld) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _sync,
          color: Colors.cyanAccent,
          backgroundColor: const Color(0xFF18181B),
          child: CustomScrollView(
            physics:
                const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildFilterBar()),
              if (_list.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_graph_rounded,
                          size: 60,
                          color: Colors.white.withAlpha((0.1 * 255).round()),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSyncing ? _syncStatusText : 'No Data Found',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.4 * 255).round()),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_isTableView)
                SliverToBoxAdapter(child: _buildTableView())
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => SubjectCard(data: _list[index]),
                      childCount: _list.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    double overall = _overallPercentage;
    Color glowColor =
        overall >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _studentName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: IconButton(
                  icon: Icon(
                    _isTableView
                        ? Icons.grid_view_rounded
                        : Icons.table_chart_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () async {
                      setState(() => _isTableView = !_isTableView);
                      await _savePreferences();
                    },
                  tooltip: 'Toggle View',
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF18181B),
                  glowColor.withAlpha((0.15 * 255).round()),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: glowColor.withAlpha((0.3 * 255).round()), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withAlpha((0.1 * 255).round()),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                CircularPercentIndicator(
                  radius: 45.0,
                  lineWidth: 8.0,
                  animation: true,
                  percent: (overall / 100).clamp(0, 1),
                  center: Text(
                    '${overall.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  progressColor: glowColor,
                  backgroundColor: Colors.white.withAlpha((0.05 * 255).round()),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMonth == '0'
                            ? 'Full Semester Total'
                            : 'Overall Attendance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSyncing
                            ? _syncStatusText
                            : (overall >= 75
                                ? 'You are in the safe zone! Keep it up.'
                                : 'Warning: Shortage of attendance!'),
                        style: TextStyle(
                          color: _isSyncing
                              ? Colors.cyanAccent
                              : Colors.white.withAlpha((0.6 * 255).round()),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildPillDrop(
            _selectedSession,
            _sessions.map((s) => s['id']!).toList(),
            (v) => _selectedSession = v!,
            prefix: 'Session: ',
            displayMap: _sessions,
          ),
          const SizedBox(width: 10),
          _buildPillDrop(
            _selectedSemester,
            _semesters.map((s) => s['id']!).toList(),
            (v) => _selectedSemester = v!,
            displayMap: _semesters,
          ),
          const SizedBox(width: 10),
          _buildPillDrop(
            _selectedMonth,
            _months.map((m) => m['id']!).toList(),
            (v) {
              _selectedMonth = v!;

              if (v != '0') _selectedYear = _selectedSession;
            },
            displayMap: _months,
          ),
          const SizedBox(width: 10),
          if (_selectedMonth != '0')
            _buildPillDrop(
              _selectedYear,
              ['2024', '2025', '2026', '2027'],
              (v) => _selectedYear = v!,
            ),
        ],
      ),
    );
  }

  Widget _buildPillDrop(
    String current,
    List<String> values,
    Function(String?) fn, {
    String prefix = '',
    List<Map<String, String>>? displayMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          dropdownColor: const Color(0xFF18181B),
          icon: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white54,
              size: 18,
            ),
          ),
          style: TextStyle(
            color: current == '0' ? Colors.amberAccent : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: values.map((val) {
            String label = displayMap != null
                ? displayMap.firstWhere((e) => e['id'] == val)['name']!
                : val;
            return DropdownMenuItem(value: val, child: Text(prefix + label));
          }).toList(),
          onChanged: (v) async {
            setState(() => fn(v));
            await _savePreferences();
            await _sync();
          },
        ),
      ),
    );
  }

  Widget _buildTableView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: DataTable(

          headingRowColor: WidgetStateProperty.all(Colors.black12),
          columnSpacing: 25,
          columns: const [
            DataColumn(
              label: Text(
                'Subject',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Held',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Attended',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                '%',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          rows: _list.map((e) {
            Color c = e.percentage >= 75
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444);
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    e.subjectName.length > 20
                        ? '${e.subjectName.substring(0, 20)}...'
                        : e.subjectName,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    e.total.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    e.attended.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    '${e.percentage}%',
                    style: TextStyle(color: c, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

}