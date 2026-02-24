import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../data/local/database_helper.dart';
import '../../data/services/auth_interceptor.dart';
import '../../data/services/html_parser_service.dart';
import '../../data/models/attendance_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<AttendanceModel> _list = [];
  bool _isSyncing = false;
  bool _isTableView = false; // NEW: Toggle between Card and Table
  String _studentName = "Loading...";
  String _syncStatusText = ""; // NEW: Shows what is being fetched

  // Selectors
  String _selectedMonth = "12";
  String _selectedYear = "2025";
  String _selectedSession = "2025"; 
  String _selectedSemester = "373";

  final _storage = const FlutterSecureStorage();

  final List<Map<String, String>> _sessions = [
    {"id": "2024", "name": "2024-25"},
    {"id": "2025", "name": "2025-26"},
    {"id": "2026", "name": "2026-27"},
  ];

  // NEW: Added "0" for Full Semester Magic Mode!
  final List<Map<String, String>> _months = [
    {"id": "0", "name": "Full Sem 🌟"}, 
    {"id": "1", "name": "Jan"}, {"id": "2", "name": "Feb"}, {"id": "3", "name": "Mar"}, 
    {"id": "4", "name": "Apr"}, {"id": "5", "name": "May"}, {"id": "6", "name": "Jun"},
    {"id": "7", "name": "Jul"}, {"id": "8", "name": "Aug"}, {"id": "9", "name": "Sep"}, 
    {"id": "10", "name": "Oct"}, {"id": "11", "name": "Nov"}, {"id": "12", "name": "Dec"},
  ];

  final List<Map<String, String>> _semesters = [
    {"id": "371", "name": "Sem 1"}, {"id": "372", "name": "Sem 2"}, {"id": "373", "name": "Sem 3"}, {"id": "374", "name": "Sem 4"},
    {"id": "375", "name": "Sem 5"}, {"id": "376", "name": "Sem 6"}, {"id": "377", "name": "Sem 7"}, {"id": "378", "name": "Sem 8"},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    _list = await DatabaseHelper.instance.getCached();
    _studentName = await _storage.read(key: "student_name") ?? "Student";
    setState(() {});
    _sync();
  }

  Future<void> _sync() async {
    setState(() { _isSyncing = true; _syncStatusText = "Connecting..."; });
    try {
      final auth = AuthInterceptorService();
      final headers = await auth.getAuthHeaders();
      
      headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/121.0.0.0';
      headers['Referer'] = 'https://online.uktech.ac.in/ums/Student/User/ViewAttendance';
      headers['X-Requested-With'] = 'XMLHttpRequest';

      var pageRes = await http.get(Uri.parse(headers['Referer']!), headers: headers);
      var params = HtmlParserService().extractParams(pageRes.body);

      if (params['StudentName'] != null && params['StudentName']!.isNotEmpty) {
        _studentName = params['StudentName']!;
        await _storage.write(key: "student_name", value: _studentName);
        if (mounted) setState(() {}); 
      }

      // THE MAGIC AGGREGATOR IF "FULL SEM 🌟" IS SELECTED
      if (_selectedMonth == "0") {
        await _aggregateFullSemester(headers, params);
      } else {
        // Normal Single Month Fetch
        await _fetchSingleMonth(headers, params, _selectedMonth, _selectedYear);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() { _isSyncing = false; _syncStatusText = ""; });
    }
  }

  // --- NEW: THE FULL SEMESTER AGGREGATOR ---
  Future<void> _aggregateFullSemester(Map<String, String> headers, Map<String, String> params) async {
    Map<String, AttendanceModel> mergedData = {};
    int baseYear = int.parse(_selectedSession); // e.g., 2025

    // We scan Aug-Dec of base year, and Jan-Jun of next year to cover the whole academic session.
    List<Map<String, int>> scanList = [
      {"m": 8, "y": baseYear}, {"m": 9, "y": baseYear}, {"m": 10, "y": baseYear}, {"m": 11, "y": baseYear}, {"m": 12, "y": baseYear},
      {"m": 1, "y": baseYear + 1}, {"m": 2, "y": baseYear + 1}, {"m": 3, "y": baseYear + 1}, {"m": 4, "y": baseYear + 1}, {"m": 5, "y": baseYear + 1}, {"m": 6, "y": baseYear + 1},
    ];

    for (var target in scanList) {
      if (!mounted) return;
      setState(() => _syncStatusText = "Scanning ${target['m']}/${target['y']}...");
      
      final uri = Uri.https("online.uktech.ac.in", "/ums/Student/User/ShowStudentAttendanceListByRollNoDOB", {
        "CollegeId": params['CollegeId'] ?? "54", "CourseId": params['CourseId'] ?? "1", "BranchId": params['BranchId'] ?? "70",
        "CourseBranchDurationId": _selectedSemester, "StudentAdmissionId": params['StudentAdmissionId'] ?? "",
        "DateOfBirth": params['DOB'] ?? "", "SessionYear": _selectedSession, "RollNo": params['RollNo'] ?? "",
        "Year": target['y'].toString(), "MonthId": target['m'].toString(),
      });
      
      var response = await http.get(uri, headers: headers);
      String rawHtml = response.body;
      if (rawHtml.startsWith('"') && rawHtml.endsWith('"')) {
        try { rawHtml = jsonDecode(rawHtml); } catch (_) {}
      }

      var monthData = HtmlParserService().parseAttendance(rawHtml);

      // Merge the subjects!
      for (var subject in monthData) {
        if (mergedData.containsKey(subject.subjectName)) {
          var existing = mergedData[subject.subjectName]!;
          int newHeld = existing.total + subject.total;
          int newAttended = existing.attended + subject.attended;
          mergedData[subject.subjectName] = AttendanceModel(
            subjectName: subject.subjectName, total: newHeld, attended: newAttended,
            percentage: double.parse(((newAttended / newHeld) * 100).toStringAsFixed(1)),
            dailyStatus: {}, // Hide daily grid in full sem mode
          );
        } else {
          mergedData[subject.subjectName] = AttendanceModel(
            subjectName: subject.subjectName, total: subject.total, attended: subject.attended, percentage: subject.percentage, dailyStatus: {},
          );
        }
      }
      // Small delay so we don't spam the server and get blocked
      await Future.delayed(const Duration(milliseconds: 150)); 
    }

    if (mounted) setState(() => _list = mergedData.values.toList());
  }

  Future<void> _fetchSingleMonth(Map<String, String> headers, Map<String, String> params, String m, String y) async {
    final uri = Uri.https("online.uktech.ac.in", "/ums/Student/User/ShowStudentAttendanceListByRollNoDOB", {
      "CollegeId": params['CollegeId'] ?? "54", "CourseId": params['CourseId'] ?? "1", "BranchId": params['BranchId'] ?? "70",
      "CourseBranchDurationId": _selectedSemester, "StudentAdmissionId": params['StudentAdmissionId'] ?? "",
      "DateOfBirth": params['DOB'] ?? "", "SessionYear": _selectedSession, "RollNo": params['RollNo'] ?? "",
      "Year": y, "MonthId": m,
    });
    
    var response = await http.get(uri, headers: headers);
    String rawHtml = response.body;
    if (rawHtml.startsWith('"') && rawHtml.endsWith('"')) {
      try { rawHtml = jsonDecode(rawHtml); } catch (_) {}
    }

    var fresh = HtmlParserService().parseAttendance(rawHtml);
    if (fresh.isNotEmpty) {
      await DatabaseHelper.instance.saveAttendance(fresh);
      if (mounted) setState(() => _list = fresh);
    } else {
      if (mounted) {
        setState(() => _list = []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No data found for Month $m / $y"), backgroundColor: Colors.orange.shade800));
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
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildFilterBar()),
              if (_list.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_graph_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(_isSyncing ? _syncStatusText : "No Data Found", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else if (_isTableView)
                SliverToBoxAdapter(child: _buildTableView()) // THE NEW TABLE VIEW
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 30),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildSubjectCard(_list[index]), childCount: _list.length)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    double overall = _overallPercentage;
    Color glowColor = overall >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

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
                    Text("Welcome back,", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                    Text(_studentName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // NEW: View Toggle Button
              Container(
                decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                child: IconButton(
                  icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded, color: Colors.white70),
                  onPressed: () => setState(() => _isTableView = !_isTableView),
                  tooltip: "Toggle View",
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF18181B), glowColor.withOpacity(0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: glowColor.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: glowColor.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Row(
              children: [
                CircularPercentIndicator(
                  radius: 45.0, lineWidth: 8.0, animation: true, percent: (overall / 100).clamp(0, 1),
                  center: Text("${overall.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  progressColor: glowColor, backgroundColor: Colors.white.withOpacity(0.05), circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedMonth == "0" ? "Full Semester Total" : "Overall Attendance", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        _isSyncing ? _syncStatusText : (overall >= 75 ? "You are in the safe zone! Keep it up." : "Warning: Shortage of attendance!"), 
                        style: TextStyle(color: _isSyncing ? Colors.cyanAccent : Colors.white.withOpacity(0.6), fontSize: 12, height: 1.3)
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
          _buildPillDrop(_selectedSession, _sessions.map((s) => s['id']!).toList(), (v) => _selectedSession = v!, prefix: "Session: ", displayMap: _sessions),
          const SizedBox(width: 10),
          _buildPillDrop(_selectedSemester, _semesters.map((s) => s['id']!).toList(), (v) => _selectedSemester = v!, displayMap: _semesters),
          const SizedBox(width: 10),
          _buildPillDrop(_selectedMonth, _months.map((m) => m['id']!).toList(), (v) => _selectedMonth = v!, displayMap: _months),
          const SizedBox(width: 10),
          if (_selectedMonth != "0") // Hide year picker if Full Sem is active
            _buildPillDrop(_selectedYear, ["2024", "2025", "2026", "2027"], (v) => _selectedYear = v!),
        ],
      ),
    );
  }

  Widget _buildPillDrop(String current, List<String> values, Function(String?) fn, {String prefix = "", List<Map<String, String>>? displayMap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current, dropdownColor: const Color(0xFF18181B),
          icon: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18)),
          style: TextStyle(color: current == "0" ? Colors.amberAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.w500), // Highlights "Full Sem"
          items: values.map((val) {
            String label = displayMap != null ? displayMap.firstWhere((e) => e['id'] == val)['name']! : val;
            return DropdownMenuItem(value: val, child: Text(prefix + label));
          }).toList(),
          onChanged: (v) { setState(() => fn(v)); _sync(); },
        ),
      ),
    );
  }

  // --- NEW: THE TABLE VIEW ---
  Widget _buildTableView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.black12),
          columnSpacing: 25,
          columns: const [
            DataColumn(label: Text("Subject", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Held", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Attended", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text("%", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
          ],
          rows: _list.map((e) {
            Color c = e.percentage >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
            return DataRow(cells: [
              DataCell(Text(e.subjectName.length > 20 ? "${e.subjectName.substring(0, 20)}..." : e.subjectName, style: const TextStyle(color: Colors.white))),
              DataCell(Text(e.total.toString(), style: const TextStyle(color: Colors.white))),
              DataCell(Text(e.attended.toString(), style: const TextStyle(color: Colors.white))),
              DataCell(Text("${e.percentage}%", style: TextStyle(color: c, fontWeight: FontWeight.bold))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(AttendanceModel data) {
    bool isSafe = data.percentage >= 75;
    Color accent = isSafe ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 15),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white54, collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.subjectName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text("${data.percentage.toInt()}%", style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearPercentIndicator(
                      lineHeight: 6.0, animation: true, percent: (data.percentage / 100).clamp(0, 1),
                      progressColor: accent, backgroundColor: Colors.white.withOpacity(0.05),
                      barRadius: const Radius.circular(10), padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text("${data.attended}/${data.total}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ],
          ),
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
              child: data.dailyStatus.isEmpty
                ? Text(_selectedMonth == "0" ? "Daily tracking hidden in Full Semester mode." : "No daily tracking available.", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12))
                : Wrap(
                    spacing: 8, runSpacing: 8,
                    children: data.dailyStatus.entries.map((entry) {
                      String status = entry.value;
                      bool present = status.contains("P");
                      return Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: present ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: present ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(entry.key, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
                            Text(status, style: TextStyle(color: present ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
            )
          ],
        ),
      ),
    );
  }
}