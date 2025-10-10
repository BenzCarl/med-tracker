import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reports_service.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  Future<void> _exportReport(BuildContext context, String type) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String reportData = '';
      String reportName = '';

      switch (type) {
        case 'medicines':
          reportData = await ReportsService.generateMedicineListReport();
          reportName = 'Medicine List';
          break;
        case 'history':
          reportData = await ReportsService.generateHistoryReport(days: 30);
          reportName = 'History Report (30 Days)';
          break;
        case 'adherence':
          final adherenceData = await ReportsService.generateAdherenceReport();
          reportData = adherenceData.toString();
          reportName = 'Adherence Report';
          break;
        case 'full':
          reportData = await ReportsService.generateFullReport();
          reportName = 'Full Report';
          break;
      }

      Navigator.pop(context); // Close loading dialog

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: reportData));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$reportName copied to clipboard!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.purple.shade600],
            ),
          ),
        ),
        title: const Text(
          'Export Reports',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Reports will be copied to your clipboard. You can then paste them into any app.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildReportCard(
                    context,
                    'Medicine List',
                    'Export all your medicines with details',
                    Icons.medication_liquid_rounded,
                    Colors.blue,
                    () => _exportReport(context, 'medicines'),
                  ),
                  const SizedBox(height: 12),
                  _buildReportCard(
                    context,
                    'Medication History',
                    'Export last 30 days of medication intake',
                    Icons.history_rounded,
                    Colors.green,
                    () => _exportReport(context, 'history'),
                  ),
                  const SizedBox(height: 12),
                  _buildReportCard(
                    context,
                    'Adherence Report',
                    'View your medication adherence statistics',
                    Icons.trending_up_rounded,
                    Colors.orange,
                    () => _exportReport(context, 'adherence'),
                  ),
                  const SizedBox(height: 12),
                  _buildReportCard(
                    context,
                    'Full Report',
                    'Complete health report with all data',
                    Icons.description_rounded,
                    Colors.purple,
                    () => _exportReport(context, 'full'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.file_download_outlined, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
