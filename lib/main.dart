import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

@JS('localStorage.getItem')
external JSString? _lsGet(JSString key);

@JS('localStorage.setItem')
external void _lsSet(JSString key, JSString value);

@JS('localStorage.removeItem')
external void _lsRemove(JSString key);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = LocalStoragePizza();
  final state = storage.load() ?? AppState.initial();
  runApp(PizzaBudgetApp(storage: storage, initialState: state));
}

String newId() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String dateText(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

double parseMoney(String text) {
  var s = text.replaceAll(r'$', '').replaceAll(' ', '').trim();
  if (s.contains('.') && s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (s.contains(',')) {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s) ?? 0;
}

String money(double value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$${out.toString()}';
}

const supportMessages = [
  'Elegiste tu objetivo por encima del impulso. Esa decisión vale mucho.',
  'Una compra evitada puede convertirse en un paso concreto hacia tu meta.',
  'Tu plata acaba de recibir una misión más importante.',
  'Cada transferencia consciente fortalece el hábito que querés construir.',
  'Hoy no fue solo ahorrar: fue decidir a favor de tu objetivo.',
  'Pequeñas decisiones repetidas pueden cambiar por completo tu resultado.',
];

class LocalStoragePizza {
  static const key = 'pizza_budget_production_v2';
  static const backupKey = 'pizza_budget_production_v2_backup';
  static const legacyKey = 'pizza_budget_production_v1';

  AppState? load() {
    final primary = _decode(_read(key));
    if (primary != null) return primary;

    final backup = _decode(_read(backupKey));
    if (backup != null) {
      save(backup);
      return backup;
    }

    final legacy = _decode(_read(legacyKey));
    if (legacy != null) {
      save(legacy);
      return legacy;
    }

    return null;
  }

  String? _read(String storageKey) {
    try {
      return _lsGet(storageKey.toJS)?.toDart;
    } catch (_) {
      return null;
    }
  }

  AppState? _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AppState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  void save(AppState state) {
    try {
      state.updatedAt = DateTime.now();
      final current = _read(key);
      if (current != null && current.trim().isNotEmpty) {
        _lsSet(backupKey.toJS, current.toJS);
      }
      final encoded = jsonEncode(state.toJson());
      _lsSet(key.toJS, encoded.toJS);
    } catch (_) {}
  }

  void clear() {
    try {
      _lsRemove(key.toJS);
      _lsRemove(backupKey.toJS);
      _lsRemove(legacyKey.toJS);
    } catch (_) {}
  }
}

class Envelope {
  final String id;
  String name;
  String emoji;
  double initialAmount;
  double usedAmount;
  int colorValue;

  Envelope({
    String? id,
    required this.name,
    required this.emoji,
    required this.initialAmount,
    this.usedAmount = 0,
    required this.colorValue,
  }) : id = id ?? idGen();

  static String idGen() => newId();
  double get remaining => max(0, initialAmount - usedAmount);
  double get usage => initialAmount <= 0 ? 0 : (usedAmount / initialAmount).clamp(0.0, 1.0);
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'initialAmount': initialAmount,
        'usedAmount': usedAmount,
        'colorValue': colorValue,
      };

  factory Envelope.fromJson(Map<String, dynamic> j) => Envelope(
        id: j['id']?.toString(),
        name: (j['name'] ?? '').toString(),
        emoji: (j['emoji'] ?? '🍕').toString(),
        initialAmount: (j['initialAmount'] as num?)?.toDouble() ?? 0,
        usedAmount: (j['usedAmount'] as num?)?.toDouble() ?? 0,
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFFEF5350,
      );
}

class Goal {
  final String id;
  String name;
  double target;
  double saved;
  double previousSavings;
  double reservedThisMonth;
  DateTime deadline;
  bool active;

  Goal({
    String? id,
    required this.name,
    required this.target,
    required this.saved,
    required this.previousSavings,
    required this.reservedThisMonth,
    required this.deadline,
    this.active = false,
  }) : id = id ?? idGen();

  static String idGen() => newId();
  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'previousSavings': previousSavings,
        'reservedThisMonth': reservedThisMonth,
        'deadline': deadline.toIso8601String(),
        'active': active,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id']?.toString(),
        name: (j['name'] ?? '').toString(),
        target: (j['target'] as num?)?.toDouble() ?? 0,
        saved: (j['saved'] as num?)?.toDouble() ?? 0,
        previousSavings: (j['previousSavings'] as num?)?.toDouble() ?? 0,
        reservedThisMonth: (j['reservedThisMonth'] as num?)?.toDouble() ?? 0,
        deadline: DateTime.tryParse((j['deadline'] ?? '').toString()) ?? DateTime.now().add(const Duration(days: 180)),
        active: j['active'] == true,
      );
}

class FixedExpense {
  final String id;
  String name;
  double monthlyAmount;
  int remainingInstallments;

  FixedExpense({String? id, required this.name, required this.monthlyAmount, required this.remainingInstallments})
      : id = id ?? idGen();

  static String idGen() => newId();
  double get committedAmount => monthlyAmount * max(0, remainingInstallments);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'monthlyAmount': monthlyAmount,
        'remainingInstallments': remainingInstallments,
      };

  factory FixedExpense.fromJson(Map<String, dynamic> j) => FixedExpense(
        id: j['id']?.toString(),
        name: (j['name'] ?? '').toString(),
        monthlyAmount: (j['monthlyAmount'] as num?)?.toDouble() ?? 0,
        remainingInstallments: (j['remainingInstallments'] as num?)?.toInt() ?? 1,
      );
}

enum MovementType { expense, goalTransfer }

class Movement {
  final String id;
  final MovementType type;
  final String envelopeId;
  final String envelopeName;
  final String envelopeEmoji;
  final double amount;
  final DateTime at;
  final String detail;
  final String? goalId;
  final String? goalName;
  final String? support;

  Movement({
    String? id,
    required this.type,
    required this.envelopeId,
    required this.envelopeName,
    required this.envelopeEmoji,
    required this.amount,
    DateTime? at,
    required this.detail,
    this.goalId,
    this.goalName,
    this.support,
  })  : id = id ?? idGen(),
        at = at ?? DateTime.now();

  static String idGen() => newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'envelopeId': envelopeId,
        'envelopeName': envelopeName,
        'envelopeEmoji': envelopeEmoji,
        'amount': amount,
        'at': at.toIso8601String(),
        'detail': detail,
        'goalId': goalId,
        'goalName': goalName,
        'support': support,
      };

  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
        id: j['id']?.toString(),
        type: MovementType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => MovementType.expense,
        ),
        envelopeId: (j['envelopeId'] ?? '').toString(),
        envelopeName: (j['envelopeName'] ?? '').toString(),
        envelopeEmoji: (j['envelopeEmoji'] ?? '🍕').toString(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        at: DateTime.tryParse((j['at'] ?? '').toString()),
        detail: (j['detail'] ?? '').toString(),
        goalId: j['goalId']?.toString(),
        goalName: j['goalName']?.toString(),
        support: j['support']?.toString(),
      );
}

class AppState {
  double salary;
  double hourlyIncome;
  DateTime? nextPayday;
  List<Goal> goals;
  List<FixedExpense> fixedExpenses;
  List<Envelope> envelopes;
  List<Movement> history;
  bool onboardingDone;
  bool googleDemoLinked;
  String demoEmail;
  DateTime updatedAt;

  AppState({
    required this.salary,
    required this.hourlyIncome,
    required this.nextPayday,
    required this.goals,
    required this.fixedExpenses,
    required this.envelopes,
    required this.history,
    required this.onboardingDone,
    required this.googleDemoLinked,
    required this.demoEmail,
    required this.updatedAt,
  });

  factory AppState.initial() => AppState(
        salary: 0,
        hourlyIncome: 0,
        nextPayday: null,
        goals: [],
        fixedExpenses: [],
        envelopes: [
          Envelope(name: 'Joda', emoji: '🎉', initialAmount: 0, colorValue: 0xFFEF5350),
          Envelope(name: 'Comida', emoji: '🍔', initialAmount: 0, colorValue: 0xFFFFB74D),
          Envelope(name: 'Apuntes', emoji: '📚', initialAmount: 0, colorValue: 0xFF66BB6A),
          Envelope(name: 'Transporte', emoji: '🚌', initialAmount: 0, colorValue: 0xFF42A5F5),
          Envelope(name: 'Varios', emoji: '💸', initialAmount: 0, colorValue: 0xFFAB47BC),
        ],
        history: [],
        onboardingDone: false,
        googleDemoLinked: false,
        demoEmail: 'usuario@gmail.com',
        updatedAt: DateTime.now(),
      );

  double get reservedSavings => goals.fold(0.0, (s, g) => s + g.reservedThisMonth);
  double get fixedCommitted => fixedExpenses.fold(0.0, (s, g) => s + g.committedAmount);
  double get freeFundInitial => salary - reservedSavings - fixedCommitted;
  double get envelopesAssigned => envelopes.fold(0.0, (s, e) => s + e.initialAmount);
  double get freeFundNow => envelopes.fold(0.0, (s, e) => s + e.remaining);

  Goal? get activeGoal {
    for (final g in goals) {
      if (g.active) return g;
    }
    return goals.isEmpty ? null : goals.first;
  }

  int get daysToPayday {
    if (nextPayday == null) return 0;
    return max(0, dateOnly(nextPayday!).difference(dateOnly(DateTime.now())).inDays);
  }

  double get dailyBudget {
    final d = daysToPayday;
    if (d <= 0) return freeFundNow;
    return freeFundNow / d;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'salary': salary,
        'hourlyIncome': hourlyIncome,
        'nextPayday': nextPayday?.toIso8601String(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'fixedExpenses': fixedExpenses.map((e) => e.toJson()).toList(),
        'envelopes': envelopes.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
        'onboardingDone': onboardingDone,
        'googleDemoLinked': googleDemoLinked,
        'demoEmail': demoEmail,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AppState.fromJson(Map<String, dynamic> j) => AppState(
        salary: (j['salary'] as num?)?.toDouble() ?? 0,
        hourlyIncome: (j['hourlyIncome'] as num?)?.toDouble() ?? 0,
        nextPayday: j['nextPayday'] == null ? null : DateTime.tryParse(j['nextPayday'].toString()),
        goals: ((j['goals'] as List?) ?? []).whereType<Map>().map((e) => Goal.fromJson(Map<String, dynamic>.from(e))).toList(),
        fixedExpenses: ((j['fixedExpenses'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => FixedExpense.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        envelopes: ((j['envelopes'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Envelope.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        history: ((j['history'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Movement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        onboardingDone: j['onboardingDone'] == true,
        googleDemoLinked: j['googleDemoLinked'] == true,
        demoEmail: (j['demoEmail'] ?? 'usuario@gmail.com').toString(),
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '').toString()) ?? DateTime.now(),
      );
}

class PizzaBudgetApp extends StatelessWidget {
  final LocalStoragePizza storage;
  final AppState initialState;

  const PizzaBudgetApp({super.key, required this.storage, required this.initialState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizza Budget',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: HomeScreen(storage: storage, initialState: initialState),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final LocalStoragePizza storage;
  final AppState initialState;

  const HomeScreen({super.key, required this.storage, required this.initialState});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppState state;
  String? selectedEnvelopeId;
  int onboardingStep = 0;

  @override
  void initState() {
    super.initState();
    state = widget.initialState;
    onboardingStep = _resumeStep();
  }

  int _resumeStep() {
    if (state.salary <= 0 || state.nextPayday == null) return 0;
    if (state.goals.isEmpty) return 1;
    if (state.fixedExpenses.isEmpty) return 2;
    return 3;
  }

  void mutate(VoidCallback fn) {
    setState(fn);
    widget.storage.save(state);
  }

  void snack(String text, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Envelope? get selectedEnvelope {
    for (final e in state.envelopes) {
      if (e.id == selectedEnvelopeId) return e;
    }
    return null;
  }

  Envelope? envelopeById(String idValue) {
    for (final e in state.envelopes) {
      if (e.id == idValue) return e;
    }
    return null;
  }

  Future<DateTime?> pickDate(DateTime initial, {DateTime? first}) {
    return showDatePicker(
      context: context,
      locale: const Locale('es', 'AR'),
      initialDate: initial,
      firstDate: first ?? dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
  }

  Future<void> editIncome({bool onboarding = false}) async {
    final salary = TextEditingController(text: state.salary > 0 ? state.salary.toStringAsFixed(0) : '');
    final hourly = TextEditingController(text: state.hourlyIncome > 0 ? state.hourlyIncome.toStringAsFixed(0) : '');
    var payday = state.nextPayday ?? dateOnly(DateTime.now()).add(const Duration(days: 30));
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: !onboarding,
      builder: (context) => StatefulBuilder(
        builder: (context, local) => AlertDialog(
          title: const Text('Ingresos y fecha de cobro'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: salary,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Sueldo mensual actual'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hourly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cuánto ganás por hora'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  title: const Text('Próxima fecha de cobro'),
                  subtitle: Text(dateText(payday)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final d = await pickDate(payday, first: dateOnly(DateTime.now()).add(const Duration(days: 1)));
                    if (d != null) local(() => payday = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (!onboarding)
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final s = parseMoney(salary.text);
    final h = parseMoney(hourly.text);
    if (s <= 0 || h <= 0) {
      snack('Ingresá un sueldo y un valor por hora válidos.');
      return;
    }
    mutate(() {
      state.salary = s;
      state.hourlyIncome = h;
      state.nextPayday = dateOnly(payday);
    });
    if (onboarding) setState(() => onboardingStep = 1);
  }

  Future<void> createGoal() async {
    final name = TextEditingController();
    final target = TextEditingController();
    final previous = TextEditingController(text: '0');
    final reserved = TextEditingController(text: '0');
    var deadline = DateTime.now().add(const Duration(days: 180));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, local) => AlertDialog(
          title: const Text('Crear meta de ahorro'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre de la meta')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: target,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto objetivo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: previous,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ahorro previo',
                      helperText: 'Llena la barra, pero no se resta del sueldo.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reserved,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ahorro reservado de este sueldo',
                      helperText: 'Se resta del sueldo y entra a la meta ahora.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    title: const Text('Fecha límite'),
                    subtitle: Text(dateText(deadline)),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final d = await pickDate(deadline);
                      if (d != null) local(() => deadline = d);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final n = name.text.trim();
    final t = parseMoney(target.text);
    final p = parseMoney(previous.text);
    final r = parseMoney(reserved.text);
    if (n.isEmpty || t <= 0 || p < 0 || r < 0) {
      snack('Revisá los datos de la meta.');
      return;
    }
    if (state.reservedSavings + r > state.salary) {
      snack('El ahorro reservado supera el sueldo disponible.');
      return;
    }
    mutate(() {
      for (final g in state.goals) {
        g.active = false;
      }
      state.goals.add(
        Goal(
          name: n,
          target: t,
          saved: p + r,
          previousSavings: p,
          reservedThisMonth: r,
          deadline: dateOnly(deadline),
          active: true,
        ),
      );
    });
  }

  Future<void> editGoal(Goal goal) async {
    final name = TextEditingController(text: goal.name);
    final target = TextEditingController(text: goal.target.toStringAsFixed(0));
    final previous = TextEditingController(text: goal.previousSavings.toStringAsFixed(0));
    final reserved = TextEditingController(text: goal.reservedThisMonth.toStringAsFixed(0));
    var deadline = goal.deadline;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, local) => AlertDialog(
          title: const Text('Editar meta'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 10),
                  TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto objetivo')),
                  const SizedBox(height: 10),
                  TextField(controller: previous, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ahorro previo')),
                  const SizedBox(height: 10),
                  TextField(controller: reserved, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ahorro reservado este mes')),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    title: const Text('Fecha límite'),
                    subtitle: Text(dateText(deadline)),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final d = await pickDate(deadline);
                      if (d != null) local(() => deadline = d);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      mutate(() {
        state.goals.removeWhere((g) => g.id == goal.id);
        if (state.goals.isNotEmpty && !state.goals.any((g) => g.active)) state.goals.first.active = true;
      });
      return;
    }
    if (action != 'save') return;
    final n = name.text.trim();
    final t = parseMoney(target.text);
    final p = parseMoney(previous.text);
    final r = parseMoney(reserved.text);
    if (n.isEmpty || t <= 0 || p < 0 || r < 0) {
      snack('Revisá los datos.');
      return;
    }
    final others = state.reservedSavings - goal.reservedThisMonth;
    if (others + r > state.salary) {
      snack('El ahorro reservado total supera el sueldo.');
      return;
    }
    final deltaPrevious = p - goal.previousSavings;
    final deltaReserved = r - goal.reservedThisMonth;
    mutate(() {
      goal.name = n;
      goal.target = t;
      goal.saved = max(0, goal.saved + deltaPrevious + deltaReserved);
      goal.previousSavings = p;
      goal.reservedThisMonth = r;
      goal.deadline = dateOnly(deadline);
    });
  }

  Future<void> createFixed() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final installments = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programar gasto fijo'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto mensual / cuota')),
              const SizedBox(height: 10),
              TextField(controller: installments, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad de cuotas / meses restantes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Programar')),
        ],
      ),
    );
    if (ok != true) return;
    final n = name.text.trim();
    final a = parseMoney(amount.text);
    final q = int.tryParse(installments.text.trim()) ?? 0;
    if (n.isEmpty || a <= 0 || q <= 0) {
      snack('Revisá los datos del gasto fijo.');
      return;
    }
    mutate(() => state.fixedExpenses.add(FixedExpense(name: n, monthlyAmount: a, remainingInstallments: q)));
  }

  Future<void> editFixed(FixedExpense fixed) async {
    final name = TextEditingController(text: fixed.name);
    final amount = TextEditingController(text: fixed.monthlyAmount.toStringAsFixed(0));
    final installments = TextEditingController(text: fixed.remainingInstallments.toString());
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar gasto fijo'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto mensual / cuota')),
              const SizedBox(height: 10),
              TextField(controller: installments, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cuotas / meses restantes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'delete'), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Guardar')),
        ],
      ),
    );
    if (action == 'delete') {
      mutate(() => state.fixedExpenses.removeWhere((g) => g.id == fixed.id));
      return;
    }
    if (action != 'save') return;
    final n = name.text.trim();
    final a = parseMoney(amount.text);
    final q = int.tryParse(installments.text.trim()) ?? 0;
    if (n.isEmpty || a <= 0 || q <= 0) {
      snack('Revisá los datos.');
      return;
    }
    mutate(() {
      fixed.name = n;
      fixed.monthlyAmount = a;
      fixed.remainingInstallments = q;
    });
  }

  bool duplicateEnvelope(String name, {String? ignoreId}) {
    final n = name.trim().toLowerCase();
    return state.envelopes.any((e) => e.id != ignoreId && e.name.trim().toLowerCase() == n);
  }

  Future<void> configureEnvelope({Envelope? envelope}) async {
    final name = TextEditingController(text: envelope?.name ?? '');
    final emoji = TextEditingController(text: envelope?.emoji ?? '🍕');
    final amount = TextEditingController(text: envelope == null ? '' : envelope.initialAmount.toStringAsFixed(0));
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(envelope == null ? 'Crear sobre' : 'Configurar sobre'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto asignado en pesos')),
              const SizedBox(height: 10),
              TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji')),
            ],
          ),
        ),
        actions: [
          if (envelope != null)
            TextButton(onPressed: () => Navigator.pop(context, 'delete'), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Guardar')),
        ],
      ),
    );
    if (action == 'delete' && envelope != null) {
      deleteEnvelope(envelope);
      return;
    }
    if (action != 'save') return;
    final n = name.text.trim();
    final em = emoji.text.trim().isEmpty ? '🍕' : emoji.text.trim();
    final a = parseMoney(amount.text);
    if (n.isEmpty || a < 0) {
      snack('Completá un nombre y un monto válido.');
      return;
    }
    if (duplicateEnvelope(n, ignoreId: envelope?.id)) {
      snack('Este sobre ya existe, probá editarlo.');
      return;
    }
    final others = state.envelopesAssigned - (envelope?.initialAmount ?? 0);
    if (others + a > max(0, state.freeFundInitial) + 0.01) {
      snack('La suma de sobres no puede superar ${money(max(0, state.freeFundInitial))}.');
      return;
    }
    mutate(() {
      if (envelope != null) {
        envelope.name = n;
        envelope.emoji = em;
        envelope.initialAmount = a;
        envelope.usedAmount = min(envelope.usedAmount, a);
      } else {
        final colors = [0xFF26A69A, 0xFFFFCA28, 0xFFEC407A, 0xFF7E57C2, 0xFF5C6BC0];
        state.envelopes.add(Envelope(name: n, emoji: em, initialAmount: a, colorValue: colors[state.envelopes.length % colors.length]));
      }
    });
  }

  void deleteEnvelope(Envelope e) {
    mutate(() {
      state.envelopes.removeWhere((x) => x.id == e.id);
      if (selectedEnvelopeId == e.id) selectedEnvelopeId = null;
    });
  }

  Future<void> registerExpense() async {
    final envelope = selectedEnvelope;
    if (envelope == null) {
      snack('Elegí primero un sobre.');
      return;
    }
    final amount = TextEditingController();
    final detail = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gasto en ${envelope.emoji} ${envelope.name}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Disponible: ${money(envelope.remaining)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto')),
              const SizedBox(height: 10),
              TextField(controller: detail, decoration: const InputDecoration(labelText: 'Detalle')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar')),
        ],
      ),
    );
    if (ok != true) return;
    final a = parseMoney(amount.text);
    if (a <= 0 || a > envelope.remaining) {
      snack('El monto debe estar dentro del saldo del sobre.');
      return;
    }
    final before = envelope.usage;
    mutate(() {
      envelope.usedAmount += a;
      state.history.insert(
        0,
        Movement(
          type: MovementType.expense,
          envelopeId: envelope.id,
          envelopeName: envelope.name,
          envelopeEmoji: envelope.emoji,
          amount: a,
          detail: detail.text.trim().isEmpty ? 'Gasto' : detail.text.trim(),
        ),
      );
    });
    thresholdAlert(envelope, before);
  }

  void thresholdAlert(Envelope e, double before) {
    final now = e.usage;
    if (now >= 0.85 && before < 0.85) {
      snack('Zona de Riesgo: consumiste ${(now * 100).round()}% de ${e.name}.', color: Colors.red);
    } else if (now >= 0.50 && before < 0.50) {
      snack('Advertencia: ya consumiste ${(now * 100).round()}% de ${e.name}.', color: Colors.orange);
    }
  }

  Future<void> temptation() async {
    if (state.goals.isEmpty || state.envelopes.isEmpty) {
      snack('Necesitás al menos una meta y un sobre.');
      return;
    }
    final amount = TextEditingController();
    String? envelopeId = selectedEnvelopeId ?? state.envelopes.first.id;
    String? goalId = state.activeGoal?.id ?? state.goals.first.id;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, local) {
          final a = parseMoney(amount.text);
          final hours = state.hourlyIncome > 0 ? a / state.hourlyIncome : 0;
          return AlertDialog(
            title: const Text('🛡️ Botón de la Tentación'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '¿Cuánto sale?'),
                    onChanged: (_) => local(() {}),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: envelopeId,
                    decoration: const InputDecoration(labelText: '¿De qué sobre saldría?'),
                    items: state.envelopes
                        .map((e) => DropdownMenuItem(value: e.id, child: Text('${e.emoji} ${e.name} · ${money(e.remaining)}')))
                        .toList(),
                    onChanged: (v) => local(() => envelopeId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: goalId,
                    decoration: const InputDecoration(labelText: 'Meta que recibirá el dinero'),
                    items: state.goals.map((g) => DropdownMenuItem(value: g.id, child: Text('🎯 ${g.name}'))).toList(),
                    onChanged: (v) => local(() => goalId = v),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      a <= 0
                          ? 'Ingresá un monto para medir el esfuerzo.'
                          : 'Evitar este gasto equivale a ahorrar ${hours.toStringAsFixed(1)} horas de tu esfuerzo laboral. ¿Qué elegís?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Lo compro igual')),
              FilledButton.icon(
                onPressed: a > 0 && envelopeId != null && goalId != null ? () => Navigator.pop(context, a) : null,
                icon: const Icon(Icons.savings_outlined),
                label: const Text('¡Prefiero Ahorrarlo!'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || result <= 0) return;
    final envelope = state.envelopes.firstWhere((e) => e.id == envelopeId);
    final goal = state.goals.firstWhere((g) => g.id == goalId);
    if (result > envelope.remaining) {
      snack('Ese sobre no tiene saldo suficiente.');
      return;
    }
    final before = envelope.usage;
    final support = supportMessages[Random().nextInt(supportMessages.length)];
    mutate(() {
      envelope.usedAmount += result;
      goal.saved += result;
      for (final g in state.goals) {
        g.active = g.id == goal.id;
      }
      state.history.insert(
        0,
        Movement(
          type: MovementType.goalTransfer,
          envelopeId: envelope.id,
          envelopeName: envelope.name,
          envelopeEmoji: envelope.emoji,
          amount: result,
          detail: 'Reemplazado por mi Meta: Se transfirieron ${money(result)} de ${envelope.name} a ${goal.name}',
          goalId: goal.id,
          goalName: goal.name,
          support: support,
        ),
      );
    });
    thresholdAlert(envelope, before);
    snack('Transferencia realizada a ${goal.name}.', color: Colors.green);
  }

  Future<void> resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar datos'),
        content: const Text('Se borrará toda la información local y volverá el onboarding.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.storage.clear();
    setState(() {
      state = AppState.initial();
      selectedEnvelopeId = null;
      onboardingStep = 0;
    });
    widget.storage.save(state);
  }

  void googleDemo() {
    mutate(() => state.googleDemoLinked = true);
    snack('Simulación visual activada. Tus datos reales siguen guardándose localmente en este navegador.');
  }

  @override
  Widget build(BuildContext context) {
    return state.onboardingDone ? dashboard() : onboarding();
  }

  Widget onboarding() {
    return Scaffold(
      appBar: AppBar(title: const Text('Pizza Budget · Configuración inicial')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Stepper(
                currentStep: onboardingStep.clamp(0, 3),
                controlsBuilder: (_, __) => const SizedBox.shrink(),
                steps: [
                  Step(
                    title: const Text('Ingresos y fecha de cobro'),
                    state: onboardingStep > 0 ? StepState.complete : StepState.indexed,
                    content: onboardingStep == 0
                        ? FilledButton.icon(onPressed: () => editIncome(onboarding: true), icon: const Icon(Icons.payments_outlined), label: const Text('Cargar ingresos y fecha'))
                        : Text('${money(state.salary)} · cobro ${state.nextPayday == null ? '-' : dateText(state.nextPayday!)}'),
                  ),
                  Step(
                    title: const Text('Metas de ahorro vinculadas'),
                    isActive: onboardingStep >= 1,
                    state: onboardingStep > 1 ? StepState.complete : StepState.indexed,
                    content: onboardingGoals(),
                  ),
                  Step(
                    title: const Text('Gastos fijos programados'),
                    isActive: onboardingStep >= 2,
                    state: onboardingStep > 2 ? StepState.complete : StepState.indexed,
                    content: onboardingFixed(),
                  ),
                  Step(
                    title: const Text('Repartir dinero libre en sobres'),
                    isActive: onboardingStep >= 3,
                    content: onboardingEnvelopes(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget onboardingGoals() {
    if (onboardingStep < 1) return const Text('Completá el paso anterior.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...state.goals.map((g) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('🎯 ${g.name}'),
              subtitle: Text('Previo ${money(g.previousSavings)} · reservado ${money(g.reservedThisMonth)}'),
              trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editGoal(g)),
            )),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(onPressed: createGoal, icon: const Icon(Icons.add), label: const Text('Agregar meta')),
            FilledButton(onPressed: state.goals.isEmpty ? null : () => setState(() => onboardingStep = 2), child: const Text('Continuar')),
          ],
        ),
      ],
    );
  }

  Widget onboardingFixed() {
    if (onboardingStep < 2) return const Text('Completá los pasos anteriores.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...state.fixedExpenses.map((g) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(g.name),
              subtitle: Text('${money(g.monthlyAmount)} × ${g.remainingInstallments} = ${money(g.committedAmount)}'),
              trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editFixed(g)),
            )),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(onPressed: createFixed, icon: const Icon(Icons.add), label: const Text('Agregar gasto fijo')),
            FilledButton(
              onPressed: () {
                if (state.freeFundInitial < 0) {
                  snack('Ahorro y gastos fijos superan el sueldo. Ajustalos antes de continuar.');
                  return;
                }
                setState(() => onboardingStep = 3);
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget onboardingEnvelopes() {
    if (onboardingStep < 3) return const Text('Completá los pasos anteriores.');
    final free = max(0, state.freeFundInitial);
    final diff = free - state.envelopesAssigned;
    final balanced = diff.abs() <= 0.01;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        flowCard(),
        const SizedBox(height: 12),
        Text('Distribuí exactamente ${money(free.toDouble())}.', style: const TextStyle(fontWeight: FontWeight.bold)),
        ...state.envelopes.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(e.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(e.name),
              subtitle: Text(money(e.initialAmount)),
              trailing: Wrap(
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => configureEnvelope(envelope: e)),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => deleteEnvelope(e)),
                ],
              ),
            )),
        TextButton.icon(onPressed: configureEnvelope, icon: const Icon(Icons.add), label: const Text('Nuevo sobre')),
        banner(
          balanced
              ? '¡Perfecto! Distribuiste todo el dinero libre.'
              : diff > 0
                  ? 'Todavía faltan distribuir ${money(diff)}.'
                  : 'Te excediste por ${money(diff.abs())}.',
          balanced ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: balanced && state.envelopes.isNotEmpty ? () => mutate(() => state.onboardingDone = true) : null,
          icon: const Icon(Icons.rocket_launch_outlined),
          label: const Text('Entrar a Pizza Budget'),
        ),
      ],
    );
  }

  Widget dashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pizza Budget 🍕'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: googleDemo,
              icon: Icon(state.googleDemoLinked ? Icons.cloud_done_outlined : Icons.cloud_outlined, size: 18),
              label: Text(
                state.googleDemoLinked
                    ? 'Cambios guardados en tu Gmail: ${state.demoEmail} · DEMO'
                    : 'Sincronizar con Google Cuenta',
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'income') editIncome();
              if (v == 'reset') resetAll();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'income', child: Text('Editar ingresos y fecha')),
              PopupMenuItem(value: 'reset', child: Text('Reiniciar todos los datos')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: temptation,
        icon: const Icon(Icons.shield_outlined),
        label: const Text('Tentación'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, constraints) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  flowCard(),
                  const SizedBox(height: 14),
                  dailyCard(),
                  const SizedBox(height: 14),
                  pizzaCard(),
                  const SizedBox(height: 14),
                  envelopeActions(),
                  const SizedBox(height: 14),
                  goalsCard(),
                  const SizedBox(height: 14),
                  fixedCard(),
                  const SizedBox(height: 14),
                  historyCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget flowCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          children: [
            datum('Sueldo total', money(state.salary), Icons.payments_outlined),
            datum('Ahorro mensual', '-${money(state.reservedSavings)}', Icons.savings_outlined),
            datum('Gastos fijos', '-${money(state.fixedCommitted)}', Icons.receipt_long_outlined),
            datum('Fondo libre inicial', money(state.freeFundInitial), Icons.account_balance_wallet_outlined, strong: true),
          ],
        ),
      ),
    );
  }

  Widget datum(String title, String value, IconData icon, {bool strong = false}) {
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Icon(icon, color: strong ? Colors.deepOrange : null),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12)),
                Text(value, style: TextStyle(fontSize: strong ? 18 : 15, fontWeight: FontWeight.bold, color: strong ? Colors.deepOrange : null)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget dailyCard() {
    final d = state.daysToPayday;
    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            Text('Tu presupuesto diario ideal es de ${money(state.dailyBudget)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(state.nextPayday == null ? 'Sin fecha de cobro' : 'Faltan $d día${d == 1 ? '' : 's'} hasta el ${dateText(state.nextPayday!)}'),
            Text('Dinero libre disponible hoy: ${money(state.freeFundNow)}'),
          ],
        ),
      ),
    );
  }

  Widget pizzaCard() {
    const size = Size(320, 320);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Tus sobres en pesos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final e = envelopeAt(details.localPosition, size, state.envelopes);
                if (e != null) setState(() => selectedEnvelopeId = e.id);
              },
              child: CustomPaint(size: size, painter: PizzaPainter(envelopes: state.envelopes, selectedId: selectedEnvelopeId)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ...state.envelopes.map(envelopeChip),
                ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Nuevo sobre'), onPressed: configureEnvelope),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget envelopeChip(Envelope e) {
    final selected = e.id == selectedEnvelopeId;
    final risk = e.usage >= 0.85;
    final warning = e.usage >= 0.50;
    final border = risk
        ? Colors.red
        : warning
            ? Colors.orange
            : selected
                ? Colors.black
                : Colors.transparent;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: border, width: border == Colors.transparent ? 1 : 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => selectedEnvelopeId = e.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
              child: Text('${e.emoji} ${e.name} · ${money(e.remaining)}', style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w600)),
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Editar', icon: const Icon(Icons.edit_outlined, size: 17), onPressed: () => configureEnvelope(envelope: e)),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline, size: 17), onPressed: () => deleteEnvelope(e)),
        ],
      ),
    );
  }

  Widget envelopeActions() {
    final e = selectedEnvelope;
    return Card(
      elevation: 0,
      color: Colors.orange.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: e == null
            ? const Text('Seleccioná una porción de la pizza para registrar gastos.', style: TextStyle(fontWeight: FontWeight.w600))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrando en: ${e.emoji} ${e.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Asignado ${money(e.initialAmount)} · usado ${money(e.usedAmount)} · queda ${money(e.remaining)}'),
                  const SizedBox(height: 10),
                  usageBanner(e),
                  const SizedBox(height: 10),
                  FilledButton.icon(onPressed: registerExpense, icon: const Icon(Icons.remove_circle_outline), label: const Text('Registrar gasto')),
                ],
              ),
      ),
    );
  }

  Widget usageBanner(Envelope e) {
    if (e.usage >= 0.85) return banner('Zona de Riesgo: consumiste ${(e.usage * 100).round()}% de este sobre.', Colors.red);
    if (e.usage >= 0.50) return banner('Advertencia: ya consumiste ${(e.usage * 100).round()}% de este sobre.', Colors.orange);
    return banner('Consumo controlado: ${(e.usage * 100).round()}% utilizado.', Colors.green);
  }

  Widget banner(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.35))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget goalsCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('🎯 Metas de ahorro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                FilledButton.tonalIcon(onPressed: createGoal, icon: const Icon(Icons.add), label: const Text('Nueva')),
              ],
            ),
            const SizedBox(height: 10),
            if (state.goals.isEmpty)
              const Text('Todavía no hay metas.')
            else
              ...state.goals.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => mutate(() {
                      for (final x in state.goals) {
                        x.active = x.id == g.id;
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: g.active ? Colors.deepOrange : Colors.grey.shade300, width: g.active ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${g.active ? '⭐ ' : ''}${g.name}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editGoal(g)),
                            ],
                          ),
                          LinearProgressIndicator(value: g.progress, minHeight: 12),
                          const SizedBox(height: 6),
                          Text('${money(g.saved)} / ${money(g.target)} · previo ${money(g.previousSavings)} · reservado ${money(g.reservedThisMonth)}'),
                          Text('Fecha límite: ${dateText(g.deadline)}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget fixedCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('🏠 Gastos fijos programados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                FilledButton.tonalIcon(onPressed: createFixed, icon: const Icon(Icons.add), label: const Text('Agregar')),
              ],
            ),
            ...state.fixedExpenses.map((g) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(g.name),
                  subtitle: Text('${money(g.monthlyAmount)} × ${g.remainingInstallments} = ${money(g.committedAmount)}'),
                  trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editFixed(g)),
                )),
          ],
        ),
      ),
    );
  }

  Widget historyCard() {
    final grouped = <DateTime, List<Movement>>{};
    for (final m in state.history) {
      final d = dateOnly(m.at);
      grouped.putIfAbsent(d, () => []).add(m);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🧾 Historial por días', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (days.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 10), child: Text('Todavía no hay movimientos.'))
            else
              ...days.map(
                (d) => ExpansionTile(
                  initiallyExpanded: sameDay(d, DateTime.now()),
                  title: Text(dateText(d)),
                  subtitle: Text('${grouped[d]!.length} movimiento${grouped[d]!.length == 1 ? '' : 's'}'),
                  children: grouped[d]!.map((m) {
                    final current = envelopeById(m.envelopeId);
                    final emoji = current?.emoji ?? m.envelopeEmoji;
                    final time = '${m.at.hour.toString().padLeft(2, '0')}:${m.at.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(m.type == MovementType.goalTransfer ? m.detail : '${m.envelopeName} · ${m.detail}'),
                      subtitle: Text(m.support == null ? time : '$time · ${m.support}'),
                      trailing: Text(
                        m.type == MovementType.goalTransfer ? '→ ${money(m.amount)}' : '-${money(m.amount)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: m.type == MovementType.goalTransfer ? Colors.green : Colors.red),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Envelope? envelopeAt(Offset position, Size size, List<Envelope> envelopes) {
  if (envelopes.isEmpty) return null;
  final total = envelopes.fold<double>(0, (s, e) => s + max(0, e.initialAmount));
  if (total <= 0) return null;
  final center = Offset(size.width / 2, size.height / 2);
  final dx = position.dx - center.dx;
  final dy = position.dy - center.dy;
  final radius = min(size.width, size.height) / 2;
  if (sqrt(dx * dx + dy * dy) > radius) return null;
  var angle = atan2(dy, dx) + pi / 2;
  while (angle < 0) angle += 2 * pi;
  while (angle >= 2 * pi) angle -= 2 * pi;
  var acc = 0.0;
  for (final e in envelopes) {
    final span = 2 * pi * (max(0, e.initialAmount) / total);
    if (angle >= acc && angle < acc + span) return e;
    acc += span;
  }
  return envelopes.last;
}

class PizzaPainter extends CustomPainter {
  final List<Envelope> envelopes;
  final String? selectedId;

  PizzaPainter({required this.envelopes, required this.selectedId});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final total = envelopes.fold<double>(0, (s, e) => s + max(0, e.initialAmount));
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFE0B2));
    if (total <= 0) {
      final tp = TextPainter(text: const TextSpan(text: '🍕', style: TextStyle(fontSize: 60)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      return;
    }
    var start = -pi / 2;
    for (final e in envelopes) {
      final sweep = 2 * pi * (max(0, e.initialAmount) / total);
      final remainingRatio = e.initialAmount <= 0 ? 0.0 : (e.remaining / e.initialAmount).clamp(0.0, 1.0);
      final currentRadius = radius * (0.22 + 0.78 * sqrt(remainingRatio));
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: currentRadius), start, sweep, false)
        ..close();
      canvas.drawPath(path, Paint()..color = e.color);
      canvas.drawPath(
        path,
        Paint()
          ..color = e.id == selectedId ? Colors.black87 : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = e.id == selectedId ? 5 : 3,
      );
      if (remainingRatio < 0.999) {
        final outline = Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(Rect.fromCircle(center: center, radius: radius), start, sweep, false)
          ..close();
        canvas.drawPath(
          outline,
          Paint()
            ..color = Colors.grey.withOpacity(0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      final mid = start + sweep / 2;
      final point = Offset(center.dx + cos(mid) * currentRadius * 0.62, center.dy + sin(mid) * currentRadius * 0.62);
      if (sweep > 0.25 && currentRadius > 55) {
        final tp = TextPainter(text: TextSpan(text: e.emoji, style: const TextStyle(fontSize: 22)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(point.dx - tp.width / 2, point.dy - tp.height / 2));
      }
      start += sweep;
    }
    canvas.drawCircle(center, radius * 0.10, Paint()..color = const Color(0xFFFFF3E0));
  }

  @override
  bool shouldRepaint(covariant PizzaPainter oldDelegate) => true;
}
