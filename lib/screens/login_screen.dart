import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import '../services/user_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => loading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim());

      User? user = userCredential.user;
      if (user != null) {
        // Primero obtener rol — ya usa sesión autenticada
        String? rol = await _userService.getUserRole(user.uid);

        if (rol == null) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            _mostrarError(
                "Tu cuenta no está registrada. Contacta a un administrador.");
          }
          return;
        }

        // Luego verificar que esté activo
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData['activo'] == false) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              _mostrarError(
                  "Tu cuenta ha sido desactivada. Contacta al administrador.");
            }
            return;
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => DashboardScreen(rol: rol)),
          );
        }
      }
    } catch (e) {
      if (mounted) _mostrarError(_getFirebaseErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text("Error"),
            ],
          ),
          content: Text(mensaje, style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Aceptar",
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _getFirebaseErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return "Este correo no está registrado.";
    } else if (error.contains('wrong-password')) {
      return "La contraseña es incorrecta.";
    } else if (error.contains('invalid-email')) {
      return "El formato del correo no es válido.";
    } else if (error.contains('invalid-credential')) {
      return "Correo o contraseña incorrectos.";
    } else if (error.contains('too-many-requests')) {
      return "Has intentado demasiadas veces. Intenta más tarde.";
    } else if (error.contains('permission-denied') ||
        error.contains('does not have permission')) {
      return "Error de permisos. Contacta al administrador.";
    } else {
      return "Error: ${error}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[700]!, Colors.orange[600]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 450),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/logo_colores.png",
                          height: 220,
                        ),
                        SizedBox(height: 40),
                        Text(
                          "Gestión de Reservas\nAgroFinca San Felipe",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 40),
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: emailController,
                                    decoration: InputDecoration(
                                      labelText: "Correo Electrónico",
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      prefixIcon: Icon(Icons.email,
                                          color: Colors.green),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Ingrese su correo electrónico.";
                                      }
                                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                          .hasMatch(value)) {
                                        return "El formato del correo no es válido.";
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: "Contraseña",
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      prefixIcon: Icon(Icons.lock,
                                          color: Colors.green),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.length < 6) {
                                        return "La contraseña debe tener al menos 6 caracteres.";
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      onPressed: loading ? null : login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: loading
                                          ? CircularProgressIndicator(
                                              color: Colors.white)
                                          : Text(
                                              "Iniciar Sesión",
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 25),
              child: Text(
                "© 2025 AgroFinca San Felipe SAS. Todos los derechos reservados.",
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}