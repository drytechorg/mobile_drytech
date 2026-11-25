import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'drytech_api.dart';

void main() => runApp(const DryTechApp());

class DryTechAccount {
  final String name;
  final String username;
  final String email;
  final String password;

  const DryTechAccount({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
  });
}

final List<DryTechAccount> _accounts = [];
final List<DryingSession> dryingSessions = [];
final List<AppNotification> appNotifications = [];
final Set<String> savedFoodNames = {};
final List<DryTechAccount> collaborators = [];
DryTechAccount? activeAccount;
DryingSession? activeDryingSession;
bool appNotificationsEnabled = true;

class AppNotification {
  final String title;
  final String message;
  final DateTime createdAt;
  final DryingSession? session;
  bool isRead;

  AppNotification({
    required this.title,
    required this.message,
    this.session,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

void addAppNotification(String title, String message,
    {DryingSession? session}) {
  if (!appNotificationsEnabled) return;
  appNotifications.insert(
      0,
      AppNotification(
        title: title,
        message: message,
        session: session,
      ));
}

String formatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} às $hour:$minute';
}

const List<List<String>> foodCatalog = [
  ['🍎', 'Maçãs', 'Frutas', '55', '10'],
  ['🌿', 'Alecrim', 'Ervas', '45', '4'],
  ['🥕', 'Cenouras', 'Vegetais', '60', '8'],
  ['🍵', 'Chá', 'Ervas', '50', '3'],
  ['🍌', 'Bananas', 'Frutas', '55', '8'],
  ['🍓', 'Morangos', 'Frutas', '50', '7'],
  ['🍅', 'Tomates', 'Vegetais', '55', '9'],
  ['🌶️', 'Pimentas', 'Vegetais', '50', '6'],
];

String get signedInName => activeAccount?.name ?? 'Usuário';
String get signedInFirstName => signedInName.trim().split(RegExp(r'\s+')).first;
String get signedInHandle =>
    activeAccount == null ? '@usuario' : '@${activeAccount!.username}';

void showMessage(BuildContext context, String message) {
  // SnackBar fixa não disputa espaço com a NavigationBar em janelas pequenas.
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        content: Text(message),
      ),
    );
}

String formatClock(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatDurationLabel(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h e $minutes min';
}

String formatHoursValue(double hours) {
  final totalMinutes = (hours * 60).round();
  return formatDurationLabel(totalMinutes * 60);
}

const orange = Color(0xFFFF650A);
const orangeLight = Color(0xFFFF8A50);
const ink = Color(0xFF252525);
const muted = Color(0xFF777777);
const pageBg = Color(0xFFF6F7F9);
const lineColor = Color(0xFFE5E5E5);

class DryTechApp extends StatelessWidget {
  const DryTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DryTech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(seedColor: orange, primary: orange),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.fixed,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: lineColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: lineColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: orange, width: 1.5),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

void go(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

void replace(BuildContext context, Widget page) {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: orange,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: icon == null
          ? FilledButton(
              style: buttonStyle,
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : FilledButton.icon(
              style: buttonStyle,
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

class AppField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboard;

  const AppField(
    this.label,
    this.hint, {
    super.key,
    this.obscure = false,
    this.controller,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          textInputAction: TextInputAction.next,
          autocorrect: !obscure,
          enableSuggestions: !obscure,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class AppPage extends StatelessWidget {
  final String title;
  final Widget child;
  final int selected;
  final bool showBack;

  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.selected = 0,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth > 760 ? 760.0 : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: child,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE8DD),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: selected,
        onDestinationSelected: (i) {
          final pages = [
            const HomeScreen(),
            const SavedFoodsScreen(),
            const SelectFoodScreen(),
            const NotificationsScreen(),
            const ProfileScreen(),
          ];
          replace(context, pages[i]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            label: 'Salvos',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Secar',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            label: 'Avisos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDEFF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 22,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class InfoRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final Color trailingColor;
  final VoidCallback? onTap;

  const InfoRow(
    this.title,
    this.subtitle, {
    super.key,
    this.trailing,
    this.trailingColor = Colors.green,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: trailingColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.2,
        ),
      ),
    );

Widget gap([double height = 14]) => SizedBox(height: height);

// Temporizador local do aplicativo. Usa uma hora final, em vez de apenas
// diminuir um contador fixo, para compensar atrasos do navegador em segundo plano.
class DryingSession extends ChangeNotifier {
  final String food;
  final String emoji;
  final double temperature;
  final int totalSeconds;
  final String note;
  final DateTime startedAt;

  int _remainingSeconds;
  DateTime? _endsAt;
  Timer? _ticker;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _isCancelled = false;
  bool _finishNotificationSent = false;

  DryingSession({
    required this.food,
    required this.emoji,
    required this.temperature,
    required Duration duration,
    this.note = '',
  })  : totalSeconds = duration.inSeconds < 1 ? 1 : duration.inSeconds,
        _remainingSeconds = duration.inSeconds < 1 ? 1 : duration.inSeconds,
        startedAt = DateTime.now() {
    resume();
  }

  int get remainingSeconds => _remainingSeconds;
  bool get isPaused => _isPaused;
  bool get isCompleted => _isCompleted;
  bool get isCancelled => _isCancelled;
  bool get isFinished => _isCompleted || _isCancelled;
  bool get isRunning => !_isPaused && !isFinished;
  double get progress => totalSeconds == 0
      ? 1.0
      : (1 - _remainingSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();

  void _startTicker() {
    _endsAt = DateTime.now().add(Duration(seconds: _remainingSeconds));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    notifyListeners();
  }

  void _update() {
    if (_endsAt == null || !isRunning) return;
    final millisecondsLeft = _endsAt!.difference(DateTime.now()).inMilliseconds;
    _remainingSeconds =
        millisecondsLeft <= 0 ? 0 : (millisecondsLeft / 1000).ceil();
    if (_remainingSeconds == 0) {
      _isCompleted = true;
      _ticker?.cancel();
      _ticker = null;
      _endsAt = null;
      if (!_finishNotificationSent) {
        _finishNotificationSent = true;
        addAppNotification(
            'Ciclo concluído', '$food • ${formatDurationLabel(totalSeconds)}',
            session: this);
      }
    }
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _update();
    if (_isCompleted) return;
    _isPaused = true;
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    notifyListeners();
  }

  void resume() {
    if (isFinished || (!_isPaused && _ticker != null)) return;
    _isPaused = false;
    _startTicker();
  }

  void cancel() {
    if (isFinished) return;
    _isCancelled = true;
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    addAppNotification('Ciclo encerrado', '$food • contagem interrompida',
        session: this);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) replace(context, const OnboardingScreen());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [orange, orangeLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_laundry_service_outlined,
              size: 76,
              color: Colors.white,
            ),
            SizedBox(height: 14),
            Text(
              'DryTech',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              'SECAGEM INTELIGENTE',
              style: TextStyle(
                letterSpacing: 2,
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [orange, orangeLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.local_laundry_service_outlined,
              size: 72,
              color: Colors.white,
            ),
            gap(28),
            const Text(
              'Sua secagem,\nmais inteligente.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            gap(12),
            const Text(
              'Acompanhe seus alimentos, personalize ciclos e compartilhe sua DryTech.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            ),
            gap(38),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: orange,
                ),
                onPressed: () => go(context, const LoginScreen()),
                child: const Text('Começar'),
              ),
            ),
            TextButton(
              onPressed: () => go(context, const RegisterScreen()),
              child: const Text(
                'Criar uma conta',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController();
  final pass = TextEditingController();

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Text(
                      'DRY',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'TECH',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: orange,
                      ),
                    ),
                    gap(22),
                    const Text(
                      'Bem-vindo de volta!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Entre na sua conta para continuar.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              gap(38),
              AppField(
                'Nome de usuário ou e-mail',
                '@seuusuario ou e-mail',
                controller: user,
              ),
              gap(18),
              AppField(
                'Senha',
                'Digite sua senha',
                controller: pass,
                obscure: true,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const PasswordRecoveryDialog(),
                  ),
                  child: const Text('Esqueci minha senha'),
                ),
              ),
              gap(14),
              PrimaryButton(
                'Entrar',
                onPressed: () {
                  final identifier = user.text
                      .trim()
                      .replaceFirst(RegExp(r'^@'), '')
                      .toLowerCase();
                  if (identifier.isEmpty || pass.text.isEmpty) {
                    showMessage(context, 'Preencha usuário e senha.');
                    return;
                  }

                  DryTechAccount? account;
                  for (final item in _accounts) {
                    if (item.username.toLowerCase() == identifier ||
                        item.email.toLowerCase() == identifier) {
                      account = item;
                      break;
                    }
                  }

                  if (account == null) {
                    showMessage(context,
                        'Conta não encontrada. Crie uma conta primeiro.');
                  } else if (account.password != pass.text) {
                    showMessage(
                        context, 'Senha incorreta. Confira e tente novamente.');
                  } else {
                    activeAccount = account;
                    replace(context, const HomeScreen());
                  }
                },
              ),
              gap(24),
              Center(
                child: TextButton(
                  onPressed: () => go(context, const RegisterScreen()),
                  child: const Text(
                    'Ainda não tem conta? Criar conta',
                    style: TextStyle(
                      color: orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PasswordRecoveryDialog extends StatefulWidget {
  const PasswordRecoveryDialog({super.key});

  @override
  State<PasswordRecoveryDialog> createState() => _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<PasswordRecoveryDialog> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool showPasswordFields = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redefinir senha'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail cadastrado'),
            ),
            if (showPasswordFields) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirmar nova senha'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final email = emailController.text.trim().toLowerCase();
            final index = _accounts
                .indexWhere((account) => account.email.toLowerCase() == email);
            if (email.isEmpty || index < 0) {
              showMessage(
                  context, 'Não encontramos uma conta com esse e-mail.');
              return;
            }
            if (!showPasswordFields) {
              setState(() => showPasswordFields = true);
              return;
            }
            if (passwordController.text.length < 6) {
              showMessage(
                  context, 'A senha precisa ter pelo menos 6 caracteres.');
              return;
            }
            if (passwordController.text != confirmController.text) {
              showMessage(context, 'As senhas não coincidem.');
              return;
            }
            final oldAccount = _accounts[index];
            final updated = DryTechAccount(
              name: oldAccount.name,
              username: oldAccount.username,
              email: oldAccount.email,
              password: passwordController.text,
            );
            _accounts[index] = updated;
            if (identical(activeAccount, oldAccount)) activeAccount = updated;
            Navigator.pop(context);
            showMessage(context, 'Senha atualizada. Entre com a nova senha.');
          },
          child: Text(showPasswordFields ? 'Salvar senha' : 'Continuar'),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final handle = TextEditingController();
  final email = TextEditingController();
  final pwd = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [name, handle, email, pwd, confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Vamos começar!',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900, color: ink),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Crie seu perfil para personalizar o aplicativo.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
              gap(18),
              AppField('Nome completo', 'Como gostaria de ser chamado(a)?',
                  controller: name),
              gap(14),
              AppField('Nome de usuário', 'Escolha seu @usuário',
                  controller: handle),
              gap(14),
              AppField('E-mail', 'seuemail@email.com',
                  controller: email, keyboard: TextInputType.emailAddress),
              gap(14),
              AppField('Senha', 'Crie uma senha',
                  controller: pwd, obscure: true),
              gap(14),
              AppField('Confirmar senha', 'Digite novamente',
                  controller: confirm, obscure: true),
              gap(22),
              PrimaryButton(
                'Criar minha conta',
                onPressed: () {
                  final fullName =
                      name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                  final rawInput = handle.text.trim();
                  final username = rawInput
                      .replaceFirst(
                          RegExp(r'^DRYTECH-', caseSensitive: false), '')
                      .replaceFirst(RegExp(r'^@'), '')
                      .toLowerCase();
                  final mail = email.text.trim().toLowerCase();
                  final emailIsValid =
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(mail);
                  final usernameIsValid =
                      RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(username);

                  if ([fullName, username, mail, pwd.text, confirm.text]
                      .any((value) => value.trim().isEmpty)) {
                    showMessage(context, 'Preencha todos os campos.');
                  } else if (!emailIsValid) {
                    showMessage(context, 'Digite um e-mail válido.');
                  } else if (!usernameIsValid) {
                    showMessage(context,
                        'O usuário deve ter 3 a 20 caracteres: letras, números, ponto ou _.');
                  } else if (pwd.text.length < 6) {
                    showMessage(context,
                        'A senha precisa ter pelo menos 6 caracteres.');
                  } else if (pwd.text != confirm.text) {
                    showMessage(context, 'As senhas não coincidem.');
                  } else if (_accounts.any((account) =>
                      account.email.toLowerCase() == mail ||
                      account.username.toLowerCase() == username)) {
                    showMessage(context,
                        'Esse e-mail ou nome de usuário já está cadastrado.');
                  } else {
                    final account = DryTechAccount(
                      name: fullName,
                      username: username,
                      email: mail,
                      password: pwd.text,
                    );
                    _accounts.add(account);
                    activeAccount = account;
                    final firstName = fullName.split(' ').first;
                    showMessage(
                        context, 'Conta criada! Bem-vindo(a), $firstName.');
                    replace(context, const HomeScreen());
                  }
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Já tem conta? Fazer login',
                  style: TextStyle(color: orange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActiveDryingCard extends StatelessWidget {
  final DryingSession session;

  const ActiveDryingCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final status = session.isCompleted
            ? 'Ciclo concluído'
            : session.isCancelled
                ? 'Ciclo encerrado'
                : session.isPaused
                    ? 'Ciclo pausado'
                    : 'Em andamento';
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => go(context, DryingScreen(session: session)),
          child: Panel(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEE6),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text(session.emoji, style: const TextStyle(fontSize: 25)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.food,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(status,
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  session.isCompleted || session.isCancelled
                      ? '00:00:00'
                      : formatClock(session.remainingSeconds),
                  style: const TextStyle(
                    color: orange,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: muted),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recentSessions = dryingSessions.take(3).toList();
    return AppPage(
      title: 'DryTech',
      selected: 0,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Olá, $signedInFirstName!',
            style: const TextStyle(
                fontSize: 25, fontWeight: FontWeight.w900, color: ink),
          ),
          const Text(
            'Tudo pronto para planejar sua próxima secagem.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          gap(18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [orange, orangeLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22FF650A),
                    blurRadius: 20,
                    offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PAINEL DRYTECH',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 9),
                const Text('Pronto para começar',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text(
                    'Configure um ciclo e acompanhe a contagem pelo aplicativo.',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, height: 1.4)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.link_off_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                        child: Text('Secadora Laboratório',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const DeviceInfoDialog(),
                      ),
                      child: const Text('Saiba mais'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (activeDryingSession != null &&
              !activeDryingSession!.isCancelled) ...[
            section('Ciclo atual'),
            ActiveDryingCard(session: activeDryingSession!),
          ],
          section('Ciclo de secagem'),
          const BackendLiveCyclesPanel(),
          section('Acesso rápido'),
          Row(
            children: [
              Expanded(
                  child: _quick(
                      context,
                      'Nova secagem',
                      Icons.add_circle_outline_rounded,
                      const SelectFoodScreen())),
              const SizedBox(width: 12),
              Expanded(
                  child: _quick(context, 'Histórico', Icons.history_rounded,
                      const HistoryScreen())),
            ],
          ),
          section('Atividade recente'),
          if (recentSessions.isEmpty)
            const Panel(
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, color: muted, size: 25),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text('Nenhum ciclo iniciado ainda.',
                          style: TextStyle(color: muted, fontSize: 13))),
                ],
              ),
            )
          else
            ...recentSessions.map((session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoRow(
                    '${session.emoji}  ${session.food}',
                    '${formatDateTime(session.startedAt)} • ${formatDurationLabel(session.totalSeconds)}',
                    trailing: session.isCompleted
                        ? 'Concluído'
                        : session.isCancelled
                            ? 'Encerrado'
                            : session.isPaused
                                ? 'Pausado'
                                : 'Ativo',
                    trailingColor: session.isCompleted ? Colors.green : orange,
                    onTap: () => go(context, DryingScreen(session: session)),
                  ),
                )),
          section('Compartilhamento'),
          PrimaryButton(
            'Adicionar amigo',
            icon: Icons.person_add_alt_1,
            onPressed: () => go(context, const AddFriendScreen()),
          ),
        ],
      ),
    );
  }
}

class BackendLiveCyclesPanel extends StatefulWidget {
  const BackendLiveCyclesPanel({super.key});

  @override
  State<BackendLiveCyclesPanel> createState() => _BackendLiveCyclesPanelState();
}

class _BackendLiveCyclesPanelState extends State<BackendLiveCyclesPanel> {
  final DryTechApi _api = DryTechApi();
  Timer? _poller;
  Timer? _clock;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _load());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _snapshot?['cycle'] is Map) setState(() {});
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    try {
      final data = await _api.getMockData();
      if (!mounted) return;
      setState(() {
        _snapshot = data;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    } finally {
      _busy = false;
    }
  }

  int _number(dynamic value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;

  int _elapsedSeconds(Map<String, dynamic> cycle) {
    final status = cycle['status']?.toString();
    if (status == 'PAUSED' ||
        status == 'COMPLETED' ||
        status == 'CANCELLED' ||
        status == 'ERROR') {
      return _number(cycle['durationSeconds']);
    }
    final started = DateTime.tryParse(cycle['startTime']?.toString() ?? '');
    if (started == null) return _number(cycle['durationSeconds']);
    return DateTime.now().difference(started).inSeconds.clamp(0, 86400).toInt();
  }

  String _statusLabel(String status) => switch (status) {
        'PREPARING' => 'Preparando',
        'DRYING' => 'Secando',
        'PAUSED' => 'Pausado',
        'COMPLETED' => 'Concluído',
        'CANCELLED' => 'Cancelado',
        'ERROR' => 'Com falha',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'DRYING' => const Color(0xFF16834A),
        'PAUSED' => const Color(0xFFB66A00),
        'COMPLETED' => const Color(0xFF2768C5),
        'ERROR' || 'CANCELLED' => Colors.redAccent,
        _ => orange,
      };

  Widget _metric(IconData icon, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: orange),
              const SizedBox(height: 7),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: ink)),
              Text(label, style: const TextStyle(fontSize: 10, color: muted)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading && _snapshot == null)
      return const Panel(child: LinearProgressIndicator(color: orange));
    if (_snapshot == null) {
      return Panel(
          child: Row(children: [
        const Icon(Icons.cloud_off_outlined, color: muted),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_error ?? 'Não foi possível carregar a secagem.',
                style: const TextStyle(color: muted, fontSize: 12))),
        IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: orange)),
      ]));
    }

    final device = _snapshot!['device'] is Map
        ? Map<String, dynamic>.from(_snapshot!['device'])
        : <String, dynamic>{};
    final rawCycle = _snapshot!['cycle'];
    if (rawCycle is! Map) {
      return Panel(
          child: Row(children: [
        const Icon(Icons.hourglass_empty_rounded, color: orange),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                '${device['name'] ?? 'Secadora'} · aguardando um ciclo do painel.',
                style: const TextStyle(color: muted, fontSize: 12))),
        IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: orange)),
      ]));
    }

    final cycle = Map<String, dynamic>.from(rawCycle);
    final status = cycle['status']?.toString() ?? 'PREPARING';
    final color = _statusColor(status);
    final total =
        _number(cycle['plannedDurationSeconds'] ?? cycle['durationSeconds']);
    final elapsed = _elapsedSeconds(cycle);
    final progress =
        total <= 0 ? 0.0 : (elapsed / total).clamp(0.0, 1.0).toDouble();
    final remaining = (total - elapsed).clamp(0, 86400).toInt();
return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.local_laundry_service_rounded, color: color)),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(device['name']?.toString() ?? 'Secadora Laboratório',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: ink)),
                  Text(cycle['foodName']?.toString() ?? 'Ciclo de secagem',
                      style: const TextStyle(color: muted, fontSize: 12)),
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99)),
                child: Text(_statusLabel(status).toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            const Text('Progresso da secagem',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
            const Spacer(),
            Text('${(progress * 100).round()}%',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                  value: status == 'COMPLETED' ? 1 : progress,
                  minHeight: 9,
                  color: color,
                  backgroundColor: const Color(0xFFEDEEF0))),
          const SizedBox(height: 7),
          Row(children: [
            Text('Decorrido ${formatDurationLabel(elapsed)}',
                style: const TextStyle(color: muted, fontSize: 10)),
            const Spacer(),
            Text(
                status == 'COMPLETED'
                    ? 'Concluído'
                    : 'Restam ${formatDurationLabel(remaining)}',
                style: const TextStyle(color: muted, fontSize: 10)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _metric(Icons.thermostat_rounded, 'Temperatura alvo',
                '${cycle['targetTemperature'] ?? cycle['maximumTemperature'] ?? '—'} °C'),
            const SizedBox(width: 8),
            _metric(Icons.monitor_weight_outlined, 'Peso inicial',
                '${cycle['initialWeight'] ?? '—'} kg'),
            const SizedBox(width: 8),
            _metric(
                Icons.timer_outlined, 'Duração', '${(total / 60).ceil()} min'),
          ]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Atualizar agora'),
            ),
          ),          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Última leitura: $_error',
                    style: const TextStyle(color: muted, fontSize: 10))),
        ],
      ),
    );
  }
}

Widget _quick(BuildContext context, String title, IconData icon, Widget page) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => go(context, page),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: orange, size: 28),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
  );
}

class DeviceInfoDialog extends StatelessWidget {
  const DeviceInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conexão com a secadora'),
      content: const Text(
          'A secadora não está conectada ao aplicativo. A contagem de tempo funciona, mas a temperatura é apenas o ajuste escolhido e não representa uma leitura do equipamento.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi')),
      ],
    );
  }
}

class SelectFoodScreen extends StatefulWidget {
  final String? initialFood;
  const SelectFoodScreen({super.key, this.initialFood});

  @override
  State<SelectFoodScreen> createState() => _SelectFoodScreenState();
}

class _SelectFoodScreenState extends State<SelectFoodScreen> {
  final searchController = TextEditingController();
  String search = '';

  @override
  void initState() {
    super.initState();
    search = widget.initialFood ?? '';
    searchController.text = search;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFoods = foodCatalog
        .where((food) =>
            food.join(' ').toLowerCase().contains(search.toLowerCase()))
        .toList();

    return AppPage(
      title: 'Nova secagem',
      selected: 2,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('O que você quer desidratar?',
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 21, color: ink)),
          const Text('Escolha um alimento para configurar o ciclo.',
              style: TextStyle(color: muted, fontSize: 13)),
          gap(18),
          TextField(
            controller: searchController,
            onChanged: (value) => setState(() => search = value.trim()),
            decoration: InputDecoration(
              hintText: 'Buscar alimento',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        setState(() => search = '');
                      },
                    ),
            ),
          ),
          section('Alimentos'),
          if (filteredFoods.isEmpty)
            const Panel(
                child: Text('Nenhum alimento encontrado. Tente outra busca.',
                    style: TextStyle(color: muted))),
          ...filteredFoods.map((food) {
            final isSaved = savedFoodNames.contains(food[1]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => go(context,
                          ConfigureDryingScreen(food: food[1], emoji: food[0])),
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E8),
                            borderRadius: BorderRadius.circular(15)),
                        child:
                            Text(food[0], style: const TextStyle(fontSize: 29)),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: InkWell(
                        onTap: () => go(
                            context,
                            ConfigureDryingScreen(
                                food: food[1], emoji: food[0])),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(food[1],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('${food[2]} • ${food[3]} °C sugeridos',
                                style: const TextStyle(
                                    color: muted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip:
                          isSaved ? 'Remover dos salvos' : 'Salvar alimento',
                      onPressed: () {
                        setState(() {
                          if (isSaved) {
                            savedFoodNames.remove(food[1]);
                          } else {
                            savedFoodNames.add(food[1]);
                          }
                        });
                        showMessage(
                            context,
                            isSaved
                                ? 'Alimento removido dos salvos.'
                                : 'Alimento salvo.');
                      },
                      icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: orange),
                    ),
                    IconButton(
                      tooltip: 'Configurar alimento',
                      onPressed: () => go(context,
                          ConfigureDryingScreen(food: food[1], emoji: food[0])),
                      icon:
                          const Icon(Icons.chevron_right_rounded, color: muted),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ConfigureDryingScreen extends StatefulWidget {
  final String food;
  final String emoji;

  const ConfigureDryingScreen({
    super.key,
    this.food = 'Maçãs',
    this.emoji = '🍎',
  });

  @override
  State<ConfigureDryingScreen> createState() => _ConfigureDryingScreenState();
}

class _ConfigureDryingScreenState extends State<ConfigureDryingScreen> {
  late double temp;
  late double hours;
  final noteController = TextEditingController();

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final preset = foodCatalog.firstWhere(
      (food) => food[1] == widget.food,
      orElse: () => foodCatalog.first,
    );
    temp = double.parse(preset[3]);
    hours = double.parse(preset[4]);
  }

  @override
  Widget build(BuildContext context) {
    final duration = Duration(minutes: (hours * 60).round());
    return AppPage(
      title: 'Configurar secagem',
      selected: 2,
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Prepare seu ciclo',
            style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: ink,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 5),
          const Text(
            'Ajuste a temperatura e o tempo desejados.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          gap(18),
          Panel(
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text(widget.emoji, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.food,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Alimento selecionado',
                          style: TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Colors.green),
              ],
            ),
          ),
          section('Temperatura desejada'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ajuste de temperatura',
                        style: TextStyle(color: muted, fontSize: 12)),
                    Text('${temp.round()} °C',
                        style: const TextStyle(
                            color: orange,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                Slider(
                  value: temp,
                  min: 35,
                  max: 60,
                  divisions: 25,
                  label: '${temp.round()} °C',
                  activeColor: orange,
                  onChanged: (value) => setState(() => temp = value),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('35 °C', style: TextStyle(color: muted, fontSize: 11)),
                    Text('60 °C', style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          section('Tempo do ciclo'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duração programada',
                        style: TextStyle(color: muted, fontSize: 12)),
                    Text(formatHoursValue(hours),
                        style: const TextStyle(
                            color: orange,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                Slider(
                  value: hours,
                  min: 0.25,
                  max: 24,
                  divisions: 95,
                  label: formatHoursValue(hours),
                  activeColor: orange,
                  onChanged: (value) => setState(() => hours = value),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('15 min',
                        style: TextStyle(color: muted, fontSize: 11)),
                    Text('24 h', style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          section('Observações'),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Adicione uma observação (opcional)',
              alignLabelWithHint: true,
            ),
          ),
          gap(22),
          PrimaryButton(
            'Iniciar contagem do ciclo',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              final currentSession = activeDryingSession;
              if (currentSession != null && !currentSession.isFinished) {
                showMessage(context,
                    'Já existe um ciclo ativo. Retome ou cancele esse ciclo antes de iniciar outro.');
                return;
              }
              final session = DryingSession(
                food: widget.food,
                emoji: widget.emoji,
                temperature: temp,
                duration: duration,
                note: noteController.text.trim(),
              );
              activeDryingSession = session;
              dryingSessions.insert(0, session);
              addAppNotification('Ciclo iniciado',
                  '${widget.food} • ${formatDurationLabel(duration.inSeconds)}',
                  session: session);
              go(context, DryingScreen(session: session));
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'A contagem é feita pelo aplicativo. Sem conexão com o equipamento, este ajuste não liga a secadora.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class DryingScreen extends StatelessWidget {
  final DryingSession session;

  const DryingScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final title = session.isCompleted
            ? 'Ciclo concluído'
            : session.isPaused
                ? 'Ciclo pausado'
                : 'Secagem em andamento';
        final status = session.isCompleted
            ? 'Concluído'
            : session.isCancelled
                ? 'Cancelado'
                : session.isPaused
                    ? 'Pausado'
                    : 'Em andamento';
        final timerColor = session.isCompleted ? Colors.green : orange;

        return AppPage(
          title: title,
          selected: 0,
          showBack: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text(
                '${session.emoji}  ${session.food}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: ink),
              ),
              gap(16),
              Panel(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                child: Column(
                  children: [
                    Text(
                      session.isCompleted
                          ? 'TEMPO FINALIZADO'
                          : 'TEMPO RESTANTE',
                      style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: session.progress,
                              strokeWidth: 11,
                              backgroundColor: const Color(0xFFFFE9DF),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(timerColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                session.isCompleted
                                    ? '00:00:00'
                                    : formatClock(session.remainingSeconds),
                                style: TextStyle(
                                  color: timerColor,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.2,
                                  fontFamily: 'RobotoMono',
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(status,
                                  style: const TextStyle(
                                      color: muted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      session.isCompleted
                          ? 'O tempo programado terminou.'
                          : session.isPaused
                              ? 'A contagem está pausada.'
                              : 'A contagem está acontecendo em tempo real.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: muted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              section('Resumo do ciclo'),
              InfoRow(
                'Temperatura ajustada',
                '${session.temperature.round()} °C',
                trailing: 'Ajuste',
                trailingColor: orange,
              ),
              gap(10),
              InfoRow(
                'Tempo programado',
                formatDurationLabel(session.totalSeconds),
              ),
              gap(10),
              InfoRow(
                'Estado do cronômetro',
                status,
                trailing: session.isCompleted
                    ? 'Finalizado'
                    : session.isPaused
                        ? 'Pausado'
                        : 'Ativo',
                trailingColor: session.isCompleted ? Colors.green : orange,
              ),
              gap(14),
              const Text(
                'O cronômetro controla apenas o tempo dentro do aplicativo. A temperatura exibida é o ajuste escolhido, não uma leitura de sensor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11, height: 1.45),
              ),
              gap(20),
              if (!session.isCompleted && !session.isCancelled)
                PrimaryButton(
                  session.isPaused ? 'Retomar contagem' : 'Pausar contagem',
                  icon: session.isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onPressed: session.isPaused ? session.resume : session.pause,
                )
              else
                PrimaryButton(
                  'Voltar',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.maybePop(context),
                ),
              if (!session.isCompleted && !session.isCancelled) ...[
                gap(8),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Encerrar este ciclo?'),
                        content: const Text(
                            'A contagem será interrompida e não poderá ser retomada.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Continuar ciclo'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              session.cancel();
                              if (identical(activeDryingSession, session)) {
                                activeDryingSession = null;
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Encerrar',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Encerrar ciclo',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Notificações',
      selected: 3,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Acompanhe as atualizações dos seus ciclos.',
                          style: TextStyle(color: muted, fontSize: 13))),
                  if (appNotifications.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setLocalState(() => appNotifications.clear()),
                      child: const Text('Limpar'),
                    ),
                ],
              ),
              section('Recentes'),
              if (appNotifications.isEmpty)
                const Panel(
                  child: Row(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: muted, size: 25),
                      SizedBox(width: 12),
                      Expanded(
                          child: Text('Você não tem notificações.',
                              style: TextStyle(color: muted, fontSize: 13))),
                    ],
                  ),
                )
              else
                ...appNotifications.map((notification) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InfoRow(
                        notification.title,
                        '${notification.message} • ${formatDateTime(notification.createdAt)}',
                        trailing: notification.isRead ? 'Lida' : 'Nova',
                        trailingColor: notification.isRead ? muted : orange,
                        onTap: () {
                          setLocalState(() => notification.isRead = true);
                          if (notification.session != null) {
                            go(context,
                                DryingScreen(session: notification.session!));
                          }
                        },
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Histórico',
      selected: 1,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Todos os ciclos registrados neste aplicativo.',
              style: TextStyle(color: muted, fontSize: 13)),
          section('Ciclos'),
          if (dryingSessions.isEmpty)
            const Panel(
                child: Text(
                    'Seus ciclos aparecerão aqui depois que você iniciar uma secagem.',
                    style: TextStyle(color: muted, fontSize: 13)))
          else
            ...dryingSessions.map((session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoRow(
                    '${session.emoji}  ${session.food}',
                    '${formatDateTime(session.startedAt)} • ${formatDurationLabel(session.totalSeconds)} • ${session.temperature.round()} °C',
                    trailing: session.isCompleted
                        ? 'Concluído'
                        : session.isCancelled
                            ? 'Encerrado'
                            : session.isPaused
                                ? 'Pausado'
                                : 'Ativo',
                    trailingColor: session.isCompleted ? Colors.green : orange,
                    onTap: () => go(
                        context,
                        session.isFinished
                            ? DetailsScreen(session: session)
                            : DryingScreen(session: session)),
                  ),
                )),
        ],
      ),
    );
  }
}

class DetailsScreen extends StatelessWidget {
  final DryingSession session;

  const DetailsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final status = session.isCompleted
        ? 'Concluído'
        : session.isCancelled
            ? 'Encerrado'
            : session.isPaused
                ? 'Pausado'
                : 'Em andamento';
    return AppPage(
      title: 'Detalhes do ciclo',
      selected: 1,
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${session.emoji}  ${session.food}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('$status • ${formatDateTime(session.startedAt)}',
                    style: TextStyle(
                        color: session.isCompleted ? Colors.green : orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          section('Resumo'),
          InfoRow('Temperatura ajustada', '${session.temperature.round()} °C'),
          gap(8),
          InfoRow(
              'Tempo programado', formatDurationLabel(session.totalSeconds)),
          gap(8),
          InfoRow('Responsável', signedInName),
          if (session.note.isNotEmpty) ...[
            gap(8),
            InfoRow('Observações', session.note),
          ],
          if (!session.isFinished) ...[
            gap(16),
            PrimaryButton('Acompanhar contagem',
                onPressed: () => go(context, DryingScreen(session: session))),
          ],
          gap(20),
          PrimaryButton('Repetir configuração',
              onPressed: () =>
                  go(context, SelectFoodScreen(initialFood: session.food))),
        ],
      ),
    );
  }
}

class SavedFoodsScreen extends StatelessWidget {
  const SavedFoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Alimentos salvos',
      selected: 1,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          final saved = foodCatalog
              .where((food) => savedFoodNames.contains(food[1]))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Acesse rapidamente os alimentos que você salvou.',
                  style: TextStyle(color: muted, fontSize: 13)),
              section('Minha lista'),
              if (saved.isEmpty)
                const Panel(
                    child: Text(
                        'Sua lista está vazia. Salve alimentos na tela Secar para encontrá-los aqui.',
                        style: TextStyle(color: muted, fontSize: 13)))
              else
                ...saved.map((food) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Text(food[0], style: const TextStyle(fontSize: 29)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => go(
                                    context,
                                    ConfigureDryingScreen(
                                        food: food[1], emoji: food[0])),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(food[1],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(
                                        '${food[2]} • ${food[3]} °C • ${food[4]} h',
                                        style: const TextStyle(
                                            color: muted, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remover dos salvos',
                              onPressed: () {
                                savedFoodNames.remove(food[1]);
                                setLocalState(() {});
                                showMessage(
                                    context, 'Alimento removido dos salvos.');
                              },
                              icon: const Icon(Icons.bookmark_remove_outlined,
                                  color: orange),
                            ),
                          ],
                        ),
                      ),
                    )),
              gap(10),
              PrimaryButton('Adicionar alimento',
                  onPressed: () => go(context, const SelectFoodScreen())),
            ],
          );
        },
      ),
    );
  }
}

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final handle = TextEditingController();

  @override
  void dispose() {
    handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviteCode =
        'DRYTECH-${(activeAccount?.username ?? 'USUARIO').toUpperCase()}';
    return AppPage(
      title: 'Adicionar amigo',
      selected: 4,
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Compartilhe o acesso e encontre pessoas cadastradas.',
              style: TextStyle(color: muted, fontSize: 13)),
          section('Seu código de convite'),
          Panel(
            child: Column(
              children: [
                const Icon(Icons.group_add_rounded, color: orange, size: 42),
                const SizedBox(height: 12),
                SelectableText(inviteCode,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                const Text('Compartilhe este código com quem deseja adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: inviteCode));
                    if (context.mounted)
                      showMessage(context, 'Código copiado.');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar código'),
                ),
              ],
            ),
          ),
          section('Buscar pessoa'),
          TextField(
            controller: handle,
            decoration: const InputDecoration(
                hintText: '@usuário ou código de convite',
                prefixIcon: Icon(Icons.search)),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchPerson(context),
          ),
          gap(12),
          PrimaryButton('Buscar pessoa',
              icon: Icons.person_search_rounded,
              onPressed: () => _searchPerson(context)),
          section('Pessoas adicionadas'),
          if (collaborators.isEmpty)
            const Panel(
                child: Text('Ninguém foi adicionado ainda.',
                    style: TextStyle(color: muted, fontSize: 13)))
          else
            ...collaborators.map((person) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoRow(person.name, '@${person.username}',
                      trailing: 'Adicionado'),
                )),
        ],
      ),
    );
  }

  void _searchPerson(BuildContext context) {
    final rawInput = handle.text.trim();
    final username = rawInput
        .replaceFirst(RegExp(r'^DRYTECH-', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    if (username.isEmpty) {
      showMessage(context, 'Digite um nome de usuário.');
      return;
    }
    final index = _accounts
        .indexWhere((account) => account.username.toLowerCase() == username);
    if (index < 0) {
      showMessage(context, 'Nenhuma conta encontrada com esse usuário.');
      return;
    }
    final person = _accounts[index];
    if (identical(person, activeAccount) ||
        person.username == activeAccount?.username) {
      showMessage(context, 'Esse é o seu próprio usuário.');
      return;
    }
    if (collaborators.any((item) => item.username == person.username)) {
      showMessage(context, 'Essa pessoa já foi adicionada.');
      return;
    }
    setState(() => collaborators.add(person));
    handle.clear();
    showMessage(context, '${person.name} foi adicionado(a).');
  }
}

class CollaboratorsScreen extends StatelessWidget {
  const CollaboratorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Colaboradores',
      selected: 4,
      showBack: true,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Gerencie quem tem acesso compartilhado.',
                  style: TextStyle(color: muted, fontSize: 13)),
              section('Proprietário'),
              InfoRow(signedInName, signedInHandle, trailing: 'Você'),
              section('Pessoas com acesso'),
              if (collaborators.isEmpty)
                const Panel(
                    child: Text('Você ainda não adicionou colaboradores.',
                        style: TextStyle(color: muted, fontSize: 13)))
              else
                ...collaborators.map((person) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(person.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  Text('@${person.username}',
                                      style: const TextStyle(
                                          color: muted, fontSize: 11)),
                                ])),
                            IconButton(
                              tooltip: 'Remover colaborador',
                              onPressed: () => showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Remover colaborador?'),
                                  content: Text(
                                      'Remover ${person.name} da sua lista?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('Voltar')),
                                    TextButton(
                                        onPressed: () {
                                          collaborators.remove(person);
                                          Navigator.pop(dialogContext);
                                          setLocalState(() {});
                                        },
                                        child: const Text('Remover',
                                            style:
                                                TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ),
                              icon: const Icon(
                                  Icons.person_remove_alt_1_rounded,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    )),
              gap(12),
              PrimaryButton('Adicionar amigo',
                  onPressed: () => go(context, const AddFriendScreen())),
            ],
          );
        },
      ),
    );
  }
}

class SettingsOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback action;

  const SettingsOption(this.title, this.subtitle, this.icon, this.action);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = <SettingsOption>[
      SettingsOption('Sua conta', 'Nome, usuário e e-mail',
          Icons.person_outline_rounded, () => _showAccount(context)),
      SettingsOption(
          'Notificações',
          appNotificationsEnabled ? 'Ativadas' : 'Desativadas',
          Icons.notifications_none_rounded,
          () => _showNotificationSettings(context)),
      SettingsOption(
          'Segurança',
          'Redefinir senha',
          Icons.lock_outline_rounded,
          () => showDialog(
              context: context,
              builder: (_) => const PasswordRecoveryDialog())),
      SettingsOption(
          'Privacidade',
          'Informações sobre seus dados',
          Icons.privacy_tip_outlined,
          () => _showInfo(context, 'Privacidade',
              'As informações desta sessão são usadas para personalizar sua experiência. A conta local não é compartilhada automaticamente com outras pessoas.')),
      SettingsOption(
          'Aparelho DryTech',
          'Status da conexão',
          Icons.sensors_outlined,
          () => showDialog(
              context: context, builder: (_) => const DeviceInfoDialog())),
      SettingsOption(
          'Ajuda',
          'Como usar o aplicativo',
          Icons.help_outline_rounded,
          () => _showInfo(context, 'Ajuda',
              'Para começar, selecione Secar, escolha um alimento, ajuste temperatura e duração e inicie a contagem. Você pode pausar, retomar ou encerrar o ciclo na tela de acompanhamento.')),
    ];

    return AppPage(
      title: 'Configurações',
      selected: 4,
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Personalize sua experiência no DryTech.',
              style: TextStyle(color: muted, fontSize: 13)),
          section('Preferências'),
          ...settings.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    onTap: item.action,
                    leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E8),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(item.icon, color: orange)),
                    title: Text(item.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(item.subtitle,
                        style: const TextStyle(fontSize: 11, color: muted)),
                    trailing:
                        const Icon(Icons.chevron_right_rounded, color: muted),
                  ),
                ),
              )),
          gap(10),
          TextButton.icon(
            onPressed: () {
              activeAccount = null;
              replace(context, const LoginScreen());
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: const Text('Sair da conta',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAccount(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Sua conta'),
              content: Text(
                  'Nome: ${activeAccount?.name ?? signedInName}\nUsuário: $signedInHandle\nE-mail: ${activeAccount?.email ?? 'Não informado'}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'))
              ],
            ));
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (dialogContext, setDialogState) => AlertDialog(
                title: const Text('Notificações'),
                content: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Receber avisos'),
                  value: appNotificationsEnabled,
                  activeColor: orange,
                  onChanged: (value) {
                    appNotificationsEnabled = value;
                    setDialogState(() {});
                  },
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Concluir'))
                ],
              ),
            ));
  }

  void _showInfo(BuildContext context, String title, String message) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendi'))
              ],
            ));
  }
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final completed =
        dryingSessions.where((session) => session.isCompleted).toList();
    final uniqueFoods = completed.map((session) => session.food).toSet().length;
    final durations =
        completed.fold<int>(0, (sum, session) => sum + session.totalSeconds);
    final now = DateTime.now();
    final dayCounts = List<int>.generate(7, (index) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index));
      return completed
          .where((session) =>
              session.startedAt.year == day.year &&
              session.startedAt.month == day.month &&
              session.startedAt.day == day.day)
          .length;
    });
    final maxCount = dayCounts.fold<int>(
        1, (maxValue, value) => value > maxValue ? value : maxValue);
    final foodCounts = <String, int>{};
    for (final session in completed) {
      foodCounts[session.food] = (foodCounts[session.food] ?? 0) + 1;
    }
    final rankedFoods = foodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppPage(
      title: 'Estatísticas',
      selected: 4,
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Panel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Metric(completed.length.toString(), 'Ciclos concluídos'),
                _Metric(uniqueFoods.toString(), 'Alimentos'),
                _Metric(formatDurationLabel(durations), 'Tempo total'),
              ],
            ),
          ),
          section('Atividade nos últimos 7 dias'),
          Panel(
            child: SizedBox(
              height: 168,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int i = 0; i < dayCounts.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${dayCounts[i]}',
                                style: const TextStyle(
                                    fontSize: 10, color: muted)),
                            const SizedBox(height: 5),
                            Container(
                              height: 105 * dayCounts[i] / maxCount + 4,
                              decoration: BoxDecoration(
                                  color: orangeLight,
                                  borderRadius: BorderRadius.circular(7)),
                            ),
                            const SizedBox(height: 7),
                            Text(
                                ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][
                                    DateTime.now()
                                            .subtract(Duration(days: 6 - i))
                                            .weekday -
                                        1],
                                style: const TextStyle(
                                    fontSize: 10, color: muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          section('Alimentos mais utilizados'),
          if (rankedFoods.isEmpty)
            const Panel(
                child: Text(
                    'Conclua ciclos para acompanhar seus alimentos mais utilizados.',
                    style: TextStyle(color: muted, fontSize: 13)))
          else
            ...rankedFoods.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoRow(entry.key,
                      '${entry.value} ${entry.value == 1 ? 'ciclo' : 'ciclos'} concluídos'),
                )),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 25, color: orange, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Perfil',
      selected: 4,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
              child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Color(0xFFFFE8DD),
                  child: Icon(Icons.person_rounded, color: orange, size: 46))),
          gap(12),
          Center(
              child: Text(signedInName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: ink))),
          Center(
              child:
                  Text(signedInHandle, style: const TextStyle(color: muted))),
          if (activeAccount != null)
            Center(
                child: Text(activeAccount!.email,
                    style: const TextStyle(color: muted, fontSize: 12))),
          section('Minha conta'),
          InfoRow('Colaboradores', 'Gerencie quem acompanha sua secadora',
              trailing: '›',
              trailingColor: orange,
              onTap: () => go(context, const CollaboratorsScreen())),
          gap(10),
          InfoRow('Estatísticas', 'Veja os resultados dos seus ciclos',
              trailing: '›',
              trailingColor: orange,
              onTap: () => go(context, const StatisticsScreen())),
          gap(10),
          InfoRow('Configurações', 'Preferências e segurança',
              trailing: '›',
              trailingColor: orange,
              onTap: () => go(context, const SettingsScreen())),
          gap(10),
          PrimaryButton('Adicionar amigo',
              icon: Icons.person_add_alt_1,
              onPressed: () => go(context, const AddFriendScreen())),
          gap(10),
          TextButton.icon(
            onPressed: () {
              activeAccount = null;
              replace(context, const LoginScreen());
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: const Text('Sair da conta',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
