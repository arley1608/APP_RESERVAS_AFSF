import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'user_management_screen.dart';
import 'room_management_screen.dart';
import 'activity_management_screen.dart'; // Importa la nueva pantalla de actividades
import 'food_management_screen.dart'; // Importa la nueva pantalla de alimentos

class DashboardScreen extends StatelessWidget {
  final String rol;

  DashboardScreen({required this.rol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: Icon(Icons.logout, size: 40, color: Colors.white),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          },
        ),
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData ||
                snapshot.connectionState == ConnectionState.waiting) {
              return Text("Bienvenido",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      fontWeight: FontWeight.bold));
            }
            if (snapshot.data == null || snapshot.data!.data() == null) {
              return Text("Bienvenido",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      fontWeight: FontWeight.bold));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            return Text("Bienvenido, ${data['nombre'] ?? 'Usuario'}",
                style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Colors.white));
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.person, size: 40, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[700]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/images/fondo_inferior.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/logo_colores.png",
                  height: 220,
                ),
                SizedBox(height: 40),
                if (rol == "admin" || rol == "operador")
                  _buildButton(context, "Nueva Reserva", Icons.add, () {}),
                if (rol == "admin" || rol == "operador")
                  _buildButton(context, "Editar Reserva", Icons.edit, () {}),
                if (rol == "admin" || rol == "recepcionista")
                  _buildButton(
                      context, "Gestionar Reservas", Icons.visibility, () {}),
                if (rol == "admin")
                  _buildButton(context, "Gestión de Usuarios", Icons.people,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UserManagementScreen()),
                    );
                  }),
                if (rol == "admin")
                  _buildButton(
                      context, "Gestión de Alojamientos", Icons.business, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RoomManagementScreen()),
                    );
                  }),
                if (rol == "admin")
                  _buildButton(
                      context, "Gestión de Actividades", Icons.assignment, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ActivityManagementScreen()),
                    );
                  }),
                if (rol == "admin")
                  _buildButton(
                      context, "Gestión de Alimentos", Icons.restaurant, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => FoodManagementScreen()),
                    );
                  }),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Versión 1.0.0",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text, IconData icon,
      VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 70,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 30, color: Colors.white),
          label: Text(text,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
