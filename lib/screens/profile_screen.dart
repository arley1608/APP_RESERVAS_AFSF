import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      setState(() {
        nameController.text = snapshot["nombre"] ?? "";
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'nombre': nameController.text.trim(),
      });
      _showDialog("Éxito", "Nombre actualizado correctamente.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _updatePassword() async {
    if (newPasswordController.text.length < 6) {
      _showDialog("Error", "La contraseña debe tener al menos 6 caracteres.");
      return;
    }
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: oldPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPasswordController.text);
      _showDialog("Éxito", "Contraseña actualizada exitosamente.");
    } catch (e) {
      _showDialog(
          "Error", "Error al actualizar la contraseña: ${e.toString()}");
    }
    setState(() => isLoading = false);
  }

  void _showDialog(String title, String message) {
    IconData icon = title == "Éxito" ? Icons.check_circle : Icons.error;
    Color iconColor = title == "Éxito" ? Colors.green : Colors.red;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              SizedBox(width: 10),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Aceptar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 35, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Editar Perfil",
            style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: nameController,
                  style: TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: "Nombre",
                    labelStyle:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _updateProfile,
                child: isLoading
                    ? CircularProgressIndicator()
                    : Text("Actualizar Nombre",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 40),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  style: TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: "Contraseña Actual",
                    labelStyle: TextStyle(fontSize: 20),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: "Nueva Contraseña",
                    labelStyle: TextStyle(fontSize: 20),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _updatePassword,
                child: isLoading
                    ? CircularProgressIndicator()
                    : Text("Actualizar Contraseña",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
