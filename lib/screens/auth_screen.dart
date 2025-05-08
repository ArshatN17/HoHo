import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;

  const AuthScreen({
    Key? key,
    this.isLogin = true,
  }) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Set the initial tab based on the prop
    if (!widget.isLogin) {
      _tabController.animateTo(1);  // Index 1 is Register tab
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Center(
              child: Text(
                'HaHo',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Login'),
                Tab(text: 'Register'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  LoginTab(),
                  RegisterTab(),
                ],
              ),
            ),
            // Guest browsing option
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              child: Column(
                children: [
                  const Text(
                    'Just browsing?',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final success = await authProvider.enterGuestMode();
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(authProvider.error ?? 'Failed to enter guest mode')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: const Text('Continue as Guest'),
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

class LoginTab extends StatefulWidget {
  const LoginTab({Key? key}) : super(key: key);

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    
    if (success && mounted) {
      // Navigate to home screen on successful login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Failed to login')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: Validators.validatePassword,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: authProvider.isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
            const SizedBox(height: 16),
            if (authProvider.error != null)
              Text(
                authProvider.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class RegisterTab extends StatefulWidget {
  const RegisterTab({Key? key}) : super(key: key);

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
  
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
    );
    
    if (success && mounted) {
      // Navigate to home screen on successful registration
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Failed to register')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: Validators.validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              obscureText: _obscureConfirmPassword,
              validator: (value) => Validators.validateConfirmPassword(
                value,
                _passwordController.text,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: authProvider.isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Register'),
            ),
            const SizedBox(height: 16),
            if (authProvider.error != null)
              Text(
                authProvider.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
} 