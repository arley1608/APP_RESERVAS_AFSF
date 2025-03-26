import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener el rol de un usuario
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot snapshot =
          await _db.collection('usuarios').doc(uid).get();
      if (snapshot.exists) {
        return snapshot['rol'];
      }
      return null;
    } catch (e) {
      print("🔥 Error al obtener rol del usuario: $e");
      return null;
    }
  }

  // Agregar un usuario a Firestore
  Future<void> addUser(
      String uid, String nombre, String email, String rol) async {
    try {
      await _db.collection('usuarios').doc(uid).set({
        'nombre': nombre,
        'email': email,
        'rol': rol,
      });
      print("✅ Usuario agregado con éxito");
    } catch (e) {
      print("🔥 Error al agregar usuario: $e");
    }
  }

  // Eliminar usuario
  Future<void> deleteUser(String userId) async {
    try {
      await _db.collection('usuarios').doc(userId).delete();
      print("✅ Usuario eliminado correctamente");
    } catch (e) {
      print("🔥 Error al eliminar usuario: $e");
    }
  }
}
