import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class RoomManagementScreen extends StatefulWidget {
  @override
  _RoomManagementScreenState createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _capacidadController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  String _selectedTipo = "Habitación Superior";
  File? _image;
  String? _editingId;
  bool _isLoading = false;

  final List<String> _roomTypes = [
    "Habitación Superior",
    "Habitación Standard",
    "Cabaña",
    "Apartamento",
    "Zona de Camping",
    "Zona de Camping con Carpa",
    "Hamaca",
  ];

  // --- Funciones Mejoradas ---

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      setState(() => _isLoading = true);
      final ref = FirebaseStorage.instance
          .ref()
          .child('alojamientos/${DateTime.now().millisecondsSinceEpoch}');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarAlojamiento() async {
    if (_isLoading) return;

    // Validación de campos
    final nombre = _nombreController.text.trim();
    final descripcion = _descripcionController.text.trim();
    final precio =
        double.tryParse(_precioController.text.replaceAll(',', '.')) ?? 0;
    final capacidad = int.tryParse(_capacidadController.text.trim()) ?? 0;

    if (nombre.isEmpty ||
        descripcion.isEmpty ||
        precio <= 0 ||
        capacidad <= 0) {
      _showDialog(
          "Error", "Por favor, complete todos los campos correctamente.");
      return;
    }

    try {
      setState(() => _isLoading = true);

      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImage(_image!);
      } else if (_editingId != null) {
        // Mantener la imagen existente si no se selecciona una nueva
        final doc = await FirebaseFirestore.instance
            .collection('alojamientos')
            .doc(_editingId)
            .get();
        imageUrl = doc['imagen'];
      }

      final alojamientoData = {
        'nombre': nombre,
        'tipo': _selectedTipo,
        'precio': precio,
        'capacidad': capacidad,
        'descripcion': descripcion,
        'imagen': imageUrl ?? "",
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_editingId == null) {
        await FirebaseFirestore.instance
            .collection('alojamientos')
            .add(alojamientoData);
      } else {
        await FirebaseFirestore.instance
            .collection('alojamientos')
            .doc(_editingId)
            .update(alojamientoData);
      }

      _showDialog("Éxito", "Alojamiento guardado correctamente.");
      _clearForm();
    } catch (e) {
      _showDialog("Error", "Ocurrió un error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarAlojamiento(String id) async {
    try {
      setState(() => _isLoading = true);
      await FirebaseFirestore.instance
          .collection('alojamientos')
          .doc(id)
          .delete();
      _showDialog("Éxito", "Alojamiento eliminado correctamente.");
    } catch (e) {
      _showDialog("Error", "No se pudo eliminar: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadAlojamientoForEdit(Map<String, dynamic> data, String id) {
    setState(() {
      _editingId = id;
      _nombreController.text = data['nombre'];
      _selectedTipo = data['tipo'];
      _precioController.text = data['precio'].toString();
      _capacidadController.text = data['capacidad'].toString();
      _descripcionController.text = data['descripcion'];
    });
  }

  void _clearForm() {
    _nombreController.clear();
    _precioController.clear();
    _capacidadController.clear();
    _descripcionController.clear();
    setState(() {
      _image = null;
      _editingId = null;
      _selectedTipo = _roomTypes.first;
    });
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              title == "Éxito" ? Icons.check_circle : Icons.error,
              color: title == "Éxito" ? Colors.green : Colors.red,
            ),
            SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  // --- UI Mejorada ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión de Alojamientos",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nombreController,
                          decoration: InputDecoration(labelText: "Nombre"),
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedTipo,
                          items: _roomTypes
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedTipo = value!),
                          decoration: InputDecoration(labelText: "Tipo"),
                        ),
                        TextField(
                          controller: _precioController,
                          decoration: InputDecoration(labelText: "Precio"),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                        ),
                        TextField(
                          controller: _capacidadController,
                          decoration: InputDecoration(labelText: "Capacidad"),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          controller: _descripcionController,
                          decoration: InputDecoration(labelText: "Descripción"),
                          maxLines: 3,
                        ),
                        SizedBox(height: 16),
                        _image != null
                            ? Image.file(_image!,
                                height: 150, fit: BoxFit.cover)
                            : Container(
                                height: 150,
                                color: Colors.grey[200],
                                child: Icon(Icons.image, size: 50),
                              ),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(Icons.photo_library),
                          label: Text("Seleccionar imagen"),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _guardarAlojamiento,
                          child: Text(
                              _editingId == null ? "Guardar" : "Actualizar"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                        ),
                        if (_editingId != null) ...[
                          SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _clearForm,
                            child: Text("Cancelar"),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Divider(height: 1),
                Expanded(
                  flex: 3,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('alojamientos')
                        .orderBy('updatedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: data['imagen']?.isNotEmpty == true
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        data['imagen'],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(Icons.image_not_supported, size: 50),
                              title: Text(data['nombre'],
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['tipo']),
                                  Text("Capacidad: ${data['capacidad']}"),
                                  Text(
                                      "Precio: ${NumberFormat.currency(locale: 'es').format(data['precio'])}"),
                                ],
                              ),
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
                                    onPressed: () =>
                                        _eliminarAlojamiento(doc.id),
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

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _capacidadController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}
