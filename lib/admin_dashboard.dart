import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_user_screen.dart';
import 'delete_user_screen.dart';
import 'projects_screen.dart';
import 'manage_requests_screen.dart';
import 'attendance_report_screen.dart';
import 'deduction_screen.dart';
import 'edit_user_screen.dart';
import 'manage_employees_screen.dart';
import 'employee_profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
  
  // قوائم للتفاصيل
  List<Map<String, dynamic>> presentEmployees = [];
  List<Map<String, dynamic>> lateEmployees = [];
  List<Map<String, dynamic>> absentEmployees = [];
  
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
      await _loadAdminName();
      await _loadEmployeesCount();
      await _loadProjectsCount();
      await _loadTodayAttendance();
      await _loadAttendanceDetails();
      await _loadPendingRequests();
    } catch (e) {
      setState(() {
        errorMessage = "حدث خطأ: $e";
      });
    }
    
    setState(() => isLoading = false);
  }
  
  Future<void> _loadAdminName() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        adminName = "مدير";
        return;
      }
      
      final String uid = user.uid;
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          adminName = data['name'] ?? 'مدير';
        }
      }
    } catch (e) {
      adminName = 'مدير';
    }
  }
  
  Future<void> _loadEmployeesCount() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('isActive', isEqualTo: true)
          .get();
      
      totalEmployees = snapshot.docs.length;
    } catch (e) {
      totalEmployees = 0;
    }
  }
  
  Future<void> _loadProjectsCount() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('projects')
          .where('isActive', isEqualTo: true)
          .get();
      
      activeProjects = snapshot.docs.length;
    } catch (e) {
      activeProjects = 0;
    }
  }
  
  Future<void> _loadTodayAttendance() async {
    try {
      final String today = DateTime.now().toIso8601String().split('T')[0];
      
      final QuerySnapshot snapshot = await _firestore
          .collection('attendance')
          .where('date', isEqualTo: today)
          .get();
      
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
      
      absentToday = totalEmployees - (presentToday + lateToday);
      if (absentToday < 0) absentToday = 0;
      
      attendanceRate = totalEmployees > 0
          ? ((presentToday + lateToday) / totalEmployees * 100)
          : 0;
          
    } catch (e) {
      presentToday = 0;
      lateToday = 0;
      absentToday = 0;
      attendanceRate = 0;
    }
  }
  
  Future<void> _loadAttendanceDetails() async {
    final String today = DateTime.now().toIso8601String().split('T')[0];
    
    final employeesSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .where('isActive', isEqualTo: true)
        .get();
    
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: today)
        .get();
    
    Map<String, dynamic> attendanceMap = {};
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      attendanceMap[data['employeeId']] = data;
    }
    
    presentEmployees.clear();
    lateEmployees.clear();
    absentEmployees.clear();
    
    for (var doc in employeesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final employee = {
        'id': doc.id,
        'name': data['name'] ?? 'بدون اسم',
        'email': data['email'] ?? '',
        'projectId': data['projectId'],
      };
      
      if (attendanceMap.containsKey(doc.id)) {
        final attendance = attendanceMap[doc.id];
        final status = attendance['status'];
        if (status == 'present') {
          presentEmployees.add(employee);
        } else if (status == 'late') {
          lateEmployees.add(employee);
        } else {
          absentEmployees.add(employee);
        }
      } else {
        absentEmployees.add(employee);
      }
    }
  }
  
  Future<void> _loadPendingRequests() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .get();
      
      pendingRequests = snapshot.docs.length;
    } catch (e) {
      pendingRequests = 0;
    }
  }
  
  void _showEmployeesList(String title, List<Map<String, dynamic>> employees, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
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
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${employees.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: employees.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('لا يوجد موظفين', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final emp = employees[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.2),
                                child: Text(
                                  emp['name'].toString()[0],
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                emp['name'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(emp['email']),
                              trailing: Icon(Icons.chevron_right, color: color),
                              onTap: () {
                                Navigator.pop(context);
                                _showEmployeeDetails(emp['id'], emp['name']);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showEmployeeDetails(String employeeId, String employeeName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(employeeId).get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final projectId = userData?['projectId'];
            
            return Container(
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
                          radius: 30,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            employeeName.isNotEmpty ? employeeName[0] : '?',
                            style: const TextStyle(fontSize: 24, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employeeName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                userData?['email'] ?? 'بدون بريد',
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
                          _buildInfoCard(
                            icon: Icons.phone,
                            title: 'رقم الهاتف',
                            value: userData?['phone'] ?? 'غير مسجل',
                          ),
                          _buildInfoCard(
                            icon: Icons.work,
                            title: 'الصلاحية',
                            value: userData?['role'] == 'employee' ? 'موظف' : (userData?['role'] == 'manager' ? 'مشرف' : 'مدير'),
                          ),
                          _buildInfoCard(
                            icon: Icons.calendar_today,
                            title: 'تاريخ التسجيل',
                            value: userSnapshot.data!.exists && userSnapshot.data!['createdAt'] != null
                                ? DateFormat('yyyy-MM-dd').format((userSnapshot.data!['createdAt'] as Timestamp).toDate())
                                : 'غير محدد',
                          ),
                          if (projectId != null)
                            FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('projects').doc(projectId).get(),
                              builder: (context, projectSnapshot) {
                                if (!projectSnapshot.hasData) return const SizedBox.shrink();
                                final projectData = projectSnapshot.data!.data() as Map<String, dynamic>?;
                                return _buildInfoCard(
                                  icon: Icons.business,
                                  title: 'المشروع',
                                  value: projectData?['name'] ?? 'غير محدد',
                                );
                              },
                            ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditUserScreen(
                                    userId: employeeId,
                                    userName: employeeName,
                                  ),
                                ),
                              ).then((_) => _loadAllData());
                            },
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            label: const Text('تعديل البيانات'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text('إغلاق'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A2E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1A1A2E), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
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
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
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
          const SizedBox(height: 28),
          _buildQuickActionsSection(),
          const SizedBox(height: 28),
          if (pendingRequests > 0) ...[
            _buildPendingRequestsSection(),
            const SizedBox(height: 28),
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
        'لوحة القيادة',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
        ),
        IconButton(
          icon: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
            );
          },
          tooltip: 'البروفايل',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
          onPressed: _loadAllData,
        ),
      ],
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 45,
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
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'مدير النظام',
                      style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12),
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
              title: 'الموظفين',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageEmployeesScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.business,
              title: 'المشاريع',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProjectsScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.assessment,
              title: 'التقارير',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AttendanceReportScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.event_note,
              title: 'الطلبات',
              badge: pendingRequests > 0 ? pendingRequests : null,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageRequestsScreen()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: Colors.white24, height: 1),
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
        color: isDestructive ? Colors.red : (isActive ? const Color(0xFF3B82F6) : Colors.white70),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : (isActive ? const Color(0xFF3B82F6) : Colors.white),
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
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
                  'مرحباً بعودتك،',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  adminName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getGreetingMessage(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 22),
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
    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${now.day} ${arabicMonths[now.month - 1]} ${now.year}';
  }
  
  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          title: 'إجمالي الموظفين',
          value: '$totalEmployees',
          icon: Icons.people_rounded,
          color: const Color(0xFF3B82F6),
          subtitle: 'موظف نشط',
          onTap: () => _showEmployeesList('جميع الموظفين', 
              presentEmployees + lateEmployees + absentEmployees, const Color(0xFF3B82F6)),
        ),
        _buildStatCard(
          title: 'المشاريع',
          value: '$activeProjects',
          icon: Icons.business_rounded,
          color: const Color(0xFF10B981),
          subtitle: 'مشروع نشط',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
        ),
        _buildStatCard(
          title: 'حاضرين',
          value: '$presentToday',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
          subtitle: 'من $totalEmployees',
          onTap: () => _showEmployeesList('الموظفين الحاضرين', presentEmployees, const Color(0xFF10B981)),
        ),
        _buildStatCard(
          title: 'نسبة الحضور',
          value: '${attendanceRate.toInt()}%',
          icon: Icons.trending_up_rounded,
          color: attendanceRate >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          subtitle: attendanceRate >= 80 ? 'ممتاز' : 'متوسط',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
        ),
        _buildStatCard(
          title: 'متأخرين',
          value: '$lateToday',
          icon: Icons.warning_rounded,
          color: const Color(0xFFF59E0B),
          subtitle: 'تأخير اليوم',
          onTap: () => _showEmployeesList('الموظفين المتأخرين', lateEmployees, const Color(0xFFF59E0B)),
        ),
        _buildStatCard(
          title: 'غائبين',
          value: '$absentToday',
          icon: Icons.person_off_rounded,
          color: const Color(0xFFEF4444),
          subtitle: 'غياب اليوم',
          onTap: () => _showEmployeesList('الموظفين الغائبين', absentEmployees, const Color(0xFFEF4444)),
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'إجراءات سريعة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              title: 'موظف جديد',
              icon: Icons.person_add_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddUserScreen())),
            ),
            _buildActionCard(
              title: 'حذف موظف',
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFEF4444),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteUserScreen())),
            ),
            _buildActionCard(
              title: 'مشاريع',
              icon: Icons.business_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
            ),
            _buildActionCard(
              title: 'تقرير الحضور',
              icon: Icons.assessment_rounded,
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
            ),
            _buildActionCard(
              title: 'خصم موظف',
              icon: Icons.receipt_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeductionScreen())),
            ),
            _buildActionCard(
              title: 'الطلبات',
              icon: Icons.event_note_rounded,
              color: const Color(0xFFEC4899),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRequestsScreen())),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
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
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'الطلبات المعلقة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
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
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('لا توجد طلبات معلقة'),
                ),
              );
            }
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
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
                        date: data['startDate'] != null 
                            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['startDate']))
                            : 'تاريخ غير محدد',
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
    final isLeave = type == 'leave' || type == 'إجازة';
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRequestsScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLeave ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isLeave ? Icons.beach_access_rounded : Icons.access_time_rounded,
                color: isLeave ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
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
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'قيد الانتظار',
                    style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B)),
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
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'آخر تسجيلات الحضور',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
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
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('لا توجد سجلات حضور بعد'),
                ),
              );
            }
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
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
                        employeeId: data['employeeId'] ?? '',
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
    required String employeeId,
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
    
    return InkWell(
      onTap: () => _showEmployeeDetails(employeeId, employeeName), // ✅ تم التعديل: نمرر الـ ID الحقيقي
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
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
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
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
      ),
    );
  }
}