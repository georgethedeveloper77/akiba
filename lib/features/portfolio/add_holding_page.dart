import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/fund.dart';
import '../../data/providers.dart';

/// v5 `.pg-add` — type → company → balance, all on-device. Re-skinned onto the
/// kit: DisplayHeader + InsTypeCard type grid + selectable company rows.
class AddHoldingPage extends ConsumerStatefulWidget {
  const AddHoldingPage({super.key});
  @override
  ConsumerState<AddHoldingPage> createState() => _AddHoldingPageState();
}

class _AddHoldingPageState extends ConsumerState<AddHoldingPage> {
  String? _category;
  Fund? _fund;
  final _balance = TextEditingController();

  @override
  void dispose() {
    _balance.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_balance.text.replaceAll(',', ''));

  Future<void> _save() async {
    final f = _fund;
    final amount = _amount;
    if (f == null || amount == null || amount <= 0) return;
    await ref
        .read(holdingsProvider.notifier)
        .setBalance(f.id, f.currency, amount);
    if (mounted) Navigator.of(context).pop();
  }

  IconData _icon(String cat) => switch (cat) {
        'mmf_kes' || 'mmf_usd' => Icons.savings_outlined,
        'bond' || 'tbill' => Icons.receipt_long_outlined,
        'sacco' => Icons.account_balance_outlined,
        'stock' || 'equity' => Icons.show_chart,
        'balanced' => Icons.balance,
        'islamic' => Icons.brightness_3_outlined,
        'reit' => Icons.apartment_outlined,
        _ => Icons.category_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final all = ref.watch(ratesProvider).valueOrNull ?? const <Fund>[];
    final cats =
        categoryOrder.where((cat) => all.any((f) => f.category == cat)).toList();
    final funds = _category == null
        ? const <Fund>[]
        : (all.where((f) => f.category == _category).toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
    final canSave = _fund != null && (_amount ?? 0) > 0;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 28),
        children: [
          const DisplayHeader(
            title: 'Add a holding',
            sub: '3 steps \u00b7 stays on this device',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _step(c, '1', 'Type'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                  childAspectRatio: 1.35,
                  children: [
                    for (final cat in cats)
                      InsTypeCard(
                        icon: _icon(cat),
                        label: categoryLabel(cat),
                        sub:
                            '${all.where((f) => f.category == cat).length} available',
                        onTap: () => setState(() {
                          _category = cat;
                          _fund = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                _step(c, '2', 'Company'),
                const SizedBox(height: 12),
                if (_category == null)
                  Text('Pick a type first.',
                      style: TextStyle(color: c.faint, fontSize: 13))
                else
                  for (final f in funds) _companyRow(c, f),
                const SizedBox(height: 24),

                _step(c, '3', 'Balance'),
                const SizedBox(height: 12),
                TextField(
                  controller: _balance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: c.text, fontSize: 20),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: _fund != null ? '${_fund!.currency}  ' : '',
                    prefixStyle: TextStyle(color: c.muted, fontSize: 18),
                    hintText: '0',
                    hintStyle: TextStyle(color: c.faint),
                    filled: true,
                    fillColor: c.s2,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.accent)),
                  ),
                ),
                if (_fund?.currentRate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Earning ${_fund!.currentRate!.toStringAsFixed(2)}% \u2014 Akiba tracks daily interest from here.',
                    style: TextStyle(color: c.faint, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      disabledBackgroundColor: c.s2,
                      disabledForegroundColor: c.faint,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Add to portfolio'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(AkibaColors c, String n, String label) => Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: Text(n,
                style: TextStyle(
                    color: c.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _companyRow(AkibaColors c, Fund f) {
    final active = _fund?.id == f.id;
    return InkWell(
      onTap: () => setState(() => _fund = f),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? c.accentSoft : c.s1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? c.accent : c.line),
        ),
        child: Row(
          children: [
            FundLogo(domain: f.logoDomain, seed: f.manager, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name,
                      style: TextStyle(color: c.text, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${f.currency} \u00b7 ${f.manager}',
                      style: TextStyle(color: c.faint, fontSize: 11)),
                ],
              ),
            ),
            if (f.currentRate != null) ...[
              const SizedBox(width: 8),
              Text('${f.currentRate!.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: c.accent,
                      fontFamily: AkibaFonts.mono,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
