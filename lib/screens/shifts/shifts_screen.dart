import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shift.dart';
import '../../services/auth_service.dart';
import '../../services/shift_storage.dart';
import '../../services/cash_movement_storage.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  bool loading = true;
  bool busy = false;
  Shift? openShift;
  List<Shift> history = [];
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  bool get isOwner =>
      AuthService.currentRole == 'owner' ||
      AuthService.currentRole == 'manager';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final open = await ShiftStorage.currentOpenShift();
      final all = await ShiftStorage.getAll();
      final list = isOwner
          ? all
          : all
              .where((s) => s.userId == AuthService.currentUser?.id)
              .toList();
      if (!mounted) return;
      setState(() {
        openShift = open;
        history = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _toast('Could not load shifts: $e');
    }
  }

  void _toast(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> openShiftSheet() async {
    if (busy) return;
    if (AuthService.currentUser == null) {
      _toast('Please log in again');
      return;
    }
    if (openShift != null) {
      _toast('You already have an open shift. Close it first.');
      return;
    }

    final suggested = await ShiftStorage.suggestedOpeningCash();
    final ctrl = TextEditingController(text: suggested.toStringAsFixed(0));
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  'Open shift',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Opening float is pre-filled from the last closed shift (cash carried forward). '
                  'Change it only if you removed or added cash outside the system.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Opening cash (₦)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'OPEN SHIFT NOW',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final amount = double.tryParse(ctrl.text.trim()) ?? 0;
    setState(() => busy = true);
    try {
      await ShiftStorage.openShift(openingCash: amount);
      if (!mounted) return;
      await load();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Shift opened'),
          content: Text(
            'Opening float: ${money.format(amount)}\n\n'
            'You can take sales now. When the day ends, tap CLOSE SHIFT and count the cash.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> closeShiftSheet(Shift shift) async {
    if (busy) return;
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  'Close shift',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expected = opening float + cash sales '
                  '− cash expenses − cash removed by owner.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Cash counted (₦)',
                    prefixIcon: Icon(Icons.savings_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if ((double.tryParse(ctrl.text.trim()) == null)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter cash counted')),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'CLOSE SHIFT',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;
    final counted = double.tryParse(ctrl.text.trim());
    if (counted == null) {
      _toast('Enter a valid cash amount');
      return;
    }

    setState(() => busy = true);
    try {
      final closed = await ShiftStorage.closeShift(
        shift: shift,
        closingCashCounted: counted,
        note: noteCtrl.text.trim(),
      );
      if (!mounted) return;
      final v = closed.cashVariance ?? 0;
      final msg = v == 0
          ? 'Balanced — perfect'
          : v > 0
              ? 'Over by ${money.format(v)}'
              : 'SHORT by ${money.format(-v)}';

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Shift closed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Opening float', money.format(closed.openingCash)),
              _kv('Expected cash', money.format(closed.expectedCash ?? 0)),
              _kv('Counted', money.format(closed.closingCashCounted ?? 0)),
              _kv('Sales in shift', money.format(closed.salesTotal ?? 0)),
              const SizedBox(height: 10),
              Text(
                msg,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: v < 0
                      ? AppColors.danger
                      : v > 0
                          ? AppColors.accent
                          : AppColors.success,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await load();
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cashOutSheet() async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Owner cash pickup');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Remove cash from drawer',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use when the owner takes cash from the till. '
                  'This reduces expected cash at shift close.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₦)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text(
                    'CONFIRM REMOVE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      await CashMovementStorage.addOut(
        amount: amount,
        reason: reasonCtrl.text.trim().isEmpty
            ? 'Owner cash pickup'
            : reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      _toast('Cash removed: ${money.format(amount)}', error: false);
    } catch (e) {
      _toast('$e');
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy · HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cash shifts',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          openShift == null
                              ? 'No open shift — open before cash sales'
                              : 'Shift open since ${_fmt(openShift!.openedAt)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (openShift == null)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: busy ? null : openShiftSheet,
                              icon: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                busy ? 'Please wait…' : 'OPEN SHIFT',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  openShift!.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Float: ${money.format(openShift!.openingCash)}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed:
                                  busy ? null : () => closeShiftSheet(openShift!),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text(
                                'CLOSE SHIFT',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.danger,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : _cashOutSheet,
                              icon: const Icon(Icons.money_off_csred_rounded,
                                  color: Colors.white),
                              label: const Text(
                                'CASH OUT (remove from drawer)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'History',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  if (history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Text('No shifts yet')),
                    )
                  else
                    ...history.map(_historyCard),
                ],
              ),
            ),
    );
  }

  Widget _historyCard(Shift s) {
    final v = s.cashVariance;
    Color badgeColor = Colors.grey;
    String badge = 'Open';
    if (s.closed) {
      if (v == null || v == 0) {
        badge = 'Balanced';
        badgeColor = AppColors.success;
      } else if (v < 0) {
        badge = 'Short ${money.format(-v)}';
        badgeColor = AppColors.danger;
      } else {
        badge = 'Over ${money.format(v)}';
        badgeColor = AppColors.accent;
      }
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.userName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Opened ${_fmt(s.openedAt)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          if (s.closedAt != null)
            Text(
              'Closed ${_fmt(s.closedAt!)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          if (s.closed) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _mini('Open', money.format(s.openingCash)),
                _mini('Expected', money.format(s.expectedCash ?? 0)),
                _mini('Close', money.format(s.closingCashCounted ?? 0)),
                _mini('Sales', money.format(s.salesTotal ?? 0)),
                _mini(
                  'Net',
                  money.format((s.closingCashCounted ?? 0) - s.openingCash),
                ),
                _mini('Next day starts', money.format(s.closingCashCounted ?? 0)),
              ],
            ),
          ] else if (!s.closed &&
              s.userId == AuthService.currentUser?.id) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : () => closeShiftSheet(s),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                child: const Text('CLOSE THIS SHIFT'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$k: $v',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
}
