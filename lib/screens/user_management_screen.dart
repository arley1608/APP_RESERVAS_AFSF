import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  String rolSeleccionado = "operador";
  bool isLoading = false;

  Future<void> _createUser() async {
    // Validación de campos
    if (nombreController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showErrorDialog("Todos los campos son requeridos");
      return;
    }

    if (passwordController.text.length < 6) {
      _showErrorDialog("La contraseña debe tener al menos 6 caracteres");
      return;
    }

    setState(() => isLoading = true);
    try {
      // Crear el nuevo usuario
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Guardar datos adicionales en Firestore
      String uid = userCredential.user!.uid;
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': nombreController.text.trim(),
        'email': emailController.text.trim(),
        'rol': rolSeleccionado,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog("Usuario creado correctamente");
      _resetForm();
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Error al crear usuario";
      if (e.code == 'weak-password') {
        errorMessage = "La contraseña es muy débil";
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "El correo ya está registrado";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Correo electrónico inválido";
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog("Error inesperado: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .delete();
      _showSuccessDialog("Usuario eliminado correctamente");
    } catch (e) {
      _showErrorDialog("Error al eliminar usuario: ${e.toString()}");
    }
  }

  void _showSuccessDialog(String message) {
    _showDialog(
      title: "Éxito",
      message: message,
      icon: Icons.check_circle,
      iconColor: Colors.green,
    );
  }

  void _showErrorDialog(String message) {
    _showDialog(
      title: "Error",
      message: message,
      icon: Icons.error,
      iconColor: Colors.red,
    );
  }

  void _showDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
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
          content: Text(message, style: TextStyle(fontSize: 18)),
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

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Agregar Usuario",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: "Nombre Completo",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: rolSeleccionado,
                    onChanged: (value) =>
                        setState(() => rolSeleccionado = value!),
                    items: ["admin", "operador", "recepcionista"]
                        .map((rol) => DropdownMenuItem(
                              value: rol,
                              child: Text(rol.capitalize()),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar", style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _createUser();
                    },
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Agregar Usuario", style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text("Confirmar Eliminación",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "¿Estás seguro de eliminar a $userName? Esta acción no se puede deshacer.",
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar", style: TextStyle(fontSize: 16)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(userId);
              },
              child: Text("Eliminar",
                  style: TextStyle(color: Colors.red, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    nombreController.clear();
    emailController.clear();
    passwordController.clear();
    rolSeleccionado = "operador";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión de Usuarios",
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
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _showAddUserDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Agregar Nuevo Usuario",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error al cargar usuarios"));
                }

                final users = snapshot.data?.docs ?? [];

                if (users.isEmpty) {
                  return Center(child: Text("No hay usuarios registrados"));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: Icon(Icons.person,
                            size: 40, color: _getRoleColor(data['rol'])),
                        title: Text(data['nombre']?.toString() ?? 'Sin nombre',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['email']?.toString() ?? 'Sin correo',
                                style: TextStyle(fontSize: 16)),
                            Text(
                                "Rol: ${data['rol']?.toString().capitalize() ?? 'No definido'}",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600])),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red, size: 28),
                          onPressed: () {
                            _showConfirmationDialog(doc.id,
                                data['nombre']?.toString() ?? 'Usuario');
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'operador':
        return Colors.blue;
      case 'recepcionista':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
