import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String?> getUserRole(String uid) async {
    final snapshot = await _db.collection('usuarios').doc(uid).get();
    if (snapshot.exists) {
      return snapshot['rol'] as String?;
    }
    return null;
  }

  Future<void> addUser(
      String uid, String nombre, String email, String rol) async {
    await _db.collection('usuarios').doc(uid).set({
      'nombre': nombre,
      'email': email,
      'rol': rol,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('usuarios').doc(userId).delete();
  }
}