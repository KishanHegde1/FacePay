import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/design.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final query = _searchController.text.toLowerCase().trim();
        final transactions =
            widget.state.transactions
                .where(
                  (transaction) =>
                      (_filter == 'All' ||
                          (_filter == 'Received'
                              ? transaction.incoming
                              : !transaction.incoming)) &&
                      '${transaction.title} ${transaction.subtitle} ${transaction.category} ${transaction.id}'
                          .toLowerCase()
                          .contains(query),
                )
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        final groups = <String, List<PaymentTransaction>>{};
        for (final transaction in transactions) {
          groups
              .putIfAbsent(_dateLabel(transaction.date), () => [])
              .add(transaction);
        }
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.all(constraints.maxWidth < 720 ? 20 : 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR MONEY, IN MOTION',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Activity',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.1,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Local demo activity is labelled clearly below. Verified transaction details will appear after payment services are connected.',
                      style: TextStyle(color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    SurfaceCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search transactions or references',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.muted,
                              ),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () =>
                                          setState(_searchController.clear),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 19,
                                      ),
                                    ),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['All', 'Sent', 'Received']
                                .map(
                                  (filter) => ChoiceChip(
                                    label: Text(filter),
                                    selected: _filter == filter,
                                    showCheckmark: false,
                                    onSelected: (_) =>
                                        setState(() => _filter = filter),
                                    selectedColor: AppColors.primary,
                                    backgroundColor: AppColors.surface,
                                    side: BorderSide(
                                      color: _filter == filter
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _filter == filter
                                          ? Colors.white
                                          : AppColors.muted,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    if (transactions.isEmpty)
                      SurfaceCard(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              Container(
                                width: 68,
                                height: 68,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryLight,
                                ),
                                child: const Icon(
                                  Icons.search_off_rounded,
                                  size: 31,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Nothing here just yet',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                query.isNotEmpty || _filter != 'All'
                                    ? 'Try a different search or view all transactions.'
                                    : 'There is no demo payment activity yet.',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (query.isNotEmpty || _filter != 'All')
                                TextButton(
                                  onPressed: () => setState(() {
                                    _filter = 'All';
                                    _searchController.clear();
                                  }),
                                  child: const Text('Clear filters'),
                                ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ...groups.entries.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 2,
                                bottom: 12,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    group.key,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${group.value.length} ${group.value.length == 1 ? 'payment' : 'payments'}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SurfaceCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 5,
                              ),
                              child: Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < group.value.length;
                                    index++
                                  ) ...[
                                    if (index != 0)
                                      const Divider(
                                        height: 1,
                                        color: AppColors.border,
                                      ),
                                    _TransactionRow(
                                      transaction: group.value[index],
                                      onTap: () => _showReceipt(
                                        context,
                                        group.value[index],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Transaction history',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReceipt(BuildContext context, PaymentTransaction transaction) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF21806C),
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                transaction.isDemo
                    ? 'Demo payment recorded'
                    : 'Payment complete',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                transaction.isDemo
                    ? 'No money moved · local preview only'
                    : transaction.incoming
                    ? 'Received payment'
                    : 'Sent payment',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FittedBox(
                child: Text(
                  '${transaction.incoming ? '+' : '−'}${formatMoney(transaction.amount)}',
                  style: const TextStyle(
                    fontSize: 38,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              SurfaceCard(
                color: AppColors.background,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _ReceiptLine(
                      label: transaction.incoming ? 'From' : 'To',
                      value: transaction.title,
                    ),
                    _ReceiptLine(label: 'Details', value: transaction.subtitle),
                    _ReceiptLine(
                      label: 'Date',
                      value: _fullDate(transaction.date),
                    ),
                    _ReceiptLine(
                      label: 'Category',
                      value: transaction.category,
                    ),
                    _ReceiptLine(label: 'Reference', value: transaction.id),
                    _ReceiptLine(
                      label: 'Status',
                      value: transaction.isDemo ? 'Demo complete' : 'Completed',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              Text(
                transaction.isDemo
                    ? 'This demo item is kept only while the app is open. No money moved.'
                    : 'Transaction details are shown after verified payment activity is available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.onTap});
  final PaymentTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lower = '${transaction.category} ${transaction.title}'.toLowerCase();
    final icon = transaction.incoming
        ? Icons.south_west_rounded
        : lower.contains('coffee') || lower.contains('food')
        ? Icons.local_cafe_outlined
        : lower.contains('shop')
        ? Icons.shopping_bag_outlined
        : Icons.north_east_rounded;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: transaction.incoming
                    ? AppColors.mint
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: transaction.incoming
                    ? const Color(0xFF21806C)
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (transaction.isDemo)
                    const Text(
                      'DEMO · NO MONEY MOVED',
                      style: TextStyle(
                        color: Color(0xFF9A6500),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .35,
                      ),
                    )
                  else
                    Text(
                      transaction.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.incoming ? '+' : '−'}${formatMoney(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: transaction.incoming
                        ? const Color(0xFF21806C)
                        : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _time(transaction.date),
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String _dateLabel(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(date);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String _time(DateTime date) =>
    '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
String _fullDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}, ${_time(date)}';
