import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  bool isLoading = false;
  String _rol = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _service.getUsuario(user.uid);
      if (data != null) {
        setState(() {
          nameController.text = data['nombre'] ?? '';
          _rol = data['rol'] ?? '';
          _email = user.email ?? '';
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (nameController.text.trim().isEmpty) {
      _showErrorDialog("El nombre no puede estar vacío");
      return;
    }
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _service.updateUsuario(
            user.uid, {'nombre': nameController.text.trim()});
        _showSuccessDialog("Nombre actualizado correctamente");
      }
    } catch (e) {
      _showErrorDialog("Error al actualizar el nombre: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (newPasswordController.text.length < 6) {
      _showErrorDialog("La contraseña debe tener al menos 6 caracteres");
      return;
    }
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: oldPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPasswordController.text);
        _showSuccessDialog("Contraseña actualizada exitosamente");
        oldPasswordController.clear();
        newPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Error al actualizar la contraseña";
      if (e.code == 'wrong-password')
        errorMessage = "La contraseña actual es incorrecta";
      if (e.code == 'weak-password')
        errorMessage = "La nueva contraseña es muy débil";
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog("Error inesperado: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'admin':
        return Colors.red[700]!;
      case 'recepcionista':
        return Colors.green[700]!;
      default:
        return Colors.blue[700]!;
    }
  }

  String _getRolLabel(String rol) {
    switch (rol) {
      case 'admin':
        return 'Administrador';
      case 'recepcionista':
        return 'Recepcionista';
      case 'operador':
        return 'Operador';
      default:
        return rol;
    }
  }

  void _showSuccessDialog(String message) => _showDialog(
      title: "Éxito",
      message: message,
      icon: Icons.check_circle,
      iconColor: Colors.green);

  void _showErrorDialog(String message) => _showDialog(
      title: "Error",
      message: message,
      icon: Icons.error,
      iconColor: Colors.red);

  void _showDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(icon, color: iconColor, size: 28),
          SizedBox(width: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(message, style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Perfil de Usuario",
            style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 35, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar y rol
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green[700],
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            SizedBox(height: 12),
            if (_rol.isNotEmpty)
              Chip(
                avatar: Icon(Icons.verified_user,
                    color: Colors.white, size: 16),
                label: Text(
                  _getRolLabel(_rol),
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: _getRolColor(_rol),
              ),
            SizedBox(height: 4),
            if (_email.isNotEmpty)
              Text(
                _email,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            SizedBox(height: 20),

            // Información Personal
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Información Personal",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700])),
                    SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Nombre Completo",
                        labelStyle: TextStyle(fontSize: 18),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green[700],
                        ),
                        onPressed: isLoading ? null : _updateProfile,
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text("Actualizar Nombre",
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),

            // Cambiar Contraseña
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cambiar Contraseña",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700])),
                    SizedBox(height: 20),
                    TextField(
                      controller: oldPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Contraseña Actual",
                        labelStyle: TextStyle(fontSize: 18),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Nueva Contraseña",
                        labelStyle: TextStyle(fontSize: 18),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green[700],
                        ),
                        onPressed: isLoading ? null : _updatePassword,
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text("Actualizar Contraseña",
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}