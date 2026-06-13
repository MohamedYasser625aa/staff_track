import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'employee_profile_screen.dart';
import 'employee_details_screen.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // بيانات الموظف
  String employeeName = "";
  String employeeId = "";
  String employeeEmail = "";
  String employeePhone = "";
  String department = "";
  String projectId = "";
  double vacationBalance = 0;
  double totalDeductions = 0;
  double salary = 0;
  bool isCheckedIn = false;
  String checkInTime = "";
  String checkOutTime = "";
  bool isLoading = true;
  
  // موقع العمل
  double workLatitude = 30.0444;
  double workLongitude = 31.2357;
  double allowedRadius = 100;
  String workLocationAddress = "جاري التحميل...";
  
  // الطلبات
  final TextEditingController _requestReasonController = TextEditingController();
  final TextEditingController _requestDateController = TextEditingController();
  String _selectedRequestType = "إجازة";
  
  List<Map<String, dynamic>> topEmployees = [];
  
  // الحسابات
  final double dailySalary = 500; // راتب يومي 500 جنيه
  final int workingHours = 8; // 8 ساعات عمل
  double hourlyRate = 0; // يتم حسابه لاحقاً
  
  @override
  void initState() {
    super.initState();
    hourlyRate = dailySalary / workingHours; // 500 / 8 = 62.5 جنيه في الساعة
    _loadEmployeeData();
    _loadTopEmployees();
  }
  
  @override
  void dispose() {
    _requestReasonController.dispose();
    _requestDateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadEmployeeData() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;
      
      employeeId = user.uid;
      employeeEmail = user.email ?? '';
      final doc = await _firestore.collection('users').doc(employeeId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        employeeName = data['name'] ?? 'موظف';
        employeePhone = data['phone'] ?? '';
        department = data['department'] ?? 'غير محدد';
        vacationBalance = (data['vacationBalance'] ?? 21).toDouble();
        salary = (data['salary'] ?? 3000).toDouble();
        projectId = data['projectId'] ?? '';
        
        await _loadWorkLocation();
        await _loadMonthlyDeductions();
        await _checkTodayAttendance();
      }
      
      setState(() => isLoading = false);
    } catch (e) {
      print("Error loading employee data: $e");
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _loadWorkLocation() async {
    try {
      if (projectId.isEmpty) {
        workLocationAddress = 'لم يتم تحديد موقع العمل بعد';
        setState(() {});
        return;
      }
      
      final projectDoc = await _firestore.collection('projects').doc(projectId).get();
      
      if (projectDoc.exists) {
        final data = projectDoc.data() as Map<String, dynamic>;
        workLatitude = (data['latitude'] ?? 30.0444).toDouble();
        workLongitude = (data['longitude'] ?? 31.2357).toDouble();
        allowedRadius = (data['radius'] ?? 100).toDouble();
        workLocationAddress = data['address'] ?? data['name'] ?? 'موقع العمل';
      } else {
        workLocationAddress = 'موقع العمل غير موجود';
      }
      
      setState(() {});
      
    } catch (e) {
      print("Error loading work location: $e");
      workLocationAddress = 'خطأ في تحميل الموقع';
      setState(() {});
    }
  }
  
  Future<void> _loadMonthlyDeductions() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      final QuerySnapshot snapshot = await _firestore
          .collection('deductions')
          .where('employeeId', isEqualTo: employeeId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      
      totalDeductions = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalDeductions += (data['amount'] ?? 0).toDouble();
      }
      
      setState(() {});
    } catch (e) {
      print("Error loading deductions: $e");
    }
  }
  
  Future<void> _checkTodayAttendance() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final doc = await _firestore
          .collection('attendance')
          .doc('${employeeId}_$today')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final hasCheckOut = data['checkOutTime'] != null && data['checkOutTime'] != '';
        
        setState(() {
          isCheckedIn = data['checkInTime'] != null && !hasCheckOut;
          checkInTime = data['checkInTime'] ?? '';
          checkOutTime = data['checkOutTime'] ?? '';
        });
      } else {
        setState(() {
          isCheckedIn = false;
          checkInTime = "";
          checkOutTime = "";
        });
      }
    } catch (e) {
      print("Error checking attendance: $e");
    }
  }
  
  Future<void> _checkIn() async {
    final locationResult = await _checkLocation();
    if (!locationResult.isWithinRange) {
      _showErrorDialog(
        '❌ لا يمكن تسجيل الحضور\n\n'
        '${locationResult.message}\n\n'
        'المسافة: ${locationResult.distance.toStringAsFixed(0)} متر\n'
        'المسافة المسموحة: ${allowedRadius.toStringAsFixed(0)} متر'
      );
      return;
    }
    
    if (isCheckedIn) {
      _showErrorDialog('تم تسجيل الحضور مسبقاً اليوم');
      return;
    }
    
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final time = DateFormat('hh:mm a').format(now);
      
      final onTimeLimit = DateTime(now.year, now.month, now.day, 8, 30);
      String status;
      
      if (now.isBefore(onTimeLimit) || now.isAtSameMomentAs(onTimeLimit)) {
        status = 'present';
        _showSuccessDialog('✅ تم تسجيل الحضور بنجاح (في الوقت المحدد)');
      } else {
        status = 'late';
        final lateMinutes = now.difference(onTimeLimit).inMinutes;
        final lateHours = (lateMinutes / 60).ceil();
        final lateDeduction = hourlyRate * lateHours;
        
        await _firestore.collection('deductions').add({
          'employeeId': employeeId,
          'employeeName': employeeName,
          'amount': lateDeduction,
          'reason': 'تأخير صباحي (${lateHours} ساعة)',
          'date': Timestamp.fromDate(now),
          'month': now.month,
          'year': now.year,
        });
        
        setState(() {
          totalDeductions += lateDeduction;
        });
        
        _showSuccessDialog('⚠️ تم تسجيل الحضور (متأخر)\nتم خصم ${lateDeduction.toStringAsFixed(2)} جنيه');
      }
      
      await _firestore.collection('attendance').doc('${employeeId}_$today').set({
        'employeeId': employeeId,
        'employeeName': employeeName,
        'date': today,
        'checkInTime': time,
        'timestamp': Timestamp.fromDate(now),
        'status': status,
        'location': workLocationAddress,
      });
      
      setState(() {
        isCheckedIn = true;
        checkInTime = time;
      });
      
      await _updateEmployeeStats('attendance', 1);
      
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
    }
  }
  
  Future<void> _checkOut() async {
    if (!isCheckedIn) {
      _showErrorDialog('لم يتم تسجيل الحضور بعد');
      return;
    }
    
    if (checkOutTime.isNotEmpty) {
      _showErrorDialog('تم تسجيل الانصراف مسبقاً اليوم');
      return;
    }
    
    final locationResult = await _checkLocation();
    if (!locationResult.isWithinRange) {
      _showErrorDialog(
        '❌ لا يمكن تسجيل الانصراف\n\n'
        '${locationResult.message}\n\n'
        'المسافة: ${locationResult.distance.toStringAsFixed(0)} متر\n'
        'المسافة المسموحة: ${allowedRadius.toStringAsFixed(0)} متر'
      );
      return;
    }
    
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final time = DateFormat('hh:mm a').format(now);
      
      final checkInTimeDate = DateFormat('hh:mm a').parse(checkInTime);
      final checkInHour = checkInTimeDate.hour;
      final checkInMinute = checkInTimeDate.minute;
      
      final expectedCheckOut = DateTime(
        now.year, now.month, now.day,
        checkInHour + workingHours,
        checkInMinute
      );
      
      await _firestore.collection('attendance').doc('${employeeId}_$today').update({
        'checkOutTime': time,
        'checkOutTimestamp': Timestamp.fromDate(now),
      });
      
      final actualWorkHours = now.difference(DateTime(
        now.year, now.month, now.day,
        checkInHour, checkInMinute
      )).inHours;
      
      if (actualWorkHours < workingHours) {
        final shortHours = workingHours - actualWorkHours;
        final earlyDeduction = hourlyRate * shortHours;
        
        await _firestore.collection('deductions').add({
          'employeeId': employeeId,
          'employeeName': employeeName,
          'amount': earlyDeduction,
          'reason': 'انصراف مبكر (${shortHours} ساعة)',
          'date': Timestamp.fromDate(now),
          'month': now.month,
          'year': now.year,
        });
        
        setState(() {
          totalDeductions += earlyDeduction;
        });
        
        _showSuccessDialog('⚠️ تم تسجيل الانصراف (مبكر)\nتم خصم ${earlyDeduction.toStringAsFixed(2)} جنيه');
      } else {
        _showSuccessDialog('✅ تم تسجيل الانصراف بنجاح');
      }
      
      setState(() {
        isCheckedIn = false;
        checkOutTime = time;
      });
      
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
    }
  }
  
  Future<LocationResult> _checkLocation() async {
    LocationResult result = LocationResult();
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          result.message = 'مطلوب إذن الوصول للموقع';
          return result;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        result.message = 'تم رفض إذن الموقع نهائياً. الرجاء تفعيله من إعدادات الهاتف';
        return result;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        workLatitude, workLongitude,
      );
      
      result.distance = distance;
      result.isWithinRange = distance <= allowedRadius;
      
      if (!result.isWithinRange) {
        result.message = 'أنت بعيد عن موقع العمل';
      } else {
        result.message = 'أنت داخل النطاق المسموح';
      }
      
      return result;
      
    } catch (e) {
      result.message = 'خطأ في تحديد الموقع: ${e.toString().substring(0, 100)}';
      return result;
    }
  }
  
  Future<void> _submitRequest() async {
    if (_requestReasonController.text.isEmpty) {
      _showErrorDialog('الرجاء إدخال سبب الطلب');
      return;
    }
    
    try {
      final now = DateTime.now();
      
      await _firestore.collection('requests').add({
        'employeeId': employeeId,
        'employeeName': employeeName,
        'type': _selectedRequestType,
        'reason': _requestReasonController.text,
        'date': _requestDateController.text.isEmpty 
            ? DateFormat('yyyy-MM-dd').format(now)
            : _requestDateController.text,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),
      });
      
      _showSuccessDialog('تم إرسال الطلب بنجاح، في انتظار الموافقة');
      
      _requestReasonController.clear();
      _requestDateController.clear();
      Navigator.pop(context);
      
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
    }
  }
  
  void _showRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('طلب جديد - $_selectedRequestType'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedRequestType,
                decoration: const InputDecoration(labelText: 'نوع الطلب'),
                items: ['إجازة', 'تأخير', 'إذن خروج', 'تعديل بيانات'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedRequestType = value!);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _requestDateController,
                decoration: const InputDecoration(
                  labelText: 'التاريخ (اختياري)',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _requestReasonController,
                decoration: const InputDecoration(labelText: 'السبب'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _submitRequest,
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }
  
  // ✅ جلب أفضل 3 موظفين من البيانات الحقيقية
  Future<void> _loadTopEmployees() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endStr = DateFormat('yyyy-MM-dd').format(endOfMonth);
      
      // جلب جميع الموظفين
      final employeesSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('isActive', isEqualTo: true)
          .get();
      
      List<Map<String, dynamic>> employeesList = [];
      
      for (var doc in employeesSnapshot.docs) {
        final employeeData = doc.data() as Map<String, dynamic>;
        final empId = doc.id;
        final empName = employeeData['name'] ?? 'موظف';
        
        // جلب سجلات الحضور للموظف في الشهر الحالي
        final attendanceSnapshot = await _firestore
            .collection('attendance')
            .where('employeeId', isEqualTo: empId)
            .where('date', isGreaterThanOrEqualTo: startStr)
            .where('date', isLessThanOrEqualTo: endStr)
            .get();
        
        // حساب عدد أيام الحضور الفعلية
        int attendanceDays = attendanceSnapshot.docs.length;
        
        // حساب نسبة الحضور
        final daysInMonth = endOfMonth.day;
        double attendanceRate = daysInMonth > 0 
            ? (attendanceDays / daysInMonth * 100)
            : 0;
        
        employeesList.add({
          'name': empName,
          'attendanceCount': attendanceDays,
          'score': attendanceRate,
        });
      }
      
      // ترتيب حسب نسبة الحضور (الأعلى أولاً)
      employeesList.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      
      // أخذ أفضل 3
      setState(() {
        topEmployees = employeesList.take(3).toList();
      });
      
    } catch (e) {
      print("Error loading top employees: $e");
      setState(() {
        topEmployees = [];
      });
    }
  }
  
  Future<void> _updateEmployeeStats(String type, int value) async {
    try {
      final now = DateTime.now();
      final docRef = _firestore.collection('employeeStats').doc('${employeeId}_${now.year}_${now.month}');
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentData = doc.data() as Map<String, dynamic>;
          int attendanceCount = (currentData['attendanceCount'] ?? 0) + (type == 'attendance' ? value : 0);
          int onTimeCount = (currentData['onTimeCount'] ?? 0) + (type == 'onTime' ? value : 0);
          double score = (attendanceCount / 22) * 100;
          
          transaction.update(docRef, {
            'attendanceCount': attendanceCount,
            'onTimeCount': onTimeCount,
            'score': score,
            'lastUpdate': Timestamp.fromDate(now),
          });
        } else {
          transaction.set(docRef, {
            'employeeId': employeeId,
            'employeeName': employeeName,
            'month': now.month,
            'year': now.year,
            'attendanceCount': type == 'attendance' ? value : 0,
            'onTimeCount': type == 'onTime' ? value : 0,
            'score': 0,
            'createdAt': Timestamp.fromDate(now),
          });
        }
      });
      
    } catch (e) {
      print("Error updating stats: $e");
    }
  }
  
  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
  
  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadEmployeeData();
          await _checkTodayAttendance();
          await _loadTopEmployees();
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 20),
                    _buildWorkLocationInfo(),
                    const SizedBox(height: 20),
                    _buildMainAttendanceCard(),
                    const SizedBox(height: 20),
                    _buildVacationAndDeductionsCard(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildTopEmployeesCard(),
                    const SizedBox(height: 20),
                    _buildRecentRequests(),
                  ],
                ),
              ),
      ),
    );
  }
  
  Widget _buildWorkLocationInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'موقع العمل',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
                Text(
                  workLocationAddress,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'نصف القطر: ${allowedRadius.toStringAsFixed(0)}م',
              style: const TextStyle(fontSize: 10, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('لوحة الموظف', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: const Color(0xFF1A1A2E),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
            );
          },
          tooltip: 'البروفايل',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _loadEmployeeData();
            _checkTodayAttendance();
            _loadTopEmployees();
          },
          tooltip: 'تحديث',
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
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    employeeName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    employeeEmail,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.home,
              title: 'الرئيسية',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.person,
              title: 'البروفايل الشخصي',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.calendar_today,
              title: 'سجل الحضور',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeDetailsScreen(initialTab: 0)),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.warning,
              title: 'سجل التأخير',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeDetailsScreen(initialTab: 1)),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.beach_access,
              title: 'سجل الإجازات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeDetailsScreen(initialTab: 1)),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.receipt,
              title: 'سجل الخصومات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeDetailsScreen(initialTab: 2)),
                );
              },
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
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white70),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.white)),
      onTap: onTap,
    );
  }
  
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employeeName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(department, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                const SizedBox(height: 5),
                Text(employeePhone, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white),
                const SizedBox(height: 5),
                Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainAttendanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تسجيل الحضور والانصراف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildAttendanceButton('حضور', Icons.login, Colors.green, isCheckedIn ? null : _checkIn)),
              const SizedBox(width: 16),
              Expanded(child: _buildAttendanceButton('انصراف', Icons.logout, Colors.red, (!isCheckedIn || checkOutTime.isNotEmpty) ? null : _checkOut)),
            ],
          ),
          if (checkInTime.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('وقت الحضور:', style: TextStyle(color: Colors.grey[600])),
              Text(checkInTime, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ],
          if (checkOutTime.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('وقت الانصراف:', style: TextStyle(color: Colors.grey[600])),
              Text(checkOutTime, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAttendanceButton(String title, IconData icon, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
  
  Widget _buildVacationAndDeductionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.beach_access, color: Colors.blue, size: 30),
                ),
                const SizedBox(height: 8),
                Text(vacationBalance.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('رصيد الإجازات', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Container(height: 50, width: 1, color: Colors.grey[200]),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.remove_circle, color: Colors.red, size: 30),
                ),
                const SizedBox(height: 8),
                Text('${totalDeductions.toStringAsFixed(2)} جنيه', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const Text('خصومات هذا الشهر', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إجراءات سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildActionCard('طلب إجازة', Icons.beach_access, Colors.blue, () {
                _selectedRequestType = 'إجازة';
                _showRequestDialog();
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildActionCard('طلب تأخير', Icons.access_time, Colors.orange, () {
                _selectedRequestType = 'تأخير';
                _showRequestDialog();
              })),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildActionCard('سجل الحضور', Icons.history, Colors.purple, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeDetailsScreen(initialTab: 0)),
                );
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildActionCard('الخصومات', Icons.receipt, Colors.teal, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmployeeDetailsScreen(initialTab: 2)),
                );
              })),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopEmployeesCard() {
    if (topEmployees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, size: 50, color: Colors.grey),
              SizedBox(height: 16),
              Text('لا توجد بيانات كافية'),
              SizedBox(height: 8),
              Text('انتظر حتى يتم تسجيل حضور الموظفين', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.emoji_events, color: Colors.amber), SizedBox(width: 8), Text('أفضل 3 موظفين هذا الشهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          ...topEmployees.asMap().entries.map((entry) {
            final index = entry.key;
            final emp = entry.value;
            Color medalColor = index == 0 ? const Color(0xFFFFD700) : (index == 1 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: medalColor.withOpacity(0.2), shape: BoxShape.circle),
                    child: Center(child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: medalColor))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(emp['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('نسبة الحضور: ${(emp['score'] as double).toInt()}%', style: const TextStyle(color: Colors.green, fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildRecentRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('requests').where('employeeId', isEqualTo: employeeId).orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        
        final requests = snapshot.data!.docs;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('طلباتي الأخيرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...requests.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                Color statusColor = data['status'] == 'approved' ? Colors.green : (data['status'] == 'rejected' ? Colors.red : Colors.orange);
                String statusText = data['status'] == 'approved' ? 'موافق' : (data['status'] == 'rejected' ? 'مرفوض' : 'قيد الانتظار');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 45, height: 45,
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(data['type'] == 'إجازة' ? Icons.beach_access : Icons.access_time, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(data['type'] ?? 'طلب', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(data['reason'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
  
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

// كلاس نتيجة التحقق من الموقع
class LocationResult {
  bool isWithinRange = false;
  double distance = 0;
  String message = "";
}