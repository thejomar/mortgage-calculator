import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mortgage = Mortgage();
  await mortgage.loadSavedValues();
  runApp(
    ChangeNotifierProvider.value(
      value: mortgage,
      child: const MortgageApp(),
    ),
  );
}

/// Shared state for both screens, persisted between app launches.
class Mortgage extends ChangeNotifier {
  static const _amountKey = 'loanAmount';
  static const _yearsKey = 'loanYears';
  static const _rateKey = 'interestRate';

  double amount;
  int years;
  double rate;
  late SharedPreferences _preferences;

  Mortgage({this.amount = 100000, this.years = 30, this.rate = 0.035});

  Future<void> loadSavedValues() async {
    _preferences = await SharedPreferences.getInstance();
    amount = _preferences.getDouble(_amountKey) ?? amount;
    years = _preferences.getInt(_yearsKey) ?? years;
    rate = _preferences.getDouble(_rateKey) ?? rate;
  }

  Future<void> updateLoan({
    required double amount,
    required int years,
    required double rate,
  }) async {
    this.amount = amount;
    this.years = years;
    this.rate = rate;
    notifyListeners();
    await Future.wait([
      _preferences.setDouble(_amountKey, amount),
      _preferences.setInt(_yearsKey, years),
      _preferences.setDouble(_rateKey, rate),
    ]);
  }

  double monthlyPayment() {
    final monthlyRate = rate / 12;
    final payments = years * 12;
    if (payments == 0) return 0;
    if (monthlyRate == 0) return amount / payments;
    final discount = 1 / _pow(1 + monthlyRate, payments);
    return amount * monthlyRate / (1 - discount);
  }

  double totalPayment() => monthlyPayment() * years * 12;

  static double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}

class MortgageApp extends StatelessWidget {
  const MortgageApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF172B4D);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mortgage Calculator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF236B63)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F8),
          foregroundColor: navy,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E7E9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF236B63), width: 1.5),
          ),
        ),
      ),
      home: const MortgageHomePage(),
    );
  }
}

class MortgageHomePage extends StatefulWidget {
  const MortgageHomePage({super.key});

  @override
  State<MortgageHomePage> createState() => _MortgageHomePageState();
}

class _MortgageHomePageState extends State<MortgageHomePage> {
  bool termsAccepted = false;

  String money(double value) =>
      '\$${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  Future<void> showTermsDialog() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.description_outlined, color: Color(0xFF236B63)),
        title: const Text('Terms and Conditions'),
        content: const Text(
          'This calculator provides an estimate for educational purposes. '
          'Actual loan terms, fees, and payments may differ. By accepting, '
          'you confirm that you understand the estimate is not a loan offer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I Agree'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => termsAccepted = accepted ?? false);
  }

  void openModifyScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MortgageEditPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mortgage = context.watch<Mortgage>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mortgage Calculator')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF236B63),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.home_work_outlined,
                            color: Colors.white70, size: 28),
                        const SizedBox(height: 18),
                        const Text('ESTIMATED MONTHLY PAYMENT',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(money(mortgage.monthlyPayment()),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 18),
                        const Divider(color: Colors.white30),
                        const SizedBox(height: 10),
                        _summaryRow('Loan amount', money(mortgage.amount)),
                        const SizedBox(height: 12),
                        _summaryRow('Interest rate',
                            '${(mortgage.rate * 100).toStringAsFixed(2)}%'),
                        const SizedBox(height: 12),
                        _summaryRow('Loan term', '${mortgage.years} years'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFE8ECEE))),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment overview',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 18),
                          _detailRow('Total payment',
                              money(mortgage.totalPayment()), Icons.payments_outlined),
                          const SizedBox(height: 8),
                          _detailRow('Number of payments',
                              '${mortgage.years * 12} months', Icons.calendar_month_outlined),
                          const Divider(height: 28),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: termsAccepted,
                            title: const Text('Terms and Conditions',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Review and accept to continue'),
                            onChanged: (_) => showTermsDialog(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: openModifyScreen,
                      icon: const Icon(Icons.tune),
                      label: const Text('Modify loan details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _detailRow(String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF236B63)),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class MortgageEditPage extends StatefulWidget {
  const MortgageEditPage({super.key});

  @override
  State<MortgageEditPage> createState() => _MortgageEditPageState();
}

class _MortgageEditPageState extends State<MortgageEditPage> {
  late final TextEditingController amountController;
  late final TextEditingController yearsController;
  late double selectedRate;
  String? errorMessage;

  static const rates = [
    0.0200, 0.0225, 0.0250, 0.0275, 0.0300, 0.0325, 0.0350, 0.0375,
    0.0400, 0.0425, 0.0450, 0.0475, 0.0500, 0.0525, 0.0550, 0.0575,
    0.0600, 0.0625, 0.0650, 0.0675, 0.0700, 0.0725, 0.0750, 0.0775,
    0.0800, 0.0825, 0.0850, 0.0875, 0.0900, 0.0925, 0.0950, 0.0975,
    0.1000, 0.1025, 0.1050, 0.1075, 0.1100, 0.1125, 0.1150, 0.1175,
    0.1200, 0.1225, 0.1250, 0.1275, 0.1300, 0.1325, 0.1350, 0.1375,
    0.1400, 0.1425, 0.1450, 0.1475, 0.1500,
  ];

  @override
  void initState() {
    super.initState();
    final mortgage = context.read<Mortgage>();
    amountController = TextEditingController(
        text: mortgage.amount.toStringAsFixed(0));
    yearsController = TextEditingController(text: mortgage.years.toString());
    selectedRate = mortgage.rate.clamp(rates.first, rates.last).toDouble();
  }

  @override
  void dispose() {
    amountController.dispose();
    yearsController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    final years = int.tryParse(yearsController.text);
    if (amount == null || amount <= 0 || years == null || years <= 0) {
      setState(() => errorMessage = 'Enter a loan amount and term greater than zero.');
      return;
    }
    await context.read<Mortgage>().updateLoan(
          amount: amount,
          years: years,
          rate: selectedRate,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modify loan')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loan details',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Update your amount, term, and interest rate.'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Loan amount', prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: yearsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Number of years', suffixText: 'years'),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Interest rate',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${(selectedRate * 100).toStringAsFixed(2)}%',
                          style: const TextStyle(
                              color: Color(0xFF236B63),
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Select a rate from 2.00% to 15.00%'),
                  const SizedBox(height: 10),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE1E7E9)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.separated(
                      itemCount: rates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) {
                        final rate = rates[index];
                        final selected = (rate - selectedRate).abs() < 0.000001;
                        return ListTile(
                          dense: true,
                          title: Text('${(rate * 100).toStringAsFixed(2)}%'),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: Color(0xFF236B63))
                              : null,
                          selected: selected,
                          onTap: () => setState(() => selectedRate = rate),
                        );
                      },
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
