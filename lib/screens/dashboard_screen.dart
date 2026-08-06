import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // La sesión se perdió justo al construir esta pantalla (token
      // expirado, sign-out en otra pestaña, etc.). En vez de crashear
      // con un unwrap forzado, regresamos a login de forma segura.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final uid = currentUser.uid;
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
                      fontSize: 28,
                      fontWeight: FontWeight.bold));
            }
            final nombre = snapshot.data?['nombre'] ?? 'Usuario';
            return Text("Bienvenido, $nombre",
                style: TextStyle(
                    fontSize: 28,
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
                    height: 180,
                  ),
                  SizedBox(height: 16),

                  // Panel resumen del día (admin y recepcionista)
                  if (rol == "admin" || rol == "recepcionista")
                    _buildResumenDia(),

                  SizedBox(height: 16),

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

  Widget _buildResumenDia() {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('reservas').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: LinearProgressIndicator(color: Colors.white),
          );
        }

        final docs = snapshot.data!.docs;
        int llegadasHoy = 0;
        int salidasHoy = 0;
        int activasAhora = 0;
        int pendientesTotal = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final estado = data['estado']?.toString() ?? '';

          if (data['fechaEntrada'] != null) {
            final entrada =
                (data['fechaEntrada'] as Timestamp).toDate();
            final entradaSinHora =
                DateTime(entrada.year, entrada.month, entrada.day);
            if (entradaSinHora.isAtSameMomentAs(hoySinHora) &&
                estado != 'cancelada') {
              llegadasHoy++;
            }
          }

          if (data['fechaSalida'] != null) {
            final salida = (data['fechaSalida'] as Timestamp).toDate();
            final salidaSinHora =
                DateTime(salida.year, salida.month, salida.day);
            if (salidaSinHora.isAtSameMomentAs(hoySinHora) &&
                estado == 'activa') {
              salidasHoy++;
            }
          }

          if (estado == 'activa') activasAhora++;
          if (estado == 'pendiente' || estado == 'confirmada') {
            pendientesTotal++;
          }
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                DateFormat('EEEE, d MMMM yyyy', 'es').format(hoy),
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildBadge(
                      icon: Icons.login,
                      valor: llegadasHoy,
                      label: 'Llegadas\nhoy',
                      color: Colors.teal,
                      urgente: llegadasHoy > 0,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildBadge(
                      icon: Icons.logout,
                      valor: salidasHoy,
                      label: 'Salidas\nhoy',
                      color: Colors.blue[700]!,
                      urgente: salidasHoy > 0,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildBadge(
                      icon: Icons.hotel,
                      valor: activasAhora,
                      label: 'Activas\nahora',
                      color: Colors.green[800]!,
                      urgente: false,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildBadge(
                      icon: Icons.pending,
                      valor: pendientesTotal,
                      label: 'Por\nconfirmar',
                      color: Colors.orange[800]!,
                      urgente: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required int valor,
    required String label,
    required Color color,
    required bool urgente,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: urgente ? color : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgente ? color : Colors.white.withOpacity(0.3),
          width: urgente ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          SizedBox(height: 4),
          Text(
            '$valor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}