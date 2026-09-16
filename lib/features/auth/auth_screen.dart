import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/demo/demo_mode.dart';
import 'package:barrr/models/app_user.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  UserRole _role = UserRole.customer;
  final Set<String> _services = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).auth.signIn(_loginEmail.text, _loginPass.text);
    } catch (e) {
      setState(() => _error = 'تعذر تسجيل الدخول. تحقق من البيانات.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitRegister() async {
    if (_role == UserRole.technician && _services.isEmpty) {
      setState(() => _error = 'اختر خدمة واحدة على الأقل.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).auth.register(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _pass.text,
            role: _role,
            serviceIds: _services.toList(),
          );
    } catch (e) {
      setState(() => _error = 'تعذر إنشاء الحساب. ربما البريد مستخدم.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(AppStrings.appName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('سجل الدخول أو أنشئ حساباً للبدء'),
            if (DemoMode.enabled) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final a in DemoAccounts.all)
                      ActionChip(
                        label: Text('${a.label}: ${a.email}'),
                        onPressed: () {
                          _tabs.index = 0;
                          _loginEmail.text = a.email;
                          _loginPass.text = DemoAccounts.password;
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              const Text('كلمة المرور لكل الحسابات: 12345678', style: TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 16),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: AppStrings.login),
                Tab(text: AppStrings.register),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _LoginForm(
                    email: _loginEmail,
                    password: _loginPass,
                    busy: _busy,
                    onSubmit: _submitLogin,
                  ),
                  _RegisterForm(
                    name: _name,
                    email: _email,
                    phone: _phone,
                    password: _pass,
                    role: _role,
                    services: _services,
                    busy: _busy,
                    onRole: (r) => setState(() => _role = r),
                    onToggleService: (id) {
                      setState(() {
                        if (_services.contains(id)) {
                          _services.remove(id);
                        } else {
                          _services.add(id);
                        }
                      });
                    },
                    onSubmit: _submitRegister,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.email,
    required this.password,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: AppStrings.email),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: AppStrings.password),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy ? const CircularProgressIndicator() : const Text(AppStrings.login),
        ),
      ],
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    required this.services,
    required this.busy,
    required this.onRole,
    required this.onToggleService,
    required this.onSubmit,
  });

  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController password;
  final UserRole role;
  final Set<String> services;
  final bool busy;
  final ValueChanged<UserRole> onRole;
  final ValueChanged<String> onToggleService;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: AppStrings.name)),
        const SizedBox(height: 12),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: AppStrings.email),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: AppStrings.phone),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: AppStrings.password),
        ),
        const SizedBox(height: 16),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(value: UserRole.customer, label: Text(AppStrings.customer)),
            ButtonSegment(value: UserRole.technician, label: Text(AppStrings.technician)),
          ],
          selected: {role},
          onSelectionChanged: (s) => onRole(s.first),
        ),
        if (role == UserRole.technician) ...[
          const SizedBox(height: 16),
          const Text(AppStrings.myServices, style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('يظهر حسابك للعملاء بعد توثيق الإدارة. التواصل داخل التطبيق فقط.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in seedServices)
                FilterChip(
                  label: Text(s.titleAr),
                  selected: services.contains(s.id),
                  onSelected: (_) => onToggleService(s.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy ? const CircularProgressIndicator() : const Text(AppStrings.register),
        ),
      ],
    );
  }
}
