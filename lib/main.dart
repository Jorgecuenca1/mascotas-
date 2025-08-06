import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/planilla_list_screen.dart';
import 'services/auth_service.dart';

void main() => runApp(const MascotasApp());

class MascotasApp extends StatelessWidget {
  const MascotasApp({Key? key}) : super(key: key);
  
  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veterinario',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Pequeña pausa para mostrar splash
    await Future.delayed(Duration(milliseconds: 500));
    
    final isLoggedIn = await AuthService.isLoggedIn();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isLoggedIn ? PlanillaListScreen() : LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Veterinario',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
