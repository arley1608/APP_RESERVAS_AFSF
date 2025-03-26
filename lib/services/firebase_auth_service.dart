import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Iniciar sesión con email y contraseña
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return userCredential.user;
    } catch (e) {
      print("Error al iniciar sesión: $e");
      return null;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Obtener el rol del usuario desde Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot snapshot =
          await _db.collection('usuarios').doc(uid).get();
      if (snapshot.exists) {
        return snapshot['rol'];
      }
      return null;
    } catch (e) {
      print("Error al obtener rol del usuario: $e");
      return null;
    }
  }
}
