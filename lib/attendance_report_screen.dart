import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  DateTime _selectedMonth = DateTime.now();
  String _selectedEmployeeId = 'all';
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _employeeReports = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _loadEmployees();
      await _loadReports();
    } catch (e) {
      setState(() => _errorMessage = "حدث خطأ: $e");
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadEmployees() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .where('isActive', isEqualTo: true)
        .get();
    
    _employees = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'] ?? 'بدون اسم',
        'email': data['email'] ?? '',
      };
    }).toList();
  }
  
  Future<void> _loadReports() async {
    _employeeReports.clear();
    
    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    
    for (var employee in _employees) {
      if (_selectedEmployeeId != 'all' && employee['id'] != _selectedEmployeeId) {
        continue;
      }
      
      // 1️⃣ جلب سجلات الحضور
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('employeeId', isEqualTo: employee['id'])
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();
      
      // 2️⃣ جلب طلبات الإجازة (type = 'إجازة' أو 'leave')
      final leaveRequestsSnapshot = await _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employee['id'])
          .where('type', whereIn: ['إجازة', 'leave'])
          .get();
      
      // 3️⃣ جلب طلبات التأخير (type = 'تأخير' أو 'delay')
      final delayRequestsSnapshot = await _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employee['id'])
          .where('type', whereIn: ['تأخير', 'delay'])
          .get();
      
      // 4️⃣ جلب الخصومات
      final deductionsSnapshot = await _firestore
          .collection('deductions')
          .where('employeeId', isEqualTo: employee['id'])
          .where('month', isEqualTo: _selectedMonth.month)
          .get();
      
      // 5️⃣ حساب الإحصائيات
      int presentDays = 0;
      int lateDays = 0;
      List<Map<String, dynamic>> attendanceDetails = [];
      
      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'absent';
        if (status == 'present') presentDays++;
        else if (status == 'late') lateDays++;
        
        attendanceDetails.add({
          'date': data['date'] ?? '',
          'status': status,
          'checkInTime': data['checkInTime'] ?? '--:--',
          'checkOutTime': data['checkOutTime'] ?? '--:--',
          'location': data['location'] ?? 'موقع العمل',
        });
      }
      
      final daysInMonth = endDate.day;
      final absentDays = daysInMonth - (presentDays + lateDays);
      final attendanceRate = daysInMonth > 0 
          ? ((presentDays + lateDays) / daysInMonth * 100).toStringAsFixed(1)
          : '0';
      
      // 6️⃣ تجهيز تفاصيل الإجازات
      List<Map<String, dynamic>> leaveDetails = [];
      for (var doc in leaveRequestsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String statusText = 'معلق';
        Color statusColor = Colors.orange;
        if (data['status'] == 'approved') {
          statusText = 'موافق';
          statusColor = Colors.green;
        } else if (data['status'] == 'rejected') {
          statusText = 'مرفوض';
          statusColor = Colors.red;
        }
        
        // ✅ استخدام 'date' بدلاً من 'startDate'
        String requestDate = data['date'] ?? '';
        if (requestDate.isEmpty && data['startDate'] != null) {
          requestDate = data['startDate'];
        }
        
        leaveDetails.add({
          'date': requestDate,
          'reason': data['reason'] ?? '',
          'statusText': statusText,
          'statusColor': statusColor,
        });
      }
      
      // 7️⃣ تجهيز تفاصيل طلبات التأخير
      List<Map<String, dynamic>> delayDetails = [];
      for (var doc in delayRequestsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String statusText = 'معلق';
        Color statusColor = Colors.orange;
        if (data['status'] == 'approved') {
          statusText = 'موافق';
          statusColor = Colors.green;
        } else if (data['status'] == 'rejected') {
          statusText = 'مرفوض';
          statusColor = Colors.red;
        }
        
        // ✅ استخدام 'date' بدلاً من 'startDate'
        String requestDate = data['date'] ?? '';
        if (requestDate.isEmpty && data['startDate'] != null) {
          requestDate = data['startDate'];
        }
        
        delayDetails.add({
          'date': requestDate,
          'reason': data['reason'] ?? '',
          'statusText': statusText,
          'statusColor': statusColor,
        });
      }
      
      // 8️⃣ تجهيز تفاصيل الخصومات
      double totalDeduction = 0;
      List<Map<String, dynamic>> deductionDetails = [];
      for (var doc in deductionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        totalDeduction += amount;
        
        String deductionDate = '';
        if (data['date'] != null) {
          if (data['date'] is Timestamp) {
            deductionDate = DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate());
          } else {
            deductionDate = data['date'].toString();
          }
        }
        
        deductionDetails.add({
          'amount': amount,
          'reason': data['reason'] ?? 'خصم',
          'date': deductionDate,
        });
      }
      
      _employeeReports.add({
        'id': employee['id'],
        'name': employee['name'],
        'email': employee['email'],
        'presentDays': presentDays,
        'lateDays': lateDays,
        'absentDays': absentDays < 0 ? 0 : absentDays,
        'attendanceRate': attendanceRate,
        'totalDeduction': totalDeduction,
        'totalLeaveRequests': leaveRequestsSnapshot.docs.length,
        'totalDelayRequests': delayRequestsSnapshot.docs.length,
        'attendanceDetails': attendanceDetails,
        'leaveDetails': leaveDetails,
        'delayDetails': delayDetails,
        'deductionDetails': deductionDetails,
      });
    }
    
    _employeeReports.sort((a, b) => double.parse(b['attendanceRate']).compareTo(double.parse(a['attendanceRate'])));
  }
  
  void _showEmployeeDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        report['name'].toString()[0],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['name'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            report['email'],
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // بطاقة الإحصائيات
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('حاضر', report['presentDays'], Colors.green),
                            _buildStatItem('متأخر', report['lateDays'], Colors.orange),
                            _buildStatItem('غائب', report['absentDays'], Colors.red),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // نسبة الحضور
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('نسبة الحضور', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: double.parse(report['attendanceRate']) / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    color: double.parse(report['attendanceRate']) >= 80 ? Colors.green : Colors.orange,
                                    minHeight: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${report['attendanceRate']}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: double.parse(report['attendanceRate']) >= 80 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // الخصومات
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('💰 إجمالي الخصومات', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              '${report['totalDeduction']} ج.م',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // طلبات الإجازة
                      if (report['leaveDetails'].isNotEmpty) ...[
                        _buildSectionHeader('📅 طلبات الإجازة (${report['totalLeaveRequests']})', Icons.beach_access),
                        const SizedBox(height: 8),
                        ...report['leaveDetails'].map<Widget>((item) => _buildRequestCard(
                          icon: Icons.beach_access,
                          date: _formatDateSimple(item['date']),
                          reason: item['reason'],
                          statusText: item['statusText'],
                          statusColor: item['statusColor'],
                        )),
                        const SizedBox(height: 16),
                      ],
                      
                      // طلبات التأخير
                      if (report['delayDetails'].isNotEmpty) ...[
                        _buildSectionHeader('⏰ طلبات التأخير (${report['totalDelayRequests']})', Icons.access_time),
                        const SizedBox(height: 8),
                        ...report['delayDetails'].map<Widget>((item) => _buildRequestCard(
                          icon: Icons.access_time,
                          date: _formatDateSimple(item['date']),
                          reason: item['reason'],
                          statusText: item['statusText'],
                          statusColor: item['statusColor'],
                        )),
                        const SizedBox(height: 16),
                      ],
                      
                      // الخصومات بالتفصيل
                      if (report['deductionDetails'].isNotEmpty) ...[
                        _buildSectionHeader('💰 الخصومات', Icons.money_off),
                        const SizedBox(height: 8),
                        ...report['deductionDetails'].map<Widget>((item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.money_off, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['reason'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                    Text('📅 ${item['date']}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Text(
                                '${item['amount']} ج.م',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                      
                      // تفاصيل الحضور اليومية
                      _buildSectionHeader('📋 تفاصيل الحضور اليومية', Icons.calendar_today),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: report['attendanceDetails'].map<Widget>((day) {
                            Color statusColor;
                            String statusText;
                            switch (day['status']) {
                              case 'present':
                                statusColor = Colors.green;
                                statusText = 'حاضر';
                                break;
                              case 'late':
                                statusColor = Colors.orange;
                                statusText = 'متأخر';
                                break;
                              default:
                                statusColor = Colors.red;
                                statusText = 'غائب';
                            }
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: const Color(0xFFEEEEEE))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDate(day['date']), style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (day['checkInTime'] != '--:--')
                                        Text(
                                          '🕐 ${day['checkInTime']} - 🕑 ${day['checkOutTime']}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1A1A2E)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
  
  Widget _buildRequestCard({
    required IconData icon,
    required String date,
    required String reason,
    required String statusText,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📅 $date', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(reason, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '----';
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          return DateFormat('dd/MM/yyyy').format(date);
        }
      }
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
  
  String _formatDateSimple(String dateStr) {
    if (dateStr.isEmpty) return 'غير محدد';
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return '${parts[0]}/${parts[1]}/${parts[2]}';
        }
      }
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('تقرير الحضور الشامل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط التصفية
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedMonth,
                        firstDate: DateTime(2024, 1),
                        lastDate: DateTime.now(),
                        helpText: 'اختر الشهر',
                      );
                      if (date != null) {
                        setState(() => _selectedMonth = date);
                        await _loadReports();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF3B82F6), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedMonth.year} - ${_selectedMonth.month.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEmployeeId,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFF),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('جميع الموظفين')),
                      ..._employees.map((emp) => DropdownMenuItem(value: emp['id'], child: Text(emp['name']))),
                    ],
                    onChanged: (value) async {
                      setState(() => _selectedEmployeeId = value!);
                      await _loadReports();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // قائمة التقارير
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _employeeReports.isEmpty
                        ? const Center(child: Text('لا توجد بيانات'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _employeeReports.length,
                            itemBuilder: (context, index) {
                              final report = _employeeReports[index];
                              final rate = double.parse(report['attendanceRate']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                                ),
                                child: InkWell(
                                  onTap: () => _showEmployeeDetails(report),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: rate >= 80 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                              child: Text(
                                                report['name'].toString()[0],
                                                style: TextStyle(
                                                  color: rate >= 80 ? Colors.green : Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    report['name'],
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: rate / 100,
                                                      backgroundColor: Colors.grey.shade200,
                                                      color: rate >= 80 ? Colors.green : Colors.orange,
                                                      minHeight: 6,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '$rate%',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: rate >= 80 ? Colors.green : Colors.orange,
                                                  ),
                                                ),
                                                if (report['totalDeduction'] > 0)
                                                  Text(
                                                    'خصم: ${report['totalDeduction']} ج.م',
                                                    style: const TextStyle(fontSize: 11, color: Colors.red),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildBadge('حاضر', report['presentDays'], Colors.green),
                                            _buildBadge('متأخر', report['lateDays'], Colors.orange),
                                            _buildBadge('غائب', report['absentDays'], Colors.red),
                                            _buildBadge('إجازات', report['totalLeaveRequests'], Colors.blue),
                                            _buildBadge('تأخير طلب', report['totalDelayRequests'], Colors.purple),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBadge(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}