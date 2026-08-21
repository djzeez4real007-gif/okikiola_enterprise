import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../services/audit_log_storage.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  String query = '';
  String moduleFilter = 'All';
  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    setState(() => logs = AuditLogStorage.all());
  }

  List<Map<String, dynamic>> get filtered {
    var list = logs;
    if (moduleFilter != 'All') {
      list = list
          .where((e) => (e['module'] ?? '').toString() == moduleFilter)
          .toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((e) {
      final blob =
          '${e['action']} ${e['module']} ${e['description']} ${e['userName']} ${e['role']}'
              .toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  String _fmt(String raw) {
    try {
      return DateFormat('dd MMM yyyy · HH:mm:ss').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  IconData _icon(String action) {
    if (action.contains('sale')) return Icons.point_of_sale_rounded;
    if (action.contains('product') || action.contains('stock')) {
      return Icons.inventory_2_rounded;
    }
    if (action.contains('shift')) return Icons.schedule_rounded;
    if (action.contains('expense')) return Icons.payments_rounded;
    if (action.contains('login')) return Icons.login_rounded;
    return Icons.history_rounded;
  }

  Color _color(String action) {
    if (action.contains('void') || action.contains('delete')) {
      return AppColors.danger;
    }
    if (action.contains('shift_closed')) return AppColors.accent;
    if (action.contains('sale')) return AppColors.primary;
    return const Color(0xFF475569);
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    final modules = {
      'All',
      ...logs.map((e) => (e['module'] ?? '').toString()).where((m) => m.isNotEmpty),
    }.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF0F766E)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Audit log',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  'Who did what, and when — owner only · ${list.length} events',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Search actions, people, details…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: modules.map((m) {
                final sel = moduleFilter == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m),
                    selected: sel,
                    onSelected: (_) => setState(() => moduleFilter = m),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No audit events yet'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final e = list[i];
                      final action = (e['action'] ?? '').toString();
                      final color = _color(action);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_icon(action), color: color, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: color,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (e['description'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${e['userName'] ?? ''} · ${e['role'] ?? ''} · ${e['module'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _fmt((e['at'] ?? '').toString()),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
