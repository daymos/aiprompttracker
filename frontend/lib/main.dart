import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/project_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/project_screen.dart';
import 'screens/guides_screen.dart';
import 'screens/conversations_screen.dart';
import 'screens/keyword_detail_screen.dart';

void main() {
  runApp(const KeywordsChatApp());
}

class KeywordsChatApp extends StatelessWidget {
  const KeywordsChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
      ],
      child: MaterialApp(
        title: 'KeywordsChat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return MaterialPageRoute(builder: (context) => const AuthWrapper());
          } else if (settings.name == '/project') {
            return MaterialPageRoute(builder: (context) => const ProjectScreen());
          } else if (settings.name == '/guides') {
            return MaterialPageRoute(builder: (context) => const GuidesScreen());
          } else if (settings.name == '/conversations') {
            return MaterialPageRoute(builder: (context) => const ConversationsScreen());
          } else if (settings.name == '/keyword-detail') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => KeywordDetailScreen(
                keywordId: args['keywordId'],
                keyword: args['keyword'],
                currentPosition: args['currentPosition'],
              ),
            );
          }
          return null;
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    if (authProvider.isAuthenticated) {
      return const ChatScreen();
    }
    
    return const AuthScreen();
  }
}

