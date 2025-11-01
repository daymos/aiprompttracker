import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  '/logo.svg',
                  height: 140,
                  width: 140,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.search,
                      size: 80,
                      color: Colors.deepPurple,
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'KeywordsChat',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Simple conversational keyword research',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (authProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await authProvider.signInWithGoogle();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing in: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


