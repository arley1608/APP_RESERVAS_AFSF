import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'reservation_screen.dart';
import 'user_management_screen.dart';
import 'room_management_screen.dart';
import 'activity_management_screen.dart';
import 'food_management_screen.dart';
import 'edit_reservation_screen.dart';
import 'reservation_management_screen.dart';
import '../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  final String rol;

  DashboardScreen({required this.rol});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final firestoreService = FirestoreService();

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
        title: FutureBuilder<Map<String, dynamic>?>(
          future: firestoreService.getUsuario(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData ||
                snapshot.connectionState == ConnectionState.waiting) {
              return Text("Bienvenido",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      fontWeight: FontWeight.bold));
            }
            final nombre = snapshot.data?['nombre'] ?? 'Usuario';
            return Text("Bienvenido, $nombre",
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
                colors: [Colors.green[700]!, Colors.orange],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Image.asset(
                    "assets/images/logo_colores.png",
                    height: 220,
                  ),
                  SizedBox(height: 40),

                  // Admin y operador pueden crear reservas
                  if (rol == "admin" || rol == "operador")
                    _buildButton(context, "Nueva Reserva", Icons.add, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ReservationScreen()),
                      );
                    }),

                  // Admin y operador pueden editar sus reservas
                  if (rol == "admin" || rol == "operador")
                    _buildButton(context, "Editar Reservas", Icons.edit, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditReservationScreen(
                                  rol: rol,
                                  uid: uid,
                                )),
                      );
                    }),

                  // Admin y recepcionista pueden gestionar todas las reservas
                  if (rol == "admin" || rol == "recepcionista")
                    _buildButton(
                        context, "Gestionar Reservas", Icons.dashboard, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ReservationManagementScreen()),
                      );
                    }),

                  // Solo admin
                  if (rol == "admin")
                    _buildButton(
                        context, "Gestión de Usuarios", Icons.people, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => UserManagementScreen()),
                      );
                    }),

                  if (rol == "admin")
                    _buildButton(context, "Gestión de Alojamientos",
                        Icons.business, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RoomManagementScreen()),
                      );
                    }),

                  if (rol == "admin")
                    _buildButton(context, "Gestión de Actividades",
                        Icons.assignment, () {
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