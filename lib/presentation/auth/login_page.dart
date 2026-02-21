import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/di/service_locator.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../home/home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthRepository _authRepo;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepositoryImpl(sl.supabase);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authRepo.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập thất bại: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final isCompact = width <= 360;
    final isTablet = width >= 900;
    final isTabletLandscape = isTablet && width > height;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact
                  ? 16
                  : isTablet
                  ? 32
                  : 24,
              vertical: isCompact
                  ? 14
                  : isTablet
                  ? (isTabletLandscape ? 20 : 28)
                  : 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? (isTabletLandscape ? 480 : 520) : 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(isCompact),
                    SizedBox(height: isCompact ? 20 : 28),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(isCompact ? 14 : 18),
                        child: Column(
                          children: [
                            _buildEmailField(),
                            SizedBox(height: isCompact ? 10 : 12),
                            _buildPasswordField(),
                            SizedBox(height: isCompact ? 14 : 18),
                            _buildLoginButton(),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 16 : 20),
                    _buildSocialLoginDivider(),
                    SizedBox(height: isCompact ? 12 : 16),
                    _buildSocialLoginButtons(isCompact),
                    SizedBox(height: isCompact ? 16 : 20),
                    _buildRegisterLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Column(
      children: [
        Text(
          'Chào mừng trở lại',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 26 : null,
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        Text(
          'Đăng nhập để tiếp tục trò chuyện nhé',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: isCompact ? 14 : null,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.email_outlined),
        labelText: 'Email',
      ),
      validator: (value) {
        if (value == null || value.isEmpty || !value.contains('@')) {
          return 'Vui lòng nhập một email hợp lệ';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Mật khẩu',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty || value.length < 6) {
          return 'Mật khẩu phải có ít nhất 6 ký tự';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        child: _isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Text('Đăng nhập'),
      ),
    );
  }

  Widget _buildSocialLoginDivider() {
    return Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'HOẶC',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildSocialLoginButtons(bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(
          'assets/icons/google.svg',
          () {},
          isCompact: isCompact,
        ), // TODO: Implement Google Sign In
        SizedBox(width: isCompact ? 16 : 24),
        _socialButton(
          'assets/icons/apple.svg',
          () {},
          isApple: true,
          isCompact: isCompact,
        ), // TODO: Implement Apple Sign In
      ],
    );
  }

  Widget _socialButton(
    String asset,
    VoidCallback onPressed, {
    bool isApple = false,
    bool isCompact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.outlined(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.all(isCompact ? 12 : 14),
      ),
      icon: SvgPicture.asset(
        asset,
        height: isCompact ? 22 : 24,
        width: isCompact ? 22 : 24,
        colorFilter: isApple && isDark
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Chưa có tài khoản?'),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterPage()),
          ),
          child: const Text('Đăng ký ngay'),
        ),
      ],
    );
  }
}
