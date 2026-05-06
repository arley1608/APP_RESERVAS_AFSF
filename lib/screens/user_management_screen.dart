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

    final adminUser = FirebaseAuth.instance.currentUser;
    final adminEmail = adminUser?.email;

    final adminPassword = await _pedirPasswordAdmin();
    if (adminPassword == null) {
      setState(() => isLoading = false);
      return;
    }

    final newEmail = emailController.text.trim();
    final newPassword = passwordController.text.trim();
    final newNombre = nombreController.text.trim();
    final newRol = rolSeleccionado;

    try {
      // Crear el nuevo usuario (esto cambia la sesión activa)
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: newEmail,
        password: newPassword,
      );

      // Guardar en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .set({
        'nombre': newNombre,
        'email': newEmail,
        'rol': newRol,
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cerrar sesión del nuevo usuario y restaurar sesión del admin
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: adminEmail!,
        password: adminPassword,
      );

      _showSuccessDialog("Usuario creado correctamente");
      _resetForm();
    } on FirebaseAuthException catch (e) {
      // Restaurar sesión del admin ante cualquier error
      try {
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: adminEmail!,
          password: adminPassword,
        );
      } catch (_) {}

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
      // Restaurar sesión del admin ante cualquier error
      try {
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: adminEmail!,
          password: adminPassword,
        );
      } catch (_) {}
      _showErrorDialog("Error inesperado: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<String?> _pedirPasswordAdmin() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.lock, color: Colors.green[700]),
          SizedBox(width: 10),
          Text("Confirmar identidad",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Para crear el usuario ingresa tu contraseña de administrador:",
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Tu contraseña",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text("Cancelar"),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () {
              if (controller.text.isEmpty) return;
              Navigator.pop(context, controller.text);
            },
            child: Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text("Confirmar Eliminación",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          "¿Estás seguro de eliminar a $userName?\nEsta acción desactivará su acceso al sistema.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .update({
        'activo': false,
        'eliminadoEn': FieldValue.serverTimestamp(),
      });
      _showSuccessDialog("Usuario desactivado correctamente.\nYa no podrá acceder al sistema.");
    } catch (e) {
      _showErrorDialog("Error al eliminar usuario: ${e.toString()}");
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(icon, color: iconColor, size: 28),
          SizedBox(width: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(message, style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    _resetForm();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                    onChanged: (value) {
                      setState(() => rolSeleccionado = value!);
                      setDialogState(() => rolSeleccionado = value!);
                    },
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
              child: Text("Agregar",
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _resetForm() {
    nombreController.clear();
    emailController.clear();
    passwordController.clear();
    setState(() => rolSeleccionado = "operador");
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
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error al cargar usuarios"));
                }

                // Mostrar solo usuarios activos
                final users = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['activo'] != false;
                }).toList();

                if (users.isEmpty) {
                  return Center(child: Text("No hay usuarios registrados"));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    return Card(
                      margin:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: Icon(Icons.person,
                            size: 40, color: _getRoleColor(data['rol'])),
                        title: Text(
                            data['nombre']?.toString() ?? 'Sin nombre',
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
                          icon:
                              Icon(Icons.delete, color: Colors.red, size: 28),
                          onPressed: () => _deleteUser(doc.id,
                              data['nombre']?.toString() ?? 'Usuario'),
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