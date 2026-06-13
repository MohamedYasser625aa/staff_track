const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// دالة لحذف مستخدم نهائياً
exports.deleteUserPermanently = functions.https.onCall(async (data, context) => {
    // التحقق من أن المستخدم مسجل الدخول
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    
    const adminUid = context.auth.uid;
    const targetUid = data.uid;
    
    // التحقق من أن المستخدم الحالي هو Admin
    const adminDoc = await admin.firestore().collection('users').doc(adminUid).get();
    const adminRole = adminDoc.data() ? adminDoc.data().role : null;
    
    if (adminRole !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية لحذف المستخدمين');
    }
    
    try {
        // 1️⃣ حذف المستخدم من Firebase Authentication
        await admin.auth().deleteUser(targetUid);
        
        // 2️⃣ حذف المستخدم من Firestore
        await admin.firestore().collection('users').doc(targetUid).delete();
        
        // 3️⃣ حذف سجلات الحضور الخاصة به
        const attendanceSnapshot = await admin.firestore()
            .collection('attendance')
            .where('employeeId', isEqualTo: targetUid)
            .get();
        
        const batch = admin.firestore().batch();
        attendanceSnapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        await batch.commit();
        
        // 4️⃣ حذف طلباته
        const requestsSnapshot = await admin.firestore()
            .collection('requests')
            .where('employeeId', isEqualTo: targetUid)
            .get();
        
        const batch2 = admin.firestore().batch();
        requestsSnapshot.docs.forEach((doc) => {
            batch2.delete(doc.ref);
        });
        await batch2.commit();
        
        return { success: true, message: 'تم حذف المستخدم نهائياً' };
        
    } catch (error) {
        console.error('Error deleting user:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});