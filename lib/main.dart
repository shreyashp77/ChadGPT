import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart'; // Will create effectively
import 'screens/settings_screen.dart'; // Will create effectively
import 'screens/chat_screen.dart'; // Will create effectively
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  await NotificationService().initialize();
  
  runApp(const ChadGPTApp());
}

class ChadGPTApp extends StatelessWidget {
  const ChadGPTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, ChatProvider>(
          create: (ctx) => ChatProvider(ctx.read<SettingsProvider>()),
          update: (ctx, settings, previous) => 
            previous ?? ChatProvider(settings),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final seedColor = settings.settings.themeColor != null 
              ? Color(settings.settings.themeColor!) 
              : AppTheme.presetColors.first;

          return MaterialApp(
            title: 'ChadGPT',
            debugShowCheckedModeBanner: false,
            themeMode: settings.settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.getLightTheme(seedColor),
            darkTheme: AppTheme.getDarkTheme(seedColor),
            home: ChatScreen(),
            routes: {
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}


