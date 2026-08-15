import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class ActivityManagementScreen extends StatefulWidget {
  @override
  _ActivityManagementScreenState createState() =>
      _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController precioController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  String? editingId;

  @override
  void dispose() {
    nombreController.dispose();
    precioController.dispose();
    descripcionController.dispose();
    super.dispose();
  }

  void _showSuccessDialog(String message) => _showDialog(
      title: "Éxito", message: message, icon: Icons.check_circle, iconColor: Colors.green);

  void _showErrorDialog(String message) => _showDialog(
      title: "Error", message: message, icon: Icons.error, iconColor: Colors.red);

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
        content: Text(message, style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  Future<void> guardarActividad() async {
    if (nombreController.text.trim().isEmpty) {
      _showErrorDialog("El nombre es requerido");
      return;
    }
    final precio = double.tryParse(precioController.text.replaceAll(',', '.')) ?? 0;
    if (precio <= 0) {
      _showErrorDialog("Ingrese un precio válido mayor a cero");
      return;
    }
    if (descripcionController.text.trim().isEmpty) {
      _showErrorDialog("La descripción es requerida");
      return;
    }

    try {
      final data = {
        'nombre': nombreController.text.trim(),
        'precio': precio,
        'descripcion': descripcionController.text.trim(),
      };

      if (editingId == null) {
        await _service.addActividad(data);
        _showSuccessDialog("Actividad creada correctamente");
      } else {
        await _service.updateActividad(editingId!, data);
        _showSuccessDialog("Actividad actualizada correctamente");
      }
      if (mounted) Navigator.of(context).pop();
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
        title: Row(children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text("Confirmar eliminación", style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text("¿Estás seguro de eliminar esta actividad?",
            style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteActividad(id);
        _showSuccessDialog("Actividad eliminada correctamente");
      } catch (e) {
        _showErrorDialog("No se pudo eliminar: ${e.toString()}");
      }
    }
  }

  void _loadActividadForEdit(Map<String, dynamic> data, String id) {
    editingId = id;
    nombreController.text = data['nombre'];
    precioController.text = data['precio'].toString();
    descripcionController.text = data['descripcion'];
  }

  void _resetForm() {
    nombreController.clear();
    precioController.clear();
    descripcionController.clear();
    editingId = null;
  }

  void _abrirFormulario({Map<String, dynamic>? data, String? id}) {
    if (data != null && id != null) {
      _loadActividadForEdit(data, id);
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Text(
                          editingId == null
                              ? "Nueva Actividad"
                              : "Editar Actividad",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: nombreController,
                          decoration: InputDecoration(
                            labelText: "Nombre",
                            labelStyle: TextStyle(fontSize: 18),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.emoji_events),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: precioController,
                          decoration: InputDecoration(
                            labelText: "Precio",
                            labelStyle: TextStyle(fontSize: 18),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: descripcionController,
                          decoration: InputDecoration(
                            labelText: "Descripción",
                            labelStyle: TextStyle(fontSize: 18),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: guardarActividad,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
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
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(_resetForm);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión de Actividades",
            style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 30, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: Colors.green[700],
        icon: Icon(Icons.add, color: Colors.white),
        label: Text("Nueva", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getActividades(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error al cargar los datos"));
          }
          final activities = snapshot.data?.docs ?? [];
          if (activities.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No hay actividades registradas.\nToca \"Nueva\" para agregar la primera.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.only(bottom: 90),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final doc = activities[index];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading:
                      Icon(Icons.sports_soccer, size: 36, color: Colors.green),
                  title: Text(data['nombre'],
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  subtitle: Text("\$${data['precio']}",
                      style: TextStyle(fontSize: 14)),
                  onTap: () => _abrirFormulario(data: data, id: doc.id),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => eliminarActividad(doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}