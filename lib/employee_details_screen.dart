import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final int initialTab; // 0: حضور, 1: طلباتي, 2: خصومات
  
  const EmployeeDetailsScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String employeeId = "";
  String employeeName = "";
  double vacationBalance = 0;
  late TabController _tabController;
  int _currentTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTab;
    _tabController = TabController(length: 3, vsync: this, initialIndex: _currentTabIndex);
    _loadEmployeeData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadEmployeeData() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;
      
      employeeId = user.uid;
      final doc = await _firestore.collection('users').doc(employeeId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        employeeName = data['name'] ?? 'موظف';
        vacationBalance = (data['vacationBalance'] ?? 21).toDouble();
      }
      
      setState(() {});
    } catch (e) {
      print("Error: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(
          _currentTabIndex == 0 ? 'سجل الحضور' : (_currentTabIndex == 1 ? 'طلباتي' : 'سجل الخصومات'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A1A2E),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE94560),
          indicatorSize: TabBarIndicatorSize.label,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          tabs: const [
            Tab(text: '📋 الحضور', icon: Icon(Icons.calendar_today)),
            Tab(text: '📝 طلباتي', icon: Icon(Icons.description)),
            Tab(text: '💰 الخصومات', icon: Icon(Icons.money_off)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceHistory(),
          _buildRequestsHistory(),
          _buildDeductionsHistory(),
        ],
      ),
    );
  }
  
  // ==================== 1. سجل الحضور ====================
  
  Widget _buildAttendanceHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('attendance')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final attendances = snapshot.data!.docs;
        
        if (attendances.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('لا توجد سجلات حضور بعد'),
                SizedBox(height: 8),
                Text('قم بتسجيل حضورك من الصفحة الرئيسية', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: attendances.length,
          itemBuilder: (context, index) {
            final data = attendances[index].data() as Map<String, dynamic>;
            return _buildAttendanceCard(data);
          },
        );
      },
    );
  }
  
  Widget _buildAttendanceCard(Map<String, dynamic> data) {
    final date = data['date'] ?? '----';
    final checkIn = data['checkInTime'] ?? '--:--';
    final checkOut = data['checkOutTime'] ?? 'لم ينصرف';
    final status = data['status'] ?? 'present';
    final location = data['location'] ?? 'موقع العمل';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'present':
        statusColor = const Color(0xFF10B981);
        statusText = 'حاضر';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'late':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'متأخر';
        statusIcon = Icons.warning_rounded;
        break;
      default:
        statusColor = const Color(0xFFEF4444);
        statusText = 'غائب';
        statusIcon = Icons.cancel_rounded;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(date),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.login, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('حضور: $checkIn', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.logout, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('انصراف: $checkOut', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (location.isNotEmpty && location != 'موقع العمل')
                        Text('📍 $location', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // ==================== 2. طلباتي (إجازة + تأخير) ====================
  
  Widget _buildRequestsHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final requests = snapshot.data!.docs;
        
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('لا توجد طلبات'),
                SizedBox(height: 8),
                Text('يمكنك تقديم طلب إجازة أو تأخير من الصفحة الرئيسية', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            return _buildRequestCard(data);
          },
        );
      },
    );
  }
  
  Widget _buildRequestCard(Map<String, dynamic> data) {
    final type = data['type'] ?? 'طلب';
    final isVacation = type == 'إجازة' || type == 'leave';
    final date = data['date'] ?? '----';
    final reason = data['reason'] ?? 'بدون سبب';
    final status = data['status'] ?? 'pending';
    final createdAt = data['createdAt'] as Timestamp?;
    final adminName = data['adminName'];
    final managerName = data['managerName'];
    final adminComment = data['adminComment'];
    final managerComment = data['managerComment'];
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusText = '✅ تمت الموافقة';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusText = '❌ مرفوض';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusText = '⏳ قيد الانتظار';
        statusIcon = Icons.pending_rounded;
    }
    
    String typeIcon = isVacation ? '📅' : '⏰';
    String typeText = isVacation ? 'طلب إجازة' : 'طلب تأخير';
    Color typeColor = isVacation ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      typeIcon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeText,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: typeColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📅 التاريخ: ${_formatDate(date)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('السبب:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(reason, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '📅 تاريخ الطلب: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate())}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ),
            
            if (managerName != null && managerName.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'قرار المشرف: $managerName',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          if (managerComment != null)
                            Text(
                              managerComment,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      status == 'approved' ? Icons.check_circle : (status == 'rejected' ? Icons.cancel : Icons.pending),
                      size: 16,
                      color: status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange),
                    ),
                  ],
                ),
              ),
            
            if (adminName != null && adminName.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'قرار المدير: $adminName',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          if (adminComment != null)
                            Text(
                              adminComment,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      status == 'approved' ? Icons.check_circle : (status == 'rejected' ? Icons.cancel : Icons.pending),
                      size: 16,
                      color: status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // ==================== 3. سجل الخصومات ====================
  
  Widget _buildDeductionsHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deductions')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final deductions = snapshot.data!.docs;
        
        if (deductions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.money_off, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('لا توجد خصومات'),
                SizedBox(height: 8),
                Text('حافظ على انتظامك لتجنب الخصومات', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        // حساب إجمالي الخصومات
        double totalDeductionsAmount = 0;
        for (var doc in deductions) {
          final data = doc.data() as Map<String, dynamic>;
          totalDeductionsAmount += (data['amount'] ?? 0).toDouble();
        }
        
        return Column(
          children: [
            // عرض إجمالي الخصومات
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💰 إجمالي الخصومات',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${totalDeductionsAmount.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // قائمة الخصومات
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: deductions.length,
                itemBuilder: (context, index) {
                  final data = deductions[index].data() as Map<String, dynamic>;
                  return _buildDeductionCard(data);
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildDeductionCard(Map<String, dynamic> data) {
    final amount = (data['amount'] ?? 0).toDouble();
    final reason = data['reason'] ?? 'خصم';
    final date = data['date'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.money_off, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        date != null 
                            ? DateFormat('dd/MM/yyyy').format(date.toDate())
                            : 'تاريخ غير محدد',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (createdAt != null)
                    Text(
                      'تم التسجيل: ${DateFormat('dd/MM/yyyy').format(createdAt.toDate())}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${amount.toStringAsFixed(2)} ج.م',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ==================== دوال مساعدة ====================
  
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '----';
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}