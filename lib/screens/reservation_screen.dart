import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReservationScreen extends StatefulWidget {
  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _huespedesController =
      TextEditingController(text: '1');

  DateTime? _fechaEntrada;
  DateTime? _fechaSalida;
  String? _selectedAlojamientoId;
  Map<String, bool> _selectedActivities = {};
  Map<String, bool> _selectedFoods = {};

  // Nuevas variables para mejoras
  int _noches = 0;
  bool _disponibilidadVerificada = false;
  bool _alojamientoDisponible = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _alojamientos = [];
  List<Map<String, dynamic>> _actividades = [];
  List<Map<String, dynamic>> _alimentos = [];

  @override
  void initState() {
    super.initState();
    _loadAlojamientos();
    _loadActividades();
    _loadAlimentos();
  }

  Future<void> _loadAlojamientos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('alojamientos').get();
    setState(() {
      _alojamientos =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Future<void> _loadActividades() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('actividades').get();
    setState(() {
      _actividades =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Future<void> _loadAlimentos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('alimentos').get();
    setState(() {
      _alimentos =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Future<void> _selectFecha(BuildContext context, bool isEntrada) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isEntrada
          ? DateTime.now()
          : (_fechaEntrada ?? DateTime.now().add(Duration(days: 1))),
      firstDate: isEntrada ? DateTime.now() : (_fechaEntrada ?? DateTime.now()),
      lastDate: DateTime(DateTime.now().year + 1),
    );

    if (picked != null) {
      setState(() {
        if (isEntrada) {
          _fechaEntrada = picked;
          if (_fechaSalida == null || !_fechaSalida!.isAfter(picked)) {
            _fechaSalida = picked.add(Duration(days: 1));
          }
        } else {
          _fechaSalida = picked;
        }

        _noches = _fechaSalida!.difference(_fechaEntrada!).inDays;
        _disponibilidadVerificada = false;
      });

      if (_selectedAlojamientoId != null) {
        await _verificarDisponibilidad();
      }
    }
  }

  Future<bool> _isAlojamientoDisponible(String alojamientoId) async {
    if (_fechaEntrada == null || _fechaSalida == null) return false;

    final reservasSnapshot = await FirebaseFirestore.instance
        .collection('reservas')
        .where('alojamientoId', isEqualTo: alojamientoId)
        .get();

    for (var reserva in reservasSnapshot.docs) {
      final fechaInicioReserva =
          (reserva.data()['fechaEntrada'] as Timestamp).toDate();
      final fechaFinReserva =
          (reserva.data()['fechaSalida'] as Timestamp).toDate();

      if ((_fechaEntrada!.isBefore(fechaFinReserva) &&
          _fechaSalida!.isAfter(fechaInicioReserva))) {
        return false;
      }
    }
    return true;
  }

  Future<void> _verificarDisponibilidad() async {
    if (_fechaEntrada == null ||
        _fechaSalida == null ||
        _selectedAlojamientoId == null) return;

    setState(() {
      _isLoading = true;
      _disponibilidadVerificada = false;
    });

    final disponible = await _isAlojamientoDisponible(_selectedAlojamientoId!);

    setState(() {
      _alojamientoDisponible = disponible;
      _disponibilidadVerificada = true;
      _isLoading = false;
    });
  }

  Widget _buildResumenReserva() {
    if (_fechaEntrada == null || _fechaSalida == null) return SizedBox();

    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen de Reserva',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
                '• $_noches noche(s): ${DateFormat('dd/MM').format(_fechaEntrada!)} - ${DateFormat('dd/MM').format(_fechaSalida!)}'),
            if (_selectedAlojamientoId != null) ...[
              SizedBox(height: 5),
              Text(
                  '• Alojamiento: ${_alojamientos.firstWhere((a) => a['id'] == _selectedAlojamientoId)['nombre']}'),
            ],
            if (_disponibilidadVerificada) ...[
              SizedBox(height: 5),
              Text(
                '• Disponibilidad: ${_alojamientoDisponible ? 'DISPONIBLE ✅' : 'NO DISPONIBLE ❌'}',
                style: TextStyle(
                    color: _alojamientoDisponible ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold),
              ),
            ],
            SizedBox(height: 10),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _verificarDisponibilidad,
                    child: Text('Verificar Disponibilidad'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearReserva() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaEntrada == null || _fechaSalida == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Seleccione fechas válidas')));
      return;
    }

    if (_selectedAlojamientoId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Seleccione un alojamiento')));
      return;
    }

    if (!_disponibilidadVerificada || !_alojamientoDisponible) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verifique la disponibilidad primero')));
      return;
    }

    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Reserva'),
        content: Text('¿Está seguro de crear esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _isLoading = true);

    try {
      final alojamientoDoc = await FirebaseFirestore.instance
          .collection('alojamientos')
          .doc(_selectedAlojamientoId)
          .get();

      final precioPorNoche = alojamientoDoc.data()!['precio'] as double;
      final totalAlojamiento = precioPorNoche * _noches;

      // Calcular total actividades
      double totalActividades = 0;
      final actividadesSeleccionadas = _selectedActivities.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      for (var actividadId in actividadesSeleccionadas) {
        final actividad =
            _actividades.firstWhere((a) => a['id'] == actividadId);
        totalActividades += actividad['precio'];
      }

      // Calcular total alimentos
      double totalAlimentos = 0;
      final alimentosSeleccionados = _selectedFoods.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      for (var alimentoId in alimentosSeleccionados) {
        final alimento = _alimentos.firstWhere((a) => a['id'] == alimentoId);
        totalAlimentos += alimento['precio'];
      }

      // Crear reserva
      final reservaData = {
        'usuarioId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'titular': _nombreController.text,
        'email': _emailController.text,
        'telefono': _telefonoController.text,
        'alojamientoId': _selectedAlojamientoId,
        'alojamientoNombre': alojamientoDoc.data()!['nombre'],
        'fechaEntrada': Timestamp.fromDate(_fechaEntrada!),
        'fechaSalida': Timestamp.fromDate(_fechaSalida!),
        'noches': _noches,
        'huespedes': int.parse(_huespedesController.text),
        'actividades': actividadesSeleccionadas,
        'alimentos': alimentosSeleccionados,
        'totalAlojamiento': totalAlojamiento,
        'totalActividades': totalActividades,
        'totalAlimentos': totalAlimentos,
        'total': totalAlojamiento + totalActividades + totalAlimentos,
        'fechaCreacion': Timestamp.now(),
        'estado': 'confirmada',
      };

      await FirebaseFirestore.instance.collection('reservas').add(reservaData);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Reserva creada exitosamente')));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al crear reserva: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva Reserva', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Datos personales
                    Text('Datos del Titular',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(labelText: 'Nombre Completo'),
                      validator: (value) =>
                          value!.isEmpty ? 'Ingrese su nombre' : null,
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value!.isEmpty ? 'Ingrese su email' : null,
                    ),
                    TextFormField(
                      controller: _telefonoController,
                      decoration: InputDecoration(labelText: 'Teléfono'),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value!.isEmpty ? 'Ingrese su teléfono' : null,
                    ),
                    SizedBox(height: 20),

                    // Fechas
                    Text('Fechas de Estancia',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _selectFecha(context, true),
                            child: Text(_fechaEntrada == null
                                ? 'Seleccionar Entrada'
                                : DateFormat('dd/MM/yyyy')
                                    .format(_fechaEntrada!)),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _selectFecha(context, false),
                            child: Text(_fechaSalida == null
                                ? 'Seleccionar Salida'
                                : DateFormat('dd/MM/yyyy')
                                    .format(_fechaSalida!)),
                          ),
                        ),
                      ],
                    ),
                    _buildResumenReserva(),
                    SizedBox(height: 20),

                    // Alojamiento
                    Text('Alojamiento',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedAlojamientoId,
                      hint: Text('Seleccione un alojamiento'),
                      items: _alojamientos.map((alojamiento) {
                        return DropdownMenuItem<String>(
                          value: alojamiento['id'],
                          child: Text(
                              '${alojamiento['nombre']} - \$${alojamiento['precio']}/noche'),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedAlojamientoId = value;
                          _disponibilidadVerificada = false;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione un alojamiento' : null,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _huespedesController,
                      decoration:
                          InputDecoration(labelText: 'Número de Huéspedes'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty)
                          return 'Ingrese el número de huéspedes';
                        if (int.tryParse(value) == null ||
                            int.parse(value) <= 0) {
                          return 'Ingrese un número válido';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Actividades
                    Text('Actividades',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    ..._actividades.map((actividad) {
                      return CheckboxListTile(
                        title: Text(
                            '${actividad['nombre']} - \$${actividad['precio']}'),
                        value: _selectedActivities[actividad['id']] ?? false,
                        onChanged: (bool? value) {
                          setState(() {
                            _selectedActivities[actividad['id']] =
                                value ?? false;
                          });
                        },
                      );
                    }).toList(),
                    SizedBox(height: 20),

                    // Alimentos
                    Text('Alimentos',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    ..._alimentos.map((alimento) {
                      return CheckboxListTile(
                        title: Text(
                            '${alimento['nombre']} - \$${alimento['precio']}'),
                        value: _selectedFoods[alimento['id']] ?? false,
                        onChanged: (bool? value) {
                          setState(() {
                            _selectedFoods[alimento['id']] = value ?? false;
                          });
                        },
                      );
                    }).toList(),
                    SizedBox(height: 30),

                    // Botón de reserva
                    ElevatedButton(
                      onPressed: _crearReserva,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.green[700],
                      ),
                      child: Text('Confirmar Reserva',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _huespedesController.dispose();
    super.dispose();
  }
}
