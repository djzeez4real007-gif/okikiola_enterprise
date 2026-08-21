import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busy = false;
  String? message;

  Future<void> _export() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final path = await BackupService.exportToFile();
      if (!mounted) return;
      setState(() => message = 'Backup ready: $path');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup exported — save the file somewhere safe'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Restore backup?'),
        content: const Text(
          'This will REPLACE all current data with the backup file.\n\n'
          'Export a backup first if you are not sure.\n'
          'The app will need a full restart after restore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      busy = true;
      message = null;
    });
    try {
      final n = await BackupService.restoreFromPicker();
      if (!mounted) return;
      setState(() => message = 'Restored $n data boxes. Restart the app.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $n boxes — please restart the app'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = AuthService.currentRole == 'owner';
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF0F766E)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup & restore',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Save a full copy of products, sales, stock, shifts and users. '
                  'Keep the JSON file on Google Drive or a USB stick.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            icon: Icons.cloud_upload_rounded,
            title: 'Export backup',
            subtitle: 'Share / save a JSON file of all shop data',
            button: 'EXPORT NOW',
            color: AppColors.primary,
            onTap: busy ? null : _export,
          ),
          const SizedBox(height: 12),
          if (isOwner)
            _card(
              icon: Icons.cloud_download_rounded,
              title: 'Restore backup',
              subtitle: 'Replace current data (owner only — careful)',
              button: 'RESTORE',
              color: AppColors.danger,
              onTap: busy ? null : _restore,
            ),
          if (busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 24),
          Text(
            'Tips\n'
            '• Export at least once a week\n'
            '• Export before major stock counts\n'
            '• Restore only from a file you trust',
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required String button,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(button,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
