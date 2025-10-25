import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';  // Import FirebaseAuth
import 'home_screen.dart'; // Home screen after successful login/signup

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKeyLogin = GlobalKey<FormState>();
  final _formKeySignup = GlobalKey<FormState>();

  final _emailControllerLogin = TextEditingController();
  final _passwordControllerLogin = TextEditingController();

  final _emailControllerSignup = TextEditingController();
  final _passwordControllerSignup = TextEditingController();
  final _confirmPasswordControllerSignup = TextEditingController();

  bool _obscureLogin = true;
  bool _obscureSignup = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in user
  Future<void> _signIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailControllerLogin.text.trim(),
        password: _passwordControllerLogin.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed! Please try again.')),
      );
    }
  }

  // Sign up user
  Future<void> _signUp() async {
    if (_passwordControllerSignup.text != _confirmPasswordControllerSignup.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailControllerSignup.text.trim(),
        password: _passwordControllerSignup.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-up failed! Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(), // Listen to Firebase auth state changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // If the user is logged in, navigate to Home Screen
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // If the user is not logged in, show the AuthPage (Login/SignUp)
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Welcome to Budget Mate '),
              bottom: const TabBar(
                tabs: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Login'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Sign Up'),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  // Login Form
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKeyLogin,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailControllerLogin,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordControllerLogin,
                            obscureText: _obscureLogin,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureLogin = !_obscureLogin;
                                  });
                                },
                                icon: Icon(
                                  _obscureLogin
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (_formKeyLogin.currentState!.validate()) {
                                _signIn();
                              }
                            },
                            child: const Text('Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Sign-Up Form
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKeySignup,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailControllerSignup,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordControllerSignup,
                            obscureText: _obscureSignup,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureSignup = !_obscureSignup;
                                  });
                                },
                                icon: Icon(
                                  _obscureSignup
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordControllerSignup,
                            obscureText: _obscureSignup,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(Icons.lock_reset_outlined),
                            ),
                            validator: (v) {
                              if (v != _passwordControllerSignup.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (_formKeySignup.currentState!.validate()) {
                                _signUp();
                              }
                            },
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
