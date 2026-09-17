import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/design.dart';

class DemoBank {
  const DemoBank({
    required this.id,
    required this.name,
    required this.monogram,
    required this.color,
  });

  final String id;
  final String name;
  final String monogram;
  final Color color;
}

const demoBanks = <DemoBank>[
  DemoBank(
    id: 'sbi',
    name: 'State Bank of India',
    monogram: 'SBI',
    color: Color(0xFF4B69C8),
  ),
  DemoBank(
    id: 'hdfc',
    name: 'HDFC Bank',
    monogram: 'HDFC',
    color: Color(0xFF3462A6),
  ),
  DemoBank(
    id: 'icici',
    name: 'ICICI Bank',
    monogram: 'ICICI',
    color: Color(0xFFC16042),
  ),
  DemoBank(
    id: 'axis',
    name: 'Axis Bank',
    monogram: 'AXIS',
    color: Color(0xFF8D416E),
  ),
  DemoBank(
    id: 'kotak',
    name: 'Kotak Mahindra Bank',
    monogram: 'KOTAK',
    color: Color(0xFFBD4653),
  ),
  DemoBank(
    id: 'bob',
    name: 'Bank of Baroda',
    monogram: 'BOB',
    color: Color(0xFFDB733E),
  ),
  DemoBank(
    id: 'pnb',
    name: 'Punjab National Bank',
    monogram: 'PNB',
    color: Color(0xFF9A4E40),
  ),
  DemoBank(
    id: 'canara',
    name: 'Canara Bank',
    monogram: 'CAN',
    color: Color(0xFFE19630),
  ),
  DemoBank(
    id: 'union',
    name: 'Union Bank of India',
    monogram: 'UBI',
    color: Color(0xFFB45C4B),
  ),
  DemoBank(
    id: 'indian',
    name: 'Indian Bank',
    monogram: 'IND',
    color: Color(0xFF465D9E),
  ),
  DemoBank(
    id: 'idfc',
    name: 'IDFC FIRST Bank',
    monogram: 'IDFC',
    color: Color(0xFF9E354C),
  ),
  DemoBank(
    id: 'indusind',
    name: 'IndusInd Bank',
    monogram: 'INDUS',
    color: Color(0xFF9A5A72),
  ),
  DemoBank(
    id: 'yes',
    name: 'YES BANK',
    monogram: 'YES',
    color: Color(0xFF4F6CB3),
  ),
  DemoBank(
    id: 'federal',
    name: 'Federal Bank',
    monogram: 'FED',
    color: Color(0xFF38677D),
  ),
  DemoBank(
    id: 'au',
    name: 'AU Small Finance Bank',
    monogram: 'AU',
    color: Color(0xFF9A6256),
  ),
  DemoBank(
    id: 'bandhan',
    name: 'Bandhan Bank',
    monogram: 'BAND',
    color: Color(0xFF9D5D83),
  ),
  DemoBank(
    id: 'rbl',
    name: 'RBL Bank',
    monogram: 'RBL',
    color: Color(0xFF6B589E),
  ),
  DemoBank(
    id: 'uco',
    name: 'UCO Bank',
    monogram: 'UCO',
    color: Color(0xFF4E7F7C),
  ),
  DemoBank(
    id: 'central',
    name: 'Central Bank of India',
    monogram: 'CBI',
    color: Color(0xFF477E85),
  ),
  DemoBank(
    id: 'iob',
    name: 'Indian Overseas Bank',
    monogram: 'IOB',
    color: Color(0xFF5279AD),
  ),
];

class BankLinkScreen extends StatefulWidget {
  const BankLinkScreen({super.key, required this.state});

  final AppState state;

  @override
  State<BankLinkScreen> createState() => _BankLinkScreenState();
}

class _BankLinkScreenState extends State<BankLinkScreen> {
  DemoBank? _selected;
  String _query = '';
  bool _checkingAccount = false;

  List<DemoBank> get _visibleBanks {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return demoBanks;
    return demoBanks
        .where(
          (bank) =>
              bank.name.toLowerCase().contains(query) ||
              bank.monogram.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final linked = widget.state.linkedBank;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Link bank account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            tooltip: 'Back to dashboard',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: linked != null
            ? _linkedView(context, linked)
            : _checkingAccount
            ? _accountCheck(context)
            : _bankPicker(context),
      );
    },
  );

  Widget _page({required Widget child}) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        constraints.maxWidth < 600 ? 20 : 32,
        18,
        constraints.maxWidth < 600 ? 20 : 32,
        36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: child,
        ),
      ),
    ),
  );

  Widget _bankPicker(BuildContext context) => _page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEMO BANK DIRECTORY',
          style: TextStyle(
            color: AppPalette.of(context).muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Choose your bank',
          style: TextStyle(
            fontSize: 31,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Explore the linking experience before connecting a real payment provider.',
          style: TextStyle(
            color: AppPalette.of(context).muted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        SizedBox(height: 24),
        _demoNotice(),
        SizedBox(height: 24),
        TextField(
          key: const ValueKey('bank-search'),
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search a demo bank',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        SizedBox(height: 14),
        Text(
          _query.trim().isEmpty
              ? '${demoBanks.length} banks in this demo'
              : '${_visibleBanks.length} matching banks',
          style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted),
        ),
        SizedBox(height: 12),
        if (_visibleBanks.isEmpty)
          SurfaceCard(
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: AppPalette.of(context).muted,
                  size: 36,
                ),
                SizedBox(height: 12),
                Text(
                  'No demo bank found',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Try another bank name.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.of(context).muted,
                  ),
                ),
              ],
            ),
          )
        else
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < _visibleBanks.length; index++) ...[
                  _bankOption(_visibleBanks[index]),
                  if (index != _visibleBanks.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        if (_selected != null) ...[
          SizedBox(height: 20),
          _selectionSummary(_selected!),
          SizedBox(height: 16),
          PrimaryButton(
            key: const ValueKey('bank-continue'),
            label: 'Continue with ${_selected!.name}',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() => _checkingAccount = true),
          ),
        ],
      ],
    ),
  );

  Widget _demoNotice() => SurfaceCard(
    color: AppPalette.of(context).tint(const Color(0xFFF0EDFF)),
    radius: 18,
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.visibility_outlined,
          color: AppPalette.of(context).primary,
          size: 21,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Demo only', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text(
                'No real bank connection, account number, OTP, or money movement is requested here.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: AppPalette.of(context).muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _bankOption(DemoBank bank) {
    final selected = _selected?.id == bank.id;
    return Material(
      color: selected
          ? AppPalette.of(context).tint(const Color(0xFFF8F7FE))
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('bank-option-${bank.id}'),
        onTap: () => setState(() => _selected = bank),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              _BankMark(bank: bank, size: 42),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  bank.name,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('selected'),
                        color: (AppPalette.of(context).dark
                            ? const Color(0xFF88DAB9)
                            : const Color(0xFF338767)),
                        size: 22,
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        key: ValueKey('unselected'),
                        color: AppPalette.of(context).muted,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionSummary(DemoBank bank) => SurfaceCard(
    color: AppPalette.of(context).tint(const Color(0xFFFBFBFE)),
    radius: 18,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        _BankMark(bank: bank, size: 42),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected bank',
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.of(context).muted,
                ),
              ),
              SizedBox(height: 2),
              Text(bank.name, style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _selected = null),
          child: Text('Change'),
        ),
      ],
    ),
  );

  Widget _accountCheck(BuildContext context) {
    final bank = _selected!;
    return _page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ONE LAST LOOK',
            style: TextStyle(
              color: AppPalette.of(context).muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Review your demo account',
            style: TextStyle(
              fontSize: 31,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'This is an illustrative account label, not a real bank account.',
            style: TextStyle(
              color: AppPalette.of(context).muted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          SizedBox(height: 28),
          SurfaceCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BankMark(bank: bank, size: 52),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bank.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Savings account · •••• 4821',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Divider(),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: (AppPalette.of(context).dark
                          ? const Color(0xFF88DAB9)
                          : const Color(0xFF338767)),
                      size: 19,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This preview does not collect bank credentials or send an OTP. A real connection will be added only after a payment provider is chosen.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppPalette.of(context).muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 22),
          PrimaryButton(
            key: const ValueKey('bank-link-confirm'),
            label: 'Link demo account',
            icon: Icons.link_rounded,
            onPressed: () => widget.state.linkDemoBank(
              name: bank.name,
              monogram: bank.monogram,
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _checkingAccount = false),
              child: Text('Choose a different bank'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkedView(BuildContext context, DemoLinkedBank bank) => _page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BANK LINK COMPLETE',
          style: TextStyle(
            color: AppPalette.of(context).muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Your demo bank is linked',
          style: TextStyle(
            fontSize: 31,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'You can see this connection on your dashboard and wallet while this preview is open.',
          style: TextStyle(
            color: AppPalette.of(context).muted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        SizedBox(height: 28),
        SurfaceCard(
          key: const ValueKey('bank-linked-card'),
          color: AppPalette.of(context).tint(const Color(0xFFF6FBF8)),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppPalette.of(
                        context,
                      ).tint(const Color(0xFFDDF6EA)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: (AppPalette.of(context).dark
                          ? const Color(0xFF88DAB9)
                          : const Color(0xFF338767)),
                    ),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Demo connection active',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Divider(),
              ),
              Row(
                children: [
                  _LinkedBankMark(bank: bank, size: 52),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Savings account · •••• ${bank.lastFour}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'No real bank account or funds are connected in this demo.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.of(context).muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 22),
        PrimaryButton(
          label: 'Back to dashboard',
          icon: Icons.grid_view_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
        Center(
          child: TextButton.icon(
            key: const ValueKey('bank-unlink'),
            onPressed: () => _askToUnlink(context),
            icon: Icon(Icons.link_off_rounded, size: 18),
            label: Text('Unlink demo bank'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.of(context).danger,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _askToUnlink(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unlink demo bank?'),
        content: Text(
          'This removes only the local preview label. No real bank connection exists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep linked'),
          ),
          FilledButton(
            key: const ValueKey('bank-unlink-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Unlink'),
          ),
        ],
      ),
    );
    if (remove == true && mounted) {
      widget.state.unlinkDemoBank();
      setState(() {
        _selected = null;
        _checkingAccount = false;
      });
    }
  }
}

class _BankMark extends StatelessWidget {
  const _BankMark({required this.bank, required this.size});

  final DemoBank bank;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: bank.color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(size * .31),
    ),
    child: Text(
      bank.monogram,
      style: TextStyle(
        color: bank.color,
        fontSize: size < 48 ? 9 : 10,
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
      ),
    ),
  );
}

class _LinkedBankMark extends StatelessWidget {
  const _LinkedBankMark({required this.bank, required this.size});

  final DemoLinkedBank bank;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppPalette.of(context).primaryLight,
      borderRadius: BorderRadius.circular(size * .31),
    ),
    child: Text(
      bank.monogram,
      style: TextStyle(
        color: AppPalette.of(context).primary,
        fontSize: size < 48 ? 9 : 10,
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
      ),
    ),
  );
}
