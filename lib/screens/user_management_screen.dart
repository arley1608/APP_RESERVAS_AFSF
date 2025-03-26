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
    setState(() => isLoading = true);
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      String uid = userCredential.user!.uid;
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': nombreController.text.trim(),
        'email': emailController.text.trim(),
        'rol': rolSeleccionado,
      });
      _showDialog("Éxito", "Usuario agregado correctamente.");
    } catch (e) {
      _showDialog("Error", "No se pudo crear el usuario: ${e.toString()}");
    }
    setState(() => isLoading = false);
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .delete();
      _showDialog(
          "Éxito", "Usuario eliminado correctamente de la base de datos.");
    } catch (e) {
      _showDialog("Error", "Error al eliminar el usuario: ${e.toString()}");
    }
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
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombreController,
                  decoration: InputDecoration(labelText: "Nombre")),
              TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: "Correo Electrónico")),
              TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: "Contraseña"),
                  obscureText: true),
              DropdownButton<String>(
                value: rolSeleccionado,
                onChanged: (value) {
                  setState(() {
                    rolSeleccionado = value!;
                  });
                },
                items: ["admin", "operador", "recepcionista"]
                    .map(
                        (rol) => DropdownMenuItem(value: rol, child: Text(rol)))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createUser();
              },
              child: Text("Agregar"),
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
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text("Confirmar Eliminación",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "¿Estás seguro de que deseas eliminar a ${userName}? Esta acción no se puede deshacer.",
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(userId);
              },
              child: Text("Eliminar",
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
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
        title: Text("Gestión de Usuarios",
            style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 35),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _showAddUserDialog,
              child: Text("Agregar Usuario",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return SizedBox.shrink();
                    return ListTile(
                      title: Text("${data['nombre']} (${data['rol']})",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(data['email'] ?? 'Sin Correo',
                          style: TextStyle(fontSize: 16)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 28),
                        onPressed: () {
                          _showConfirmationDialog(
                              doc.id, data['nombre'] ?? 'Usuario');
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
