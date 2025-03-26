import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔹 Obtener habitaciones en tiempo real
  Stream<QuerySnapshot> getHabitaciones() {
    return _db.collection('habitaciones').snapshots();
  }

  // 🔹 Agregar una nueva habitación
  Future<void> addHabitacion(String numero, String tipo, double precio) async {
    await _db.collection('habitaciones').add(
        {'numero': numero, 'tipo': tipo, 'precio': precio, 'disponible': true});
  }

  // 🔹 Editar una habitación
  Future<void> updateHabitacion(String id, Map<String, dynamic> data) async {
    await _db.collection('habitaciones').doc(id).update(data);
  }

  // 🔹 Eliminar una habitación
  Future<void> deleteHabitacion(String id) async {
    await _db.collection('habitaciones').doc(id).delete();
  }
}
