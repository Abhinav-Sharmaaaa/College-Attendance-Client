import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedSession', _selectedSession);
    await prefs.setString('selectedSemester', _selectedSemester);
    await prefs.setString('selectedMonth', _selectedMonth);
    await prefs.setString('selectedYear', _selectedYear);
    await prefs.setBool('isTableView', _isTableView);
  }

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
            physics: const BouncingScrollPhysics(
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
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.7, end: 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Icon(
                            Icons.auto_graph_rounded,
                            size: 60,
                            color: Colors.white.withAlpha((0.1 * 255).round()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isSyncing ? _syncStatusText : 'No Data Found',
                            key: ValueKey(_isSyncing ? _syncStatusText : 'empty'),
                            style: TextStyle(
                              color: Colors.white.withAlpha((0.4 * 255).round()),
                              fontSize: 16,
                            ),
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
                      (context, index) => SubjectCard(
                        data: _list[index],
                        index: index,
                      ),
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
    final theme = Theme.of(context);
    final overall = _overallPercentage;
    final bool isGood = overall >= 75;
    final Color statusColor =
        isGood ? theme.colorScheme.primary : theme.colorScheme.error;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value.clamp(0.0, 1.0)) * 20),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 56,
                width: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: overall / 100),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          color: statusColor,
                          backgroundColor: theme.colorScheme.surface,
                        );
                      },
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: overall),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '${value.toStringAsFixed(1)}%',
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: theme.textTheme.bodyMedium),
                    Text(
                      _studentName,
                      style: theme.textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isSyncing
                            ? _syncStatusText
                            : isGood
                                ? 'You are in the safe zone! Keep it up.'
                                : 'Warning: Shortage of attendance!',
                        key: ValueKey(_isSyncing ? _syncStatusText : isGood),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: _isSyncing
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Cards'),
                    icon: Icon(Icons.grid_view_rounded),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Table'),
                    icon: Icon(Icons.table_chart_rounded),
                  ),
                ],
                selected: {_isTableView},
                onSelectionChanged: (newSelection) async {
                  setState(() => _isTableView = newSelection.first);
                  await _savePreferences();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          DropdownMenu<String>(
            initialSelection: _selectedSession,
            label: const Text('Session'),
            dropdownMenuEntries: _sessions
                .map((s) => DropdownMenuEntry(value: s['id']!, label: s['name']!))
                .toList(),
            onSelected: (v) async {
              setState(() => _selectedSession = v ?? _selectedSession);
              await _savePreferences();
              await _sync();
            },
          ),
          DropdownMenu<String>(
            initialSelection: _selectedSemester,
            label: const Text('Semester'),
            dropdownMenuEntries: _semesters
                .map((s) => DropdownMenuEntry(value: s['id']!, label: s['name']!))
                .toList(),
            onSelected: (v) async {
              setState(() => _selectedSemester = v ?? _selectedSemester);
              await _savePreferences();
              await _sync();
            },
          ),
          DropdownMenu<String>(
            initialSelection: _selectedMonth,
            label: const Text('Month'),
            dropdownMenuEntries: _months
                .map((m) => DropdownMenuEntry(value: m['id']!, label: m['name']!))
                .toList(),
            onSelected: (v) async {
              setState(() {
                _selectedMonth = v ?? _selectedMonth;
                if (v != null && v != '0') _selectedYear = _selectedSession;
              });
              await _savePreferences();
              await _sync();
            },
          ),
          if (_selectedMonth != '0')
            DropdownMenu<String>(
              initialSelection: _selectedYear,
              label: const Text('Year'),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: '2024', label: '2024'),
                DropdownMenuEntry(value: '2025', label: '2025'),
                DropdownMenuEntry(value: '2026', label: '2026'),
                DropdownMenuEntry(value: '2027', label: '2027'),
              ],
              onSelected: (v) async {
                setState(() => _selectedYear = v ?? _selectedYear);
                await _savePreferences();
                await _sync();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(13)),
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
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Held',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Attended',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                '%',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
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
                  Text(e.total.toString(), style: const TextStyle(color: Colors.white)),
                ),
                DataCell(
                  Text(e.attended.toString(), style: const TextStyle(color: Colors.white)),
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