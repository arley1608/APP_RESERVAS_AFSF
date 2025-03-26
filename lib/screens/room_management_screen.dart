import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  File? _image;
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

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> guardarAlojamiento() async {
    String precioTexto = precioController.text.replaceAll(',', '.');
    double? nuevoPrecio = double.tryParse(precioTexto);
    int? nuevaCapacidad = int.tryParse(capacidadController.text.trim());

    if (nuevoPrecio == null ||
        nuevaCapacidad == null ||
        nombreController.text.trim().isEmpty ||
        descripcionController.text.trim().isEmpty) {
      _showDialog("Error", "Ingrese valores válidos en todos los campos.");
      return;
    }

    if (editingId == null) {
      await FirebaseFirestore.instance.collection('alojamientos').add({
        'nombre': nombreController.text.trim(),
        'tipo': selectedTipo,
        'precio': nuevoPrecio,
        'capacidad': nuevaCapacidad,
        'descripcion': descripcionController.text.trim(),
        'imagen': _image != null ? _image!.path : "",
      });
    } else {
      await FirebaseFirestore.instance
          .collection('alojamientos')
          .doc(editingId)
          .update({
        'nombre': nombreController.text.trim(),
        'tipo': selectedTipo,
        'precio': nuevoPrecio,
        'capacidad': nuevaCapacidad,
        'descripcion': descripcionController.text.trim(),
        'imagen': _image != null ? _image!.path : "",
      });
      setState(() {
        editingId = null;
      });
    }

    _showDialog("Éxito", "Alojamiento guardado correctamente.");
  }

  Future<void> eliminarAlojamiento(String id) async {
    await FirebaseFirestore.instance
        .collection('alojamientos')
        .doc(id)
        .delete();
    _showDialog("Éxito", "Alojamiento eliminado correctamente.");
  }

  void _showDialog(String title, String message) {
    IconData icon = title == "Éxito" ? Icons.check_circle : Icons.error;
    Color iconColor = title == "Éxito" ? Colors.green : Colors.red;
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
                    )),
                DropdownButton<String>(
                  value: selectedTipo,
                  onChanged: (value) {
                    setState(() {
                      selectedTipo = value!;
                    });
                  },
                  items: roomTypes
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                ),
                TextField(
                    controller: precioController,
                    decoration: InputDecoration(
                        labelText: "Precio",
                        labelStyle: TextStyle(fontSize: 20)),
                    keyboardType: TextInputType.number),
                TextField(
                    controller: capacidadController,
                    decoration: InputDecoration(
                        labelText: "Capacidad",
                        labelStyle: TextStyle(fontSize: 20)),
                    keyboardType: TextInputType.number),
                TextField(
                    controller: descripcionController,
                    decoration: InputDecoration(
                        labelText: "Descripción",
                        labelStyle: TextStyle(fontSize: 20)),
                    maxLines: 2),
                SizedBox(height: 10),
                _image != null
                    ? Image.file(_image!, height: 100)
                    : Container(height: 100, color: Colors.grey[300]),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.image),
                  label: Text("Seleccionar Nueva Imagen"),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: guardarAlojamiento,
                  child: Text("Guardar Alojamiento",
                      style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('alojamientos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: (data['imagen'] != null &&
                                data['imagen'].isNotEmpty)
                            ? Image.network(data['imagen'],
                                width: 50, height: 50, fit: BoxFit.cover)
                            : Icon(Icons.image_not_supported,
                                size: 50, color: Colors.grey),
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
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
