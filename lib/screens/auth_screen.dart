import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'chat_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _pinController = TextEditingController();
  bool _showKeyInput = true;

  @override
  void dispose() {
    _keyController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.checkAuthState().then((_) {
        final hasPin = authProvider.isAuthenticated;
        setState(() {
          _showKeyInput = !hasPin;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Авторизация'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock,
                      size: 100, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 30),
                  Text(
                    _showKeyInput ? 'Введите API ключ' : 'Введите PIN',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  if (_showKeyInput)
                    TextFormField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'API ключ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите ключ';
                        }
                        return null;
                      },
                    )
                  else
                    TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'PIN код',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите PIN';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 20),
                  if (authProvider.errorMessage != null)
                    Text(
                      authProvider.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              if (_showKeyInput) {
                                final success = await authProvider
                                    .validateKey(_keyController.text);
                                if (success) {
                                  setState(() {
                                    _showKeyInput = false;
                                  });
                                }
                              } else {
                                final success = await authProvider
                                    .validatePin(_pinController.text);
                                if (success) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ChatScreen(),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                    child: authProvider.isLoading
                        ? const CircularProgressIndicator()
                        : Text(_showKeyInput ? 'Проверить ключ' : 'Войти'),
                  ),
                  if (!_showKeyInput)
                    TextButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () {
                              authProvider.resetAuth();
                              setState(() {
                                _showKeyInput = true;
                                _pinController.clear();
                              });
                            },
                      child: const Text('Сбросить ключ'),
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
