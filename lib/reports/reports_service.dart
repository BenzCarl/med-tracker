import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ReportsService {
  static Future<String> generateMedicineListReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicines')
        .get();

    final StringBuffer csv = StringBuffer();
    csv.writeln('Name,Dosage,Illness,Stock,Start Date,End Date,Description');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      csv.writeln(
        '${data['name'] ?? ''},'
        '${data['dosage'] ?? ''},'
        '${data['illness'] ?? ''},'
        '${data['initialStock'] ?? '0'},'
        '${data['startDate'] ?? ''},'
        '${data['endDate'] ?? ''},'
        '"${data['description'] ?? ''}"',
      );
    }

    return csv.toString();
  }

  static Future<String> generateHistoryReport({int? days}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    var query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('timestamp', descending: true);

    if (days != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      query = query.where('timestamp', isGreaterThan: cutoffDate);
    }

    final snapshot = await query.get();

    final StringBuffer csv = StringBuffer();
    csv.writeln('Medicine,Status,Timestamp,Notes');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'];
      String dateStr = '';
      if (timestamp is Timestamp) {
        dateStr = DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
      }

      csv.writeln(
        '${data['medicineName'] ?? ''},'
        '${data['status'] ?? ''},'
        '$dateStr,'
        '"${data['notes'] ?? ''}"',
      );
    }

    return csv.toString();
  }

  static Future<Map<String, dynamic>> generateAdherenceReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .where('timestamp', isGreaterThan: weekAgo)
        .get();

    int totalDoses = snapshot.docs.length;
    int takenDoses = snapshot.docs
        .where((doc) => doc.data()['status'] == 'Taken')
        .length;
    int missedDoses = snapshot.docs
        .where((doc) => doc.data()['status'] == 'Missed')
        .length;

    double adherenceRate = totalDoses > 0 ? (takenDoses / totalDoses * 100) : 0;

    return {
      'totalDoses': totalDoses,
      'takenDoses': takenDoses,
      'missedDoses': missedDoses,
      'adherenceRate': adherenceRate.toStringAsFixed(1),
      'period': '7 days',
    };
  }

  static Future<String> generateFullReport() async {
    final medicineReport = await generateMedicineListReport();
    final historyReport = await generateHistoryReport(days: 30);
    final adherenceData = await generateAdherenceReport();

    final StringBuffer report = StringBuffer();
    report.writeln('=== CARE MINDER HEALTH REPORT ===');
    report.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    report.writeln('');
    report.writeln('=== ADHERENCE SUMMARY (${adherenceData['period']}) ===');
    report.writeln('Total Doses: ${adherenceData['totalDoses']}');
    report.writeln('Taken: ${adherenceData['takenDoses']}');
    report.writeln('Missed: ${adherenceData['missedDoses']}');
    report.writeln('Adherence Rate: ${adherenceData['adherenceRate']}%');
    report.writeln('');
    report.writeln('=== MEDICINE LIST ===');
    report.writeln(medicineReport);
    report.writeln('');
    report.writeln('=== MEDICATION HISTORY (Last 30 Days) ===');
    report.writeln(historyReport);

    return report.toString();
  }
}
