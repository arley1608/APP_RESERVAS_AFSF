import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── ALOJAMIENTOS ───────────────────────────────────────────
  Stream<QuerySnapshot> getAlojamientos() {
    return _db.collection('alojamientos').orderBy('nombre').snapshots();
  }

  Future<void> addAlojamiento(Map<String, dynamic> data) async {
    await _db.collection('alojamientos').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAlojamiento(String id, Map<String, dynamic> data) async {
    await _db.collection('alojamientos').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAlojamiento(String id) async {
    await _db.collection('alojamientos').doc(id).delete();
  }

  // ─── ACTIVIDADES ────────────────────────────────────────────
  Stream<QuerySnapshot> getActividades() {
    return _db.collection('actividades').orderBy('nombre').snapshots();
  }

  Future<void> addActividad(Map<String, dynamic> data) async {
    await _db.collection('actividades').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateActividad(String id, Map<String, dynamic> data) async {
    await _db.collection('actividades').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteActividad(String id) async {
    await _db.collection('actividades').doc(id).delete();
  }

  // ─── ALIMENTOS ──────────────────────────────────────────────
  Stream<QuerySnapshot> getAlimentos() {
    return _db.collection('alimentos').orderBy('nombre').snapshots();
  }

  Future<void> addAlimento(Map<String, dynamic> data) async {
    await _db.collection('alimentos').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAlimento(String id, Map<String, dynamic> data) async {
    await _db.collection('alimentos').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAlimento(String id) async {
    await _db.collection('alimentos').doc(id).delete();
  }

  // ─── RESERVAS ───────────────────────────────────────────────
  Stream<QuerySnapshot> getReservas() {
    return _db
        .collection('reservas')
        .orderBy('fechaEntrada', descending: false)
        .snapshots();
  }

  Future<void> updateReserva(String id, Map<String, dynamic> data) async {
    await _db.collection('reservas').doc(id).update({
      ...data,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ─── USUARIOS ───────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUsuario(String uid) async {
    final snapshot = await _db.collection('usuarios').doc(uid).get();
    if (snapshot.exists) {
      return snapshot.data() as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> updateUsuario(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}