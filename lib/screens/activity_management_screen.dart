import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityManagementScreen extends StatefulWidget {
  @override
  _ActivityManagementScreenState createState() =>
      _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController precioController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  String? editingId;

  void _showSuccessDialog(String message) {
    _showDialog(
      title: "Éxito",
      message: message,
      icon: Icons.check_circle,
      iconColor: Colors.green,
    );
  }

  void _showErrorDialog(String message) {
    _showDialog(
      title: "Error",
      message: message,
      icon: Icons.error,
      iconColor: Colors.red,
    );
  }

  void _showDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
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

  Future<void> guardarActividad() async {
    if (nombreController.text.trim().isEmpty) {
      _showErrorDialog("El nombre es requerido");
      return;
    }

    final precio =
        double.tryParse(precioController.text.replaceAll(',', '.')) ?? 0;
    if (precio <= 0) {
      _showErrorDialog("Ingrese un precio válido mayor a cero");
      return;
    }

    if (descripcionController.text.trim().isEmpty) {
      _showErrorDialog("La descripción es requerida");
      return;
    }

    try {
      final actividadData = {
        'nombre': nombreController.text.trim(),
        'precio': precio,
        'descripcion': descripcionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (editingId == null) {
        actividadData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('actividades')
            .add(actividadData);
        _showSuccessDialog("Actividad creada correctamente");
      } else {
        await FirebaseFirestore.instance
            .collection('actividades')
            .doc(editingId)
            .update(actividadData);
        _showSuccessDialog("Actividad actualizada correctamente");
      }

      _resetForm();
    } catch (e) {
      _showErrorDialog("No se pudo guardar la actividad: ${e.toString()}");
    }
  }

  Future<void> eliminarActividad(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Confirmar eliminación",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("¿Estás seguro de eliminar esta actividad?",
            style: TextStyle(fontSize: 18)),
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

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('actividades')
            .doc(id)
            .delete();
        _showSuccessDialog("Actividad eliminada correctamente");
      } catch (e) {
        _showErrorDialog("No se pudo eliminar: ${e.toString()}");
      }
    }
  }

  void _loadActividadForEdit(Map<String, dynamic> data, String id) {
    setState(() {
      editingId = id;
      nombreController.text = data['nombre'];
      precioController.text = data['precio'].toString();
      descripcionController.text = data['descripcion'];
    });
  }

  void _resetForm() {
    setState(() {
      nombreController.clear();
      precioController.clear();
      descripcionController.clear();
      editingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión de Actividades",
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
            child: Column(
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: "Nombre",
                    labelStyle: TextStyle(fontSize: 20),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.emoji_events),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: precioController,
                  decoration: InputDecoration(
                    labelText: "Precio",
                    labelStyle: TextStyle(fontSize: 20),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descripcionController,
                  decoration: InputDecoration(
                    labelText: "Descripción",
                    labelStyle: TextStyle(fontSize: 20),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: guardarActividad,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    editingId == null
                        ? "Guardar Actividad"
                        : "Actualizar Actividad",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('actividades')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error al cargar los datos"));
                }

                final activities = snapshot.data?.docs ?? [];

                if (activities.isEmpty) {
                  return Center(child: Text("No hay actividades registradas"));
                }

                return ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final doc = activities[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: Icon(Icons.sports_soccer,
                            size: 40, color: Colors.green),
                        title: Text(data['nombre'],
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(
                            "Precio: \$${data['precio']}\n${data['descripcion']}",
                            style: TextStyle(fontSize: 16)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _loadActividadForEdit(data, doc.id),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => eliminarActividad(doc.id),
                            ),
                          ],
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
}
