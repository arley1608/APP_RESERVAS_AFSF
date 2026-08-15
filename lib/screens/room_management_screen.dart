import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class RoomManagementScreen extends StatefulWidget {
  @override
  _RoomManagementScreenState createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController precioController = TextEditingController();
  final TextEditingController capacidadController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  String selectedTipo = "Habitación Superior";
  String? editingId;

  bool esPorCupo = false;

  List<String> roomTypes = [
    "Habitación Superior",
    "Habitación Standard",
    "Cabaña",
    "Apartamento",
    "Zona de Camping",
    "Zona de Camping con Carpa",
    "Hamaca",
  ];

  @override
  void dispose() {
    nombreController.dispose();
    precioController.dispose();
    capacidadController.dispose();
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

  Future<void> guardarAlojamiento() async {
    if (nombreController.text.trim().isEmpty) {
      _showErrorDialog("El nombre es requerido");
      return;
    }
    final precio = double.tryParse(precioController.text.replaceAll(',', '.')) ?? 0;
    if (precio <= 0) {
      _showErrorDialog("Ingrese un precio válido mayor a cero");
      return;
    }
    final capacidad = int.tryParse(capacidadController.text.trim()) ?? 0;
    if (capacidad <= 0) {
      _showErrorDialog(esPorCupo
          ? "El cupo máximo debe ser mayor a 0"
          : "La capacidad debe ser mayor a 0");
      return;
    }

    try {
      final data = {
        'nombre': nombreController.text.trim(),
        'tipo': selectedTipo,
        'precio': precio,
        'capacidad': capacidad,
        'esPorCupo': esPorCupo,
        'descripcion': descripcionController.text.trim(),
      };

      if (editingId == null) {
        await _service.addAlojamiento(data);
        _showSuccessDialog("Alojamiento creado correctamente");
      } else {
        await _service.updateAlojamiento(editingId!, data);
        _showSuccessDialog("Alojamiento actualizado correctamente");
      }
      if (mounted) Navigator.of(context).pop(); // cierra la hoja del formulario
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
        title: Row(children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text("Confirmar eliminación", style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text("¿Estás seguro de eliminar este alojamiento?",
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
        await _service.deleteAlojamiento(id);
        _showSuccessDialog("Alojamiento eliminado correctamente");
      } catch (e) {
        _showErrorDialog("No se pudo eliminar: ${e.toString()}");
      }
    }
  }

  void _loadAlojamientoForEdit(Map<String, dynamic> data, String id) {
    editingId = id;
    nombreController.text = data['nombre'];
    final tipoGuardado = data['tipo']?.toString() ?? roomTypes.first;
    if (!roomTypes.contains(tipoGuardado)) {
      roomTypes.add(tipoGuardado);
    }
    selectedTipo = tipoGuardado;
    precioController.text = data['precio'].toString();
    capacidadController.text = data['capacidad'].toString();
    esPorCupo = data['esPorCupo'] == true;
    descripcionController.text = data['descripcion'];
  }

  void _resetForm() {
    nombreController.clear();
    precioController.clear();
    capacidadController.clear();
    descripcionController.clear();
    selectedTipo = "Habitación Superior";
    esPorCupo = false;
    editingId = null;
  }

  // Abre el formulario de crear/editar en una hoja que sube desde
  // abajo, dejando la lista con toda la pantalla disponible para
  // desplazarse. Si se pasan datos, precarga el formulario para editar.
  void _abrirFormulario({Map<String, dynamic>? data, String? id}) {
    if (data != null && id != null) {
      _loadAlojamientoForEdit(data, id);
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
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              // setModalState refresca SOLO la hoja (para que el
              // Dropdown/Switch se vean actualizados al tocarlos);
              // setState (del State de la pantalla) sigue actualizando
              // los mismos campos que usa guardarAlojamiento().
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
                              ? "Nuevo Alojamiento"
                              : "Editar Alojamiento",
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
                            onChanged: (value) {
                              setState(() => selectedTipo = value!);
                              setModalState(() {});
                            },
                            items: roomTypes
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type,
                                          style: TextStyle(fontSize: 16)),
                                    ))
                                .toList(),
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                            color: esPorCupo ? Colors.green[50] : null,
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Alojamiento por cupo',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Admite varias reservas simultáneas hasta un '
                              'cupo máximo de personas (ej. Zona de Camping '
                              'sin equipo). Si no aplica, déjalo desactivado.',
                              style: TextStyle(fontSize: 13),
                            ),
                            value: esPorCupo,
                            activeColor: Colors.green[700],
                            onChanged: (value) {
                              setState(() => esPorCupo = value);
                              setModalState(() {});
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: precioController,
                          decoration: InputDecoration(
                            labelText: esPorCupo ? "Precio por persona" : "Precio",
                            labelStyle: TextStyle(fontSize: 18),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: capacidadController,
                          decoration: InputDecoration(
                            labelText: esPorCupo
                                ? "Cupo máximo de personas"
                                : "Capacidad",
                            labelStyle: TextStyle(fontSize: 18),
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
                            labelStyle: TextStyle(fontSize: 18),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: guardarAlojamiento,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
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
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      // Si cerraron la hoja sin guardar (deslizando hacia abajo o
      // tocando fuera), limpiamos el formulario igual.
      if (mounted) setState(_resetForm);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión de Alojamientos",
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
        label: Text("Nuevo", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getAlojamientos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error al cargar los datos"));
          }
          final rooms = snapshot.data?.docs ?? [];
          if (rooms.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No hay alojamientos registrados.\nToca \"Nuevo\" para agregar el primero.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.only(bottom: 90), // espacio para el FAB
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final doc = rooms[index];
              final data = doc.data() as Map<String, dynamic>;
              final esCupo = data['esPorCupo'] == true;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(esCupo ? Icons.groups : Icons.room,
                      size: 36, color: Colors.green),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text("${data['tipo']} - ${data['nombre']}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                      ),
                      if (esCupo)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('POR CUPO',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800])),
                        ),
                    ],
                  ),
                  subtitle: Text(
                      "${esCupo ? 'Cupo' : 'Capacidad'}: ${data['capacidad']}  •  "
                      "\$${data['precio']}${esCupo ? '/persona' : ''}",
                      style: TextStyle(fontSize: 14)),
                  onTap: () => _abrirFormulario(data: data, id: doc.id),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => eliminarAlojamiento(doc.id),
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