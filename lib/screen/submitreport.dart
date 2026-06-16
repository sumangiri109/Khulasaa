import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
//  KHULASAA — Submit Report Screen
//  Zero external packages. Dark/light mode via MyApp.of(context).
//  Place in lib/screens/submit_report_screen_final.dart
// ════════════════════════════════════════════════════════════════════════════

// ─── Colours ─────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFFC0392B);
const _kStepInactive = Color(0xFFCCCAC5);
const _kGreen = Color(0xFF2E7D32);
const _kAmber = Color(0xFFF59E0B);

// Light
const _kBgLight = Color(0xFFF2F0EB);
const _kSurfLight = Color(0xFFFFFFFF);
const _kTxtL = Color(0xFF1A1A1A);
const _kMutedL = Color(0xFF777777);
const _kBorderL = Color(0xFFDDDAD4);
const _kNavBgL = Color(0xFFFFFFFF);
const _kBanBgL = Color(0xFFE8F5E9);
const _kBanTxtL = Color(0xFF2E7D32);

// Dark
const _kBgDark = Color(0xFF1A1917);
const _kSurfDark = Color(0xFF252320);
const _kTxtD = Color(0xFFF0EDE8);
const _kMutedD = Color(0xFF9A9590);
const _kBorderD = Color(0xFF3A3733);
const _kNavBgD = Color(0xFF1E1C1A);
const _kBanBgD = Color(0xFF1B2E1C);
const _kBanTxtD = Color(0xFF6DB870);

// ─── Data Model ───────────────────────────────────────────────────────────────
class ReportModel {
  String institutionName = '';
  String officeType = '';
  String province = '';
  String district = '';
  DateTime? dateOfIncident;
  List<String> categories = [];
  String description = '';
  String amount = '';
  int evidenceCount = 0;
}

class _MockEvidence {
  final String name;
  _MockEvidence(this.name);
}

// ─── Theme helper — reads from MaterialApp's active ThemeData ─────────────────
extension _Th on BuildContext {
  bool get dark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => dark ? _kBgDark : _kBgLight;
  Color get surf => dark ? _kSurfDark : _kSurfLight;
  Color get txt => dark ? _kTxtD : _kTxtL;
  Color get muted => dark ? _kMutedD : _kMutedL;
  Color get bord => dark ? _kBorderD : _kBorderL;
  Color get navBg => dark ? _kNavBgD : _kNavBgL;
  Color get banBg => dark ? _kBanBgD : _kBanBgL;
  Color get banTxt => dark ? _kBanTxtD : _kBanTxtL;
}

// ════════════════════════════════════════════════════════════════════════════
//  SubmitReportScreen
// ════════════════════════════════════════════════════════════════════════════
class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  int _step = 0;
  final _report = ReportModel();

  // Step 1
  final _step1Key = GlobalKey<FormState>();
  final _institutionCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  String? _officeType;
  String? _province;
  DateTime? _date;
  final Set<String> _cats = {};

  // Step 2
  final _step2Key = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _officialCtrl = TextEditingController();
  final _witnessCtrl = TextEditingController();

  // Step 3
  final List<_MockEvidence> _evidence = [];
  int _mockCount = 0;

  // ── Lists ────────────────────────────────────────────────────────────────
  static const _officeTypes = [
    'District Administration Office',
    'Land Revenue Office',
    'Municipality / Ward Office',
    'Police Station',
    'Hospital / Health Post',
    'Tax Office',
    'Transport Management Office',
    'Education Office',
    'Court / Judiciary',
    'Other Government Office',
  ];
  static const _provinces = [
    'Koshi Province',
    'Madhesh Province',
    'Bagmati Province',
    'Gandaki Province',
    'Lumbini Province',
    'Karnali Province',
    'Sudurpashchim Province',
  ];
  static const _corrCats = [
    'Bribery',
    'Fraud',
    'Extortion',
    'Embezzlement',
    'Nepotism',
    'Service delay',
    'Misuse of authority',
    'Other',
  ];

  // ── Navigation ───────────────────────────────────────────────────────────
  void _next() {
    if (_step == 0) {
      if (!_step1Key.currentState!.validate()) return;
      if (_cats.isEmpty) {
        _snack('Please select at least one corruption category');
        return;
      }
    }
    if (_step == 1 && !_step2Key.currentState!.validate()) return;
    if (_step < 3)
      setState(() => _step++);
    else
      _onSubmit();
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _onSubmit() {
    // TODO: wire Firebase here
    _showSuccess();
  }

  void _snack(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _kPrimary));

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _kPrimary)),
        child: child!,
      ),
    );
    if (p != null) setState(() => _date = p);
  }

  void _addEvidence() {
    setState(() {
      _mockCount++;
      _evidence.add(_MockEvidence('photo_$_mockCount.jpg'));
    });
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _institutionCtrl,
      _districtCtrl,
      _descCtrl,
      _amountCtrl,
      _officialCtrl,
      _witnessCtrl,
    ])
      c.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Nav bar ────────────────────────────────────────────────────
            _NavBar(
              onToggleTheme: widget.onToggleTheme,
            ),
            // ── Anonymous banner ───────────────────────────────────────────
            _AnonymousBanner(),
            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PageHeader(),
                          const SizedBox(height: 28),
                          _StepIndicator(currentStep: _step),
                          const SizedBox(height: 28),
                          _buildStep(),
                          const SizedBox(height: 32),
                          _NavButtons(
                            step: _step,
                            onBack: _step > 0 ? _back : null,
                            onNext: _next,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  if (wide) const _SidePanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _Step1(
          formKey: _step1Key,
          institutionCtrl: _institutionCtrl,
          districtCtrl: _districtCtrl,
          officeType: _officeType,
          province: _province,
          date: _date,
          cats: _cats,
          officeTypes: _officeTypes,
          provinces: _provinces,
          corrCats: _corrCats,
          onOfficeType: (v) => setState(() => _officeType = v),
          onProvince: (v) => setState(() => _province = v),
          onPickDate: _pickDate,
          onToggleCat: (c) => setState(
            () => _cats.contains(c) ? _cats.remove(c) : _cats.add(c),
          ),
        );
      case 1:
        return _Step2(
          formKey: _step2Key,
          descCtrl: _descCtrl,
          amountCtrl: _amountCtrl,
          officialCtrl: _officialCtrl,
          witnessCtrl: _witnessCtrl,
        );
      case 2:
        return _Step3(
          items: _evidence,
          onAdd: _addEvidence,
          onRemove: (i) => setState(() => _evidence.removeAt(i)),
        );
      case 3:
        return _Step4Review(
          institutionName: _institutionCtrl.text,
          officeType: _officeType ?? '—',
          province: _province ?? '—',
          district: _districtCtrl.text,
          date: _date,
          categories: _cats.toList(),
          description: _descCtrl.text,
          amount: _amountCtrl.text,
          evidenceCount: _evidence.length,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Nav Bar ──────────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const _NavBar({required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final dark = context.dark;
    final links = ['Home', 'Reports', 'Heatmap', 'Scorecards', 'CIAA'];

    return Container(
      color: context.navBg,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Khulasaa',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.txt,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'खुलासा',
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Nav links — hide on narrow screens
          if (MediaQuery.of(context).size.width > 620)
            ...links.map(
              (l) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.muted,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          // Theme toggle button
          GestureDetector(
            onTap: onToggleTheme,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2A2825) : const Color(0xFFEEEBE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  dark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                  size: 17,
                  color: dark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF555555),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Back to home
          OutlinedButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back, size: 14, color: context.muted),
            label: Text(
              'Back to home',
              style: TextStyle(fontSize: 12, color: context.muted),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.bord),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Anonymous Banner ─────────────────────────────────────────────────────────
class _AnonymousBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.banBg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 14, color: context.banTxt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Anonymous session created — your identity will never be stored or linked to this report',
              style: TextStyle(fontSize: 12, color: context.banTxt),
            ),
          ),
          Text(
            'SESSION: KHU-ANON-MTKHJO',
            style: const TextStyle(
              fontSize: 11,
              color: _kPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page Header ──────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 32, height: 3, color: _kPrimary),
        const SizedBox(height: 12),
        Text(
          'Submit a report',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: context.txt,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your report will be verified, published to the public feed, and escalated to CIAA if it crosses the confidence threshold.',
          style: TextStyle(fontSize: 14, color: context.muted, height: 1.5),
        ),
      ],
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});
  static const _labels = ['INCIDENT', 'DESCRIPTION', 'EVIDENCE', 'REVIEW'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 1.5,
              color: i ~/ 2 < currentStep ? _kPrimary : _kStepInactive,
            ),
          );
        }
        final idx = i ~/ 2;
        final isActive = idx == currentStep;
        final isDone = idx < currentStep;
        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? _kPrimary
                    : isDone
                    ? _kPrimary.withOpacity(0.13)
                    : Colors.transparent,
                border: Border.all(
                  color: isActive || isDone ? _kPrimary : _kStepInactive,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: _kPrimary)
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : _kStepInactive,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _labels[idx],
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: isActive || isDone ? _kPrimary : _kStepInactive,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Step 1 — Incident Details ────────────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController institutionCtrl, districtCtrl;
  final String? officeType, province;
  final DateTime? date;
  final Set<String> cats;
  final List<String> officeTypes, provinces, corrCats;
  final ValueChanged<String?> onOfficeType, onProvince;
  final VoidCallback onPickDate;
  final ValueChanged<String> onToggleCat;

  const _Step1({
    required this.formKey,
    required this.institutionCtrl,
    required this.districtCtrl,
    required this.officeType,
    required this.province,
    required this.date,
    required this.cats,
    required this.officeTypes,
    required this.provinces,
    required this.corrCats,
    required this.onOfficeType,
    required this.onProvince,
    required this.onPickDate,
    required this.onToggleCat,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: 'SECTION A — INCIDENT DETAILS',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Lbl('Institution name'),
            _TF(
              ctrl: institutionCtrl,
              hint: 'e.g. Kathmandu District Land Revenue Office',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Lbl('Office type'),
                      _DD(
                        hint: 'Select type',
                        value: officeType,
                        items: officeTypes,
                        onChanged: onOfficeType,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Lbl('Province'),
                      _DD(
                        hint: 'Select province',
                        value: province,
                        items: provinces,
                        onChanged: onProvince,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Lbl('District'),
                      _TF(
                        ctrl: districtCtrl,
                        hint: 'e.g. Kathmandu',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Lbl('Date of incident'),
                      _DateBtn(date: date, onTap: onPickDate),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Corruption category chips
            _Lbl('Corruption category'),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Select the type that best describes the incident',
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: corrCats.map((cat) {
                final sel = cats.contains(cat);
                return GestureDetector(
                  onTap: () => onToggleCat(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? _kPrimary.withOpacity(0.09) : context.bg,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: sel ? _kPrimary : context.bord,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? _kPrimary : context.muted,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel ? _kPrimary : context.txt,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2 — Description ─────────────────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController descCtrl, amountCtrl, officialCtrl, witnessCtrl;

  const _Step2({
    required this.formKey,
    required this.descCtrl,
    required this.amountCtrl,
    required this.officialCtrl,
    required this.witnessCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: 'SECTION B — INCIDENT DESCRIPTION',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Lbl('Describe what happened'),
            TextFormField(
              controller: descCtrl,
              maxLines: 6,
              style: TextStyle(fontSize: 14, color: context.txt),
              decoration: _deco(
                context,
                'Describe the incident in detail — what happened, who was involved, and how it affected you...',
              ),
              validator: (v) => (v == null || v.trim().length < 30)
                  ? 'Please provide at least 30 characters'
                  : null,
            ),
            const SizedBox(height: 20),
            _Lbl('Were any officials involved?', req: false),
            _TF(
              ctrl: officialCtrl,
              hint: 'Name or designation of official (optional)',
            ),
            const SizedBox(height: 20),
            _Lbl('Amount demanded / paid (if applicable)', req: false),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.bg,
                    border: Border(
                      top: BorderSide(color: context.bord),
                      bottom: BorderSide(color: context.bord),
                      left: BorderSide(color: context.bord),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    'NPR',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14, color: context.txt),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(fontSize: 13, color: context.muted),
                      filled: true,
                      fillColor: context.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        borderSide: BorderSide(color: context.bord),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        borderSide: BorderSide(color: context.bord),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        borderSide: BorderSide(color: _kPrimary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Lbl('Were there witnesses?', req: false),
            _TF(ctrl: witnessCtrl, hint: 'Describe any witnesses (optional)'),
          ],
        ),
      ),
    );
  }
}

// ─── Step 3 — Evidence ────────────────────────────────────────────────────────
class _Step3 extends StatelessWidget {
  final List<_MockEvidence> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _Step3({
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: 'SECTION C — EVIDENCE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload photos, screenshots, or documents that support your report. '
            'All files are encrypted end-to-end before storage.',
            style: TextStyle(fontSize: 13, color: context.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.bord),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: _kPrimary.withOpacity(0.7),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to upload evidence',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: context.txt,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photos, screenshots, PDFs accepted',
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                ],
              ),
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(items.length, (i) {
                return Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: context.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.bord),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 28,
                            color: context.muted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items[i].name.length > 10
                                ? '${items[i].name.substring(0, 10)}…'
                                : items[i].name,
                            style: TextStyle(fontSize: 9, color: context.muted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: GestureDetector(
                        onTap: () => onRemove(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: _kPrimary,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 13, color: _kGreen),
              const SizedBox(width: 6),
              Text(
                'End-to-end encrypted before upload',
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add image_picker to pubspec.yaml and replace _addEvidence() with your picker call.',
                    style: TextStyle(fontSize: 11, color: context.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4 — Review ─────────────────────────────────────────────────────────
class _Step4Review extends StatelessWidget {
  final String institutionName, officeType, province, district;
  final DateTime? date;
  final List<String> categories;
  final String description, amount;
  final int evidenceCount;

  const _Step4Review({
    required this.institutionName,
    required this.officeType,
    required this.province,
    required this.district,
    required this.date,
    required this.categories,
    required this.description,
    required this.amount,
    required this.evidenceCount,
  });

  String get _dateStr {
    if (date == null) return '—';
    return '${date!.day.toString().padLeft(2, '0')}/'
        '${date!.month.toString().padLeft(2, '0')}/${date!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: 'SECTION D — REVIEW YOUR REPORT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please review the details before submitting. Once submitted, the report cannot be edited.',
            style: TextStyle(fontSize: 13, color: context.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          _RRow('Institution', institutionName.isEmpty ? '—' : institutionName),
          _RRow('Office type', officeType),
          _RRow('Province', province),
          _RRow('District', district.isEmpty ? '—' : district),
          _RRow('Date of incident', _dateStr),
          Divider(height: 28, color: context.bord),
          _RRow('Categories', categories.isEmpty ? '—' : categories.join(', ')),
          _RRow('Description', description.isEmpty ? '—' : description),
          if (amount.isNotEmpty && amount != '0')
            _RRow('Amount', 'NPR $amount'),
          Divider(height: 28, color: context.bord),
          _RRow('Evidence', '$evidenceCount file(s) attached'),
          const SizedBox(height: 20),
          // CIAA notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kAmber.withOpacity(0.4)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 15, color: _kAmber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reports above 80% confidence score will be escalated to CIAA for formal action.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7B5800)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Privacy notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, size: 15, color: _kGreen),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your identity is fully protected. No personal data has been collected.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav Buttons ──────────────────────────────────────────────────────────────
class _NavButtons extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  const _NavButtons({
    required this.step,
    required this.onBack,
    required this.onNext,
  });

  static const _labels = [
    'Continue → Description',
    'Continue → Evidence',
    'Continue → Review',
    'Submit report',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          OutlinedButton.icon(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, size: 15, color: context.txt),
            label: Text('Back', style: TextStyle(color: context.txt)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.bord),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: _kPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _labels[step],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                step == 3 ? Icons.send_outlined : Icons.arrow_forward,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Side Panel ───────────────────────────────────────────────────────────────
class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(0, 28, 24, 28),
      child: Column(
        children: [
          _Tile(
            icon: Icons.shield_outlined,
            color: _kGreen,
            title: 'ANONYMOUS',
            body: 'No account needed. Zero personal data collected or stored.',
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.lock_outline,
            color: _kPrimary,
            title: 'ENCRYPTED',
            body: 'All evidence files are encrypted end-to-end before storage.',
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.account_balance_outlined,
            color: _kAmber,
            title: 'CIAA LINKED',
            body:
                'Reports above 80% confidence are shared with CIAA for formal action.',
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.bar_chart_outlined,
            color: const Color(0xFF6366F1),
            title: 'CONFIDENCE SCORE',
            body:
                'ML engine scores each report using NLP & K-Means clustering.',
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, body;
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surf,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.bord),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(fontSize: 12, color: context.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─── Success Sheet ────────────────────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessSheet({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 36,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Report submitted',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.txt,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your anonymous report has been received and is now under review. '
            'Track its status using your session ID.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared tiny widgets ──────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String label;
  final Widget child;
  const _Card({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.bord),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  final String text;
  final bool req;
  const _Lbl(this.text, {this.req = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.txt,
            ),
          ),
          if (req)
            const Text(' *', style: TextStyle(color: _kPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;
  const _TF({
    required this.ctrl,
    required this.hint,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14, color: context.txt),
      decoration: _deco(context, hint),
      validator: validator,
    );
  }
}

class _DD extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  const _DD({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint, style: TextStyle(fontSize: 13, color: context.muted)),
      items: items
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(
                t,
                style: TextStyle(fontSize: 13, color: context.txt),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.muted),
      dropdownColor: context.surf,
      borderRadius: BorderRadius.circular(8),
      decoration: InputDecoration(
        filled: true,
        fillColor: context.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.bord),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.bord),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  const _DateBtn({required this.date, required this.onTap});

  String get _label {
    final d = date ?? DateTime.now();
    return '${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.bord),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_label, style: TextStyle(fontSize: 13, color: context.txt)),
            Icon(Icons.calendar_today_outlined, size: 15, color: context.muted),
          ],
        ),
      ),
    );
  }
}

class _RRow extends StatelessWidget {
  final String label, value;
  const _RRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: context.txt),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _deco(BuildContext ctx, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(fontSize: 13, color: ctx.muted),
  filled: true,
  fillColor: ctx.bg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: ctx.bord),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: ctx.bord),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: _kPrimary, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: _kPrimary),
  ),
);
