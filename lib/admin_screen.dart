import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // بيانات حقيقية
  int totalEmployees = 0;
  int activeProjects = 0;
  int presentToday = 0;
  int absentToday = 0;
  int lateToday = 0;
  int pendingRequests = 0;
  double attendanceRate = 0;
  String adminName = "مدير";
  bool isLoading = true;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadAllData();
  }
  
  Future<void> _loadAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      // تحميل البيانات بالترتيب مع حماية
      await _loadAdminName();
      await _loadEmployeesCount();
      await _loadProjectsCount();
      await _loadTodayAttendance();
      await _loadPendingRequests();
    } catch (e) {
      setState(() {
        errorMessage = "حدث خطأ: $e";
      });
    }
    
    setState(() => isLoading = false);
  }
  
  // ✅ الطريقة الآمنة لجلب اسم المدير
  Future<void> _loadAdminName() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        print("⚠️ No user logged in");
        adminName = "مدير";
        return;
      }
      
      final String uid = user.uid;
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          adminName = data['name'] ?? 'مدير';
        } else {
          adminName = 'مدير';
        }
      } else {
        print("⚠️ User document not found for UID: $uid");
        adminName = 'مدير';
      }
    } catch (e) {
      print("❌ Error loading admin name: $e");
      adminName = 'مدير';
    }
  }
  
  // ✅ الطريقة الآمنة لجلب عدد الموظفين
  Future<void> _loadEmployeesCount() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('isActive', isEqualTo: true)
          .get();
      
      totalEmployees = snapshot.docs.length;
    } catch (e) {
      print("❌ Error loading employees: $e");
      totalEmployees = 0;
    }
  }
  
  // ✅ الطريقة الآمنة لجلب عدد المشاريع
  Future<void> _loadProjectsCount() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('projects')
          .where('isActive', isEqualTo: true)
          .get();
      
      activeProjects = snapshot.docs.length;
    } catch (e) {
      print("❌ Error loading projects: $e");
      activeProjects = 0;
    }
  }
  
  // ✅ الطريقة الآمنة لجلب حضور اليوم
  Future<void> _loadTodayAttendance() async {
    try {
      final String today = DateTime.now().toIso8601String().split('T')[0];
      
      final QuerySnapshot snapshot = await _firestore
          .collection('attendance')
          .where('date', isEqualTo: today)
          .get();
      
      // حساب الحضور بشكل آمن
      presentToday = 0;
      lateToday = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String status = data['status'] ?? 'absent';
        
        if (status == 'present') {
          presentToday++;
        } else if (status == 'late') {
          lateToday++;
        }
      }
      
      // الغياب = إجمالي الموظفين - (حاضر + متأخر)
      absentToday = totalEmployees - (presentToday + lateToday);
      if (absentToday < 0) absentToday = 0;
      
      // نسبة الحضور
      attendanceRate = totalEmployees > 0
          ? ((presentToday + lateToday) / totalEmployees * 100)
          : 0;
          
    } catch (e) {
      print("❌ Error loading attendance: $e");
      presentToday = 0;
      lateToday = 0;
      absentToday = 0;
      attendanceRate = 0;
    }
  }
  
  // ✅ الطريقة الآمنة لجلب الطلبات المعلقة
  Future<void> _loadPendingRequests() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .get();
      
      pendingRequests = snapshot.docs.length;
    } catch (e) {
      print("❌ Error loading requests: $e");
      pendingRequests = 0;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: _buildBody(),
      ),
    );
  }
  
  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A1A2E)),
      );
    }
    
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllData,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 24),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildQuickActionsSection(),
          const SizedBox(height: 24),
          if (pendingRequests > 0) ...[
            _buildPendingRequestsSection(),
            const SizedBox(height: 24),
          ],
          _buildRecentAttendanceSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'لوحة التحكم',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Color(0xFF1A1A2E)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF1A1A2E)),
          onPressed: _loadAllData,
        ),
      ],
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF1A1A2E),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF16213E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    adminName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE94560),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'مدير النظام',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildDrawerItem(
              icon: Icons.dashboard,
              title: 'الرئيسية',
              isActive: true,
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.people,
              title: 'إدارة الموظفين',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.business,
              title: 'المشاريع والمواقع',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.assessment,
              title: 'التقارير',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.event_note,
              title: 'الطلبات',
              badge: pendingRequests > 0 ? pendingRequests : null,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            const Divider(color: Colors.white24),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'تسجيل خروج',
              onTap: () async {
                await _auth.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              isDestructive: true,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool isActive = false,
    bool isDestructive = false,
    int? badge,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : (isActive ? const Color(0xFFE94560) : Colors.white70),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : (isActive ? const Color(0xFFE94560) : Colors.white),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFE94560),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
  
  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك، $adminName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getGreetingMessage(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                const SizedBox(height: 5),
                Text(
                  _getCurrentDate(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير ☀️';
    if (hour < 18) return 'مساء الخير 🌤️';
    return 'مساء الخير 🌙';
  }
  
  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }
  
  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'إجمالي الموظفين',
          value: '$totalEmployees',
          icon: Icons.people,
          color: const Color(0xFF2196F3),
          subValue: 'موظف نشط',
        ),
        _buildStatCard(
          title: 'المشاريع النشطة',
          value: '$activeProjects',
          icon: Icons.business,
          color: const Color(0xFF4CAF50),
          subValue: 'موقع عمل',
        ),
        _buildStatCard(
          title: 'الحضور اليوم',
          value: '$presentToday',
          icon: Icons.check_circle,
          color: const Color(0xFF4CAF50),
          subValue: 'من $totalEmployees',
        ),
        _buildStatCard(
          title: 'نسبة الحضور',
          value: '${attendanceRate.toInt()}%',
          icon: Icons.percent,
          color: attendanceRate >= 80 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
          subValue: attendanceRate >= 80 ? 'ممتاز' : 'متوسط',
        ),
        _buildStatCard(
          title: 'متأخرين اليوم',
          value: '$lateToday',
          icon: Icons.warning,
          color: const Color(0xFFFF9800),
          subValue: 'تأخير',
        ),
        _buildStatCard(
          title: 'طلبات معلقة',
          value: '$pendingRequests',
          icon: Icons.pending_actions,
          color: const Color(0xFFE94560),
          subValue: 'بانتظار الموافقة',
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Text(
                subValue,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'إضافة موظف',
                icon: Icons.person_add,
                color: const Color(0xFF2196F3),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'إضافة مشرف',
                icon: Icons.admin_panel_settings,
                color: const Color(0xFF9C27B0),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'تحديد موقع',
                icon: Icons.location_on,
                color: const Color(0xFFFF9800),
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'تقرير الحضور',
                icon: Icons.assessment,
                color: const Color(0xFF4CAF50),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'توقيع خصم',
                icon: Icons.receipt,
                color: const Color(0xFFE94560),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'إدارة الطلبات',
                icon: Icons.event_note,
                color: const Color(0xFF607D8B),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPendingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الطلبات المعلقة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('requests')
              .where('status', isEqualTo: 'pending')
              .limit(5)
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
              return const SizedBox.shrink();
            }
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: requests.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return Column(
                    children: [
                      _buildRequestItem(
                        employeeName: data['employeeName'] ?? 'موظف',
                        type: data['type'] ?? 'إجازة',
                        reason: data['reason'] ?? '',
                        date: data['date'] ?? '',
                      ),
                      if (index != requests.length - 1)
                        const Divider(height: 0, thickness: 0.5),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildRequestItem({
    required String employeeName,
    required String type,
    required String reason,
    required String date,
  }) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: type == 'إجازة' 
                    ? const Color(0xFFE3F2FD) 
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                type == 'إجازة' ? Icons.beach_access : Icons.access_time,
                color: type == 'إجازة' ? const Color(0xFF2196F3) : const Color(0xFFFF9800),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employeeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$type - $reason',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'قيد الانتظار',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentAttendanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'آخر تسجيلات الحضور',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('attendance')
              .orderBy('timestamp', descending: true)
              .limit(5)
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
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('لا توجد سجلات حضور بعد'),
                ),
              );
            }
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: attendances.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return Column(
                    children: [
                      _buildAttendanceItem(
                        employeeName: data['employeeName'] ?? 'موظف',
                        time: data['checkInTime'] ?? '--:--',
                        status: data['status'] ?? 'present',
                        location: data['location'] ?? 'موقع العمل',
                      ),
                      if (index != attendances.length - 1)
                        const Divider(height: 0, thickness: 0.5),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildAttendanceItem({
    required String employeeName,
    required String time,
    required String status,
    required String location,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'present':
        statusColor = const Color(0xFF4CAF50);
        statusText = 'حاضر';
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = const Color(0xFFFF9800);
        statusText = 'متأخر';
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = const Color(0xFFF44336);
        statusText = 'غائب';
        statusIcon = Icons.cancel;
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 10, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}