import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomManagementScreen extends StatefulWidget {
  @override
  _RoomManagementScreenState createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController precioController = TextEditingController();
  final TextEditingController capacidadController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  String selectedTipo = "Habitación Superior";
  String? editingId;

  final List<String> roomTypes = [
    "Habitación Superior",
    "Habitación Standard",
    "Cabaña",
    "Apartamento",
    "Zona de Camping",
    "Zona de Camping con Carpa",
    "Hamaca",
  ];

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

  Future<void> guardarAlojamiento() async {
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

    final capacidad = int.tryParse(capacidadController.text.trim()) ?? 0;
    if (capacidad <= 0) {
      _showErrorDialog("La capacidad debe ser mayor a 0");
      return;
    }

    try {
      final alojamientoData = {
        'nombre': nombreController.text.trim(),
        'tipo': selectedTipo,
        'precio': precio,
        'capacidad': capacidad,
        'descripcion': descripcionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (editingId == null) {
        alojamientoData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('alojamientos')
            .add(alojamientoData);
        _showSuccessDialog("Alojamiento creado correctamente");
      } else {
        await FirebaseFirestore.instance
            .collection('alojamientos')
            .doc(editingId)
            .update(alojamientoData);
        _showSuccessDialog("Alojamiento actualizado correctamente");
      }

      _resetForm();
    } catch (e) {
      _showErrorDialog("No se pudo guardar el alojamiento: ${e.toString()}");
    }
  }

  Future<void> eliminarAlojamiento(String id) async {
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
        content: Text("¿Estás seguro de eliminar este alojamiento?",
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
            .collection('alojamientos')
            .doc(id)
            .delete();
        _showSuccessDialog("Alojamiento eliminado correctamente");
      } catch (e) {
        _showErrorDialog("No se pudo eliminar: ${e.toString()}");
      }
    }
  }

  void _loadAlojamientoForEdit(Map<String, dynamic> data, String id) {
    setState(() {
      editingId = id;
      nombreController.text = data['nombre'];
      selectedTipo = data['tipo'];
      precioController.text = data['precio'].toString();
      capacidadController.text = data['capacidad'].toString();
      descripcionController.text = data['descripcion'];
    });
  }

  void _resetForm() {
    setState(() {
      nombreController.clear();
      precioController.clear();
      capacidadController.clear();
      descripcionController.clear();
      selectedTipo = "Habitación Superior";
      editingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión de Alojamientos",
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
                    prefixIcon: Icon(Icons.room),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedTipo,
                    onChanged: (value) => setState(() => selectedTipo = value!),
                    items: roomTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type, style: TextStyle(fontSize: 16)),
                            ))
                        .toList(),
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
                  controller: capacidadController,
                  decoration: InputDecoration(
                    labelText: "Capacidad",
                    labelStyle: TextStyle(fontSize: 20),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
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
                  onPressed: guardarAlojamiento,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    editingId == null
                        ? "Guardar Alojamiento"
                        : "Actualizar Alojamiento",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('alojamientos')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error al cargar los datos"));
                }

                final rooms = snapshot.data?.docs ?? [];

                if (rooms.isEmpty) {
                  return Center(child: Text("No hay alojamientos registrados"));
                }

                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final doc = rooms[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading:
                            Icon(Icons.room, size: 40, color: Colors.green),
                        title: Text("${data['tipo']} - ${data['nombre']}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(
                            "Capacidad: ${data['capacidad']}\nPrecio: \$${data['precio']}\n${data['descripcion']}",
                            style: TextStyle(fontSize: 16)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _loadAlojamientoForEdit(data, doc.id),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => eliminarAlojamiento(doc.id),
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
