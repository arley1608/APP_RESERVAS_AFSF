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
  String? _selectedTipoAlojamiento;
  bool _tipoSeleccionado = false;
  Map<String, int> _selectedActividades = {};
  String? _selectedTipoAlimento;
  bool _tipoAlimentoSeleccionado = false;
  List<Map<String, dynamic>> _alimentos = [];
  List<String> _tiposAlimento = [];
  Map<String, int> _selectedAlimentos = {};
  int _noches = 0;
  bool _disponibilidadVerificada = false;
  bool _alojamientoDisponible = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _alojamientos = [];
  List<String> _tiposAlojamiento = [];
  List<Map<String, dynamic>> _actividades = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait(
          [_loadAlojamientos(), _loadActividades(), _loadAlimentos()]);

      setState(() {
        _alojamientos = results[0];
        _actividades = results[1];
        _alimentos = results[2];
        _isLoading = false;
      });
    } catch (e) {
      _showError("Error al cargar datos", e);
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadAlojamientos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('alojamientos').get();
    final tipos = <String>{};
    final alojamientos = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      alojamientos.add({'id': doc.id, ...data});
      if (data['tipo'] != null && data['tipo'].toString().isNotEmpty) {
        tipos.add(data['tipo'].toString());
      }
    }

    setState(() {
      _tiposAlojamiento = tipos.toList()..sort();
    });

    return alojamientos;
  }

  Future<List<Map<String, dynamic>>> _loadActividades() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('actividades').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _loadAlimentos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('alimentos').get();
    final tipos = <String>{};
    final alimentos = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      alimentos.add({'id': doc.id, ...data});
      if (data['tipo'] != null && data['tipo'].toString().isNotEmpty) {
        tipos.add(data['tipo'].toString());
      }
    }

    setState(() {
      _tiposAlimento = tipos.toList()..sort();
    });

    return alimentos;
  }

  List<Map<String, dynamic>> get _filteredAlojamientos {
    if (_selectedTipoAlojamiento == null) return [];
    return _alojamientos
        .where((a) => a['tipo'] == _selectedTipoAlojamiento)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredAlimentos {
    if (_selectedTipoAlimento == null) return [];
    return _alimentos.where((a) => a['tipo'] == _selectedTipoAlimento).toList();
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
    }
  }

  Future<bool> _isAlojamientoDisponible(String alojamientoId) async {
    try {
      if (_fechaEntrada == null || _fechaSalida == null) {
        throw Exception("Las fechas no están definidas");
      }
      if (alojamientoId.isEmpty) {
        throw Exception("ID de alojamiento vacío");
      }
      if (!_fechaEntrada!.isBefore(_fechaSalida!)) {
        throw Exception("La fecha de entrada debe ser anterior a la de salida");
      }
      if (_fechaEntrada!.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
        throw Exception("No puede reservar para fechas pasadas");
      }

      // Verificar capacidad primero
      final alojamiento = _alojamientos.firstWhere(
        (a) => a['id'] == alojamientoId,
        orElse: () => {},
      );

      if (alojamiento.isEmpty) {
        throw Exception("Alojamiento no encontrado");
      }

      final capacidad = alojamiento['capacidad'] != null
          ? int.tryParse(alojamiento['capacidad'].toString()) ?? 0
          : 0;
      final huespedes = int.tryParse(_huespedesController.text) ?? 1;

      if (capacidad > 0 && huespedes > capacidad) {
        return false;
      }

      // Verificar disponibilidad de fechas
      final entrada = Timestamp.fromDate(_fechaEntrada!);
      final salida = Timestamp.fromDate(_fechaSalida!);

      final query = FirebaseFirestore.instance
          .collection('reservas')
          .where('alojamientoId', isEqualTo: alojamientoId)
          .where('fechaEntrada', isLessThan: salida)
          .where('fechaSalida', isGreaterThan: entrada)
          .where('estado', isNotEqualTo: 'cancelada');

      final snapshot = await query.get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      print("Error verificando disponibilidad: $e");
      rethrow;
    }
  }

  Future<void> _verificarDisponibilidad() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fechaEntrada == null || _fechaSalida == null) {
      _showDialog("Error", "Seleccione fechas de entrada y salida válidas");
      return;
    }

    if (_selectedAlojamientoId == null || _selectedAlojamientoId!.isEmpty) {
      _showDialog("Error", "Seleccione un alojamiento primero");
      return;
    }

    if (!_fechaEntrada!.isBefore(_fechaSalida!)) {
      _showDialog(
          "Error", "La fecha de entrada debe ser anterior a la de salida");
      return;
    }

    if (_fechaEntrada!.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
      _showDialog("Error", "No puede reservar para fechas pasadas");
      return;
    }

    setState(() {
      _isLoading = true;
      _disponibilidadVerificada = false;
    });

    try {
      final disponible =
          await _isAlojamientoDisponible(_selectedAlojamientoId!);

      setState(() {
        _alojamientoDisponible = disponible;
        _disponibilidadVerificada = true;
      });

      if (!disponible) {
        _showDialog(
          "No Disponible",
          "El alojamiento no está disponible para las fechas seleccionadas. Por favor, elija otras fechas.",
        );
      }
    } catch (e) {
      _showError("Error al verificar disponibilidad", e);
      setState(() {
        _disponibilidadVerificada = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCounter({
    required String id,
    required Map<String, int> selectedItems,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    final cantidad = selectedItems[id] ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove, size: 20),
          onPressed: cantidad > 0 ? onDecrement : null,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
        Container(
          width: 30,
          alignment: Alignment.center,
          child:
              Text('$cantidad', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: Icon(Icons.add, size: 20),
          onPressed: onIncrement,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildVerificationButton() {
    final capacidadExcedida = _checkCapacidadExcedida();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_isLoading) LinearProgressIndicator(minHeight: 2),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: capacidadExcedida ? null : _verificarDisponibilidad,
            style: ElevatedButton.styleFrom(
              backgroundColor: _disponibilidadVerificada
                  ? (_alojamientoDisponible ? Colors.green : Colors.red)
                  : Colors.blue,
              minimumSize: Size(double.infinity, 50),
            ),
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                    _disponibilidadVerificada
                        ? (_alojamientoDisponible
                            ? 'Disponible ✅'
                            : 'No Disponible ❌')
                        : 'Verificar Disponibilidad',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
          ),
          if (capacidadExcedida)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Excede la capacidad máxima',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  bool _checkCapacidadExcedida() {
    if (_selectedAlojamientoId == null) return false;

    final alojamiento = _alojamientos.firstWhere(
      (a) => a['id'] == _selectedAlojamientoId,
      orElse: () => {},
    );

    if (alojamiento.isEmpty || alojamiento['capacidad'] == null) return false;

    final capacidad = int.tryParse(alojamiento['capacidad'].toString()) ?? 0;
    final huespedes = int.tryParse(_huespedesController.text) ?? 1;

    return capacidad > 0 && huespedes > capacidad;
  }

  Widget _buildResumenReserva() {
    if (_fechaEntrada == null || _fechaSalida == null) return SizedBox();

    final alojamiento = _selectedAlojamientoId != null
        ? _alojamientos.firstWhere((a) => a['id'] == _selectedAlojamientoId)
        : null;

    final huespedes = int.tryParse(_huespedesController.text) ?? 1;
    final precioPorNochePorPersona =
        alojamiento != null ? (alojamiento['precio'] as num).toDouble() : 0.0;
    final precioAlojamiento = precioPorNochePorPersona * _noches * huespedes;

    double precioTotalActividades =
        _selectedActividades.entries.fold(0, (sum, entry) {
      final actividad = _actividades.firstWhere((a) => a['id'] == entry.key);
      return sum + (actividad['precio'] as num).toDouble() * entry.value;
    });

    double precioTotalAlimentos =
        _selectedAlimentos.entries.fold(0, (sum, entry) {
      final alimento = _alimentos.firstWhere((a) => a['id'] == entry.key);
      return sum + (alimento['precio'] as num).toDouble() * entry.value;
    });

    final precioTotal =
        precioAlojamiento + precioTotalActividades + precioTotalAlimentos;

    final capacidad = alojamiento != null && alojamiento['capacidad'] != null
        ? int.tryParse(alojamiento['capacidad'].toString()) ?? 0
        : 0;
    final excedeCapacidad = capacidad > 0 && huespedes > capacidad;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen de Reserva',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
                '• $_noches noche(s): ${DateFormat('dd/MM/yyyy').format(_fechaEntrada!)} - ${DateFormat('dd/MM/yyyy').format(_fechaSalida!)}',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 5),
            Text('• Huéspedes: $huespedes', style: TextStyle(fontSize: 16)),
            if (alojamiento != null) ...[
              SizedBox(height: 5),
              Text('• Alojamiento: ${alojamiento['nombre']}',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 5),
              Text('• Tipo: ${alojamiento['tipo'] ?? 'No especificado'}',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 5),
              Text(
                  '• Precio alojamiento: \$${precioAlojamiento.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 5),
              Text(
                '• Capacidad máxima: $capacidad personas',
                style: TextStyle(
                  color: excedeCapacidad ? Colors.red : null,
                  fontWeight: excedeCapacidad ? FontWeight.bold : null,
                  fontSize: 16,
                ),
              ),
              if (excedeCapacidad) ...[
                SizedBox(height: 5),
                Text(
                  '⚠️ Supera la capacidad por ${huespedes - capacidad} personas',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
            if (_selectedActividades.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('• Actividades:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ..._selectedActividades.entries.map((entry) {
                final actividad =
                    _actividades.firstWhere((a) => a['id'] == entry.key);
                return Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Text(
                    '  - ${actividad['nombre']} x${entry.value}: \$${(actividad['precio'] * entry.value).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
              SizedBox(height: 5),
              Text(
                  '• Total actividades: \$${precioTotalActividades.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16)),
            ],
            if (_selectedAlimentos.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('• Alimentación:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ..._selectedAlimentos.entries.map((entry) {
                final alimento =
                    _alimentos.firstWhere((a) => a['id'] == entry.key);
                return Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Text(
                    '  - ${alimento['nombre']} x${entry.value}: \$${(alimento['precio'] * entry.value).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
              SizedBox(height: 5),
              Text(
                  '• Total alimentación: \$${precioTotalAlimentos.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16)),
            ],
            SizedBox(height: 10),
            Text(
              '• Total estimado: \$${precioTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 10),
            _buildVerificationButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlojamientoCard(Map<String, dynamic> alojamiento) {
    final bool isSelected = _selectedAlojamientoId == alojamiento['id'];
    final huespedes = int.tryParse(_huespedesController.text) ?? 1;
    final precioPorNochePorPersona = (alojamiento['precio'] as num).toDouble();
    final precioTotal = _noches > 0
        ? (precioPorNochePorPersona * _noches * huespedes)
        : precioPorNochePorPersona * huespedes;

    final capacidad = alojamiento['capacidad'] != null
        ? int.tryParse(alojamiento['capacidad'].toString()) ?? 0
        : 0;
    final excedeCapacidad = capacidad > 0 && huespedes > capacidad;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading:
            (alojamiento['imagen'] != null && alojamiento['imagen'].isNotEmpty)
                ? Image.network(alojamiento['imagen'],
                    width: 50, height: 50, fit: BoxFit.cover)
                : Icon(Icons.home, size: 50, color: Colors.green),
        title: Text(
          alojamiento['nombre'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: excedeCapacidad ? Colors.red : Colors.green[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alojamiento['tipo'] ?? 'No especificado',
                style: TextStyle(fontSize: 16)),
            if (alojamiento['descripcion'] != null)
              Text(alojamiento['descripcion'], style: TextStyle(fontSize: 14)),
            SizedBox(height: 5),
            Text(
              'Precio: \$${precioPorNochePorPersona.toStringAsFixed(2)} por persona/noche',
              style: TextStyle(fontSize: 16),
            ),
            if (_noches > 0)
              Text(
                'Total estimado: \$${precioTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: excedeCapacidad ? Colors.red : Colors.green[700],
                ),
              ),
            if (capacidad > 0)
              Text(
                'Capacidad: $capacidad personas',
                style: TextStyle(
                  color: excedeCapacidad ? Colors.red : null,
                  fontSize: 16,
                ),
              ),
            if (excedeCapacidad)
              Text(
                '⚠️ Supera la capacidad por ${huespedes - capacidad} personas',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
          ],
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.green)
            : Icon(Icons.radio_button_unchecked, color: Colors.grey),
        onTap: () {
          if (excedeCapacidad) {
            _showDialog(
                "Error", "Excede la capacidad máxima de $capacidad huéspedes");
            return;
          }
          setState(() {
            _selectedAlojamientoId = alojamiento['id'];
            _disponibilidadVerificada = false;
          });
        },
      ),
    );
  }

  Widget _buildActividadItem(Map<String, dynamic> actividad) {
    final actividadId = actividad['id'];
    final isSelected = _selectedActividades.containsKey(actividadId);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: (actividad['imagen'] != null && actividad['imagen'].isNotEmpty)
            ? Image.network(actividad['imagen'],
                width: 50, height: 50, fit: BoxFit.cover)
            : Icon(Icons.sports, size: 50, color: Colors.blue),
        title: Text(
          actividad['nombre'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.blue[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (actividad['descripcion'] != null)
              Text(actividad['descripcion'], style: TextStyle(fontSize: 14)),
            SizedBox(height: 5),
            Text(
              'Precio: \$${actividad['precio'].toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Text('${_selectedActividades[actividadId]}x',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildCounter(
              id: actividadId,
              selectedItems: _selectedActividades,
              onIncrement: () => setState(() {
                _selectedActividades.update(
                  actividadId,
                  (value) => value + 1,
                  ifAbsent: () => 1,
                );
              }),
              onDecrement: () => setState(() {
                if (_selectedActividades[actividadId] == 1) {
                  _selectedActividades.remove(actividadId);
                } else {
                  _selectedActividades.update(
                      actividadId, (value) => value - 1);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlimentoItem(Map<String, dynamic> alimento) {
    final alimentoId = alimento['id'];
    final isSelected = _selectedAlimentos.containsKey(alimentoId);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: (alimento['imagen'] != null && alimento['imagen'].isNotEmpty)
            ? Image.network(alimento['imagen'],
                width: 50, height: 50, fit: BoxFit.cover)
            : Icon(Icons.restaurant, size: 50, color: Colors.orange),
        title: Text(
          alimento['nombre'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alimento['tipo'] ?? 'No especificado',
                style: TextStyle(fontSize: 16)),
            if (alimento['descripcion'] != null)
              Text(alimento['descripcion'], style: TextStyle(fontSize: 14)),
            SizedBox(height: 5),
            Text(
              'Precio: \$${alimento['precio'].toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Text('${_selectedAlimentos[alimentoId]}x',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildCounter(
              id: alimentoId,
              selectedItems: _selectedAlimentos,
              onIncrement: () => setState(() {
                _selectedAlimentos.update(
                  alimentoId,
                  (value) => value + 1,
                  ifAbsent: () => 1,
                );
              }),
              onDecrement: () => setState(() {
                if (_selectedAlimentos[alimentoId] == 1) {
                  _selectedAlimentos.remove(alimentoId);
                } else {
                  _selectedAlimentos.update(alimentoId, (value) => value - 1);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlojamientoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Tipo de Alojamiento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: _selectedTipoAlojamiento,
              hint: Text('Seleccionar tipo de alojamiento'),
              isExpanded: true,
              underline: SizedBox(),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos los tipos'),
                ),
                ..._tiposAlojamiento.map((tipo) {
                  return DropdownMenuItem<String>(
                    value: tipo,
                    child: Text(tipo),
                  );
                }).toList(),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTipoAlojamiento = newValue;
                  _selectedAlojamientoId = null;
                  _tipoSeleccionado = newValue != null;
                  _disponibilidadVerificada = false;
                });
              },
            ),
          ),
        ),
        if (_tipoSeleccionado) ...[
          SizedBox(height: 10),
          if (_filteredAlojamientos.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay alojamientos de tipo ${_selectedTipoAlojamiento}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ..._filteredAlojamientos
              .map((alojamiento) => _buildAlojamientoCard(alojamiento))
              .toList(),
        ],
      ],
    );
  }

  Widget _buildActividadesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Actividades Adicionales',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        if (_actividades.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No hay actividades disponibles',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ..._actividades
            .map((actividad) => _buildActividadItem(actividad))
            .toList(),
      ],
    );
  }

  Widget _buildAlimentosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Opciones de Alimentación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: _selectedTipoAlimento,
              hint: Text('Seleccionar tipo de alimentación'),
              isExpanded: true,
              underline: SizedBox(),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos los tipos'),
                ),
                ..._tiposAlimento.map((tipo) {
                  return DropdownMenuItem<String>(
                    value: tipo,
                    child: Text(tipo),
                  );
                }).toList(),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTipoAlimento = newValue;
                  _selectedAlimentos.clear();
                  _tipoAlimentoSeleccionado = newValue != null;
                });
              },
            ),
          ),
        ),
        if (_tipoAlimentoSeleccionado) ...[
          SizedBox(height: 10),
          if (_filteredAlimentos.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay opciones de alimentación de tipo ${_selectedTipoAlimento}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ..._filteredAlimentos
              .map((alimento) => _buildAlimentoItem(alimento))
              .toList(),
        ],
      ],
    );
  }

  Widget _buildClienteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Datos del Cliente',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: _nombreController,
            decoration: InputDecoration(
              labelText: "Nombre del titular",
              labelStyle: TextStyle(fontSize: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese el nombre del titular';
              }
              return null;
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "Email",
              labelStyle: TextStyle(fontSize: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese un email válido';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Ingrese un email válido';
              }
              return null;
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: _telefonoController,
            decoration: InputDecoration(
              labelText: "Teléfono",
              labelStyle: TextStyle(fontSize: 16),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !RegExp(r'^[0-9]+$').hasMatch(value)) {
                return 'Ingrese solo números';
              }
              return null;
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: _huespedesController,
            decoration: InputDecoration(
              labelText: "Número de huéspedes",
              labelStyle: TextStyle(fontSize: 16),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null ||
                  value.isEmpty ||
                  int.tryParse(value) == null) {
                return 'Ingrese un número válido';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _disponibilidadVerificada = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFechasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Fechas de estadía',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectFecha(context, true),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          _fechaEntrada == null
                              ? 'Seleccionar entrada'
                              : DateFormat('dd/MM/yyyy').format(_fechaEntrada!),
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _fechaEntrada == null
                      ? null
                      : () => _selectFecha(context, false),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          _fechaSalida == null
                              ? 'Seleccionar salida'
                              : DateFormat('dd/MM/yyyy').format(_fechaSalida!),
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    final capacidadExcedida = _checkCapacidadExcedida();
    final puedeReservar = _disponibilidadVerificada &&
        _alojamientoDisponible &&
        !capacidadExcedida &&
        _formKey.currentState?.validate() == true;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (_isLoading) LinearProgressIndicator(minHeight: 2),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: puedeReservar ? _crearReserva : null,
            child: Text("Confirmar Reserva",
                style: TextStyle(fontSize: 18, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15),
              backgroundColor: puedeReservar ? Colors.green[700] : Colors.grey,
              minimumSize: Size(double.infinity, 50),
            ),
          ),
          if (capacidadExcedida)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Excede la capacidad máxima del alojamiento',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          if (_disponibilidadVerificada && !_alojamientoDisponible)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'El alojamiento no está disponible para las fechas seleccionadas',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirmarReserva() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.question_mark, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text("Confirmar Reserva",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("¿Está seguro de crear esta reserva?",
            style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Confirmar", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _crearReserva() async {
    if (!_formKey.currentState!.validate()) {
      _showDialog("Error", "Por favor complete todos los campos requeridos");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showDialog("Error", "Debe iniciar sesión para reservar");
      return;
    }

    if (_fechaEntrada == null || _fechaSalida == null) {
      _showDialog("Error", "Seleccione fechas válidas");
      return;
    }

    if (_selectedAlojamientoId == null) {
      _showDialog("Error", "Seleccione un alojamiento");
      return;
    }

    final alojamiento =
        _alojamientos.firstWhere((a) => a['id'] == _selectedAlojamientoId);
    final capacidad = alojamiento['capacidad'] != null
        ? int.tryParse(alojamiento['capacidad'].toString()) ?? 0
        : 0;
    final huespedes = int.tryParse(_huespedesController.text) ?? 1;

    if (capacidad > 0 && huespedes > capacidad) {
      _showDialog("Error",
          "El alojamiento no soporta $huespedes huéspedes (máx: $capacidad)");
      return;
    }

    if (!_disponibilidadVerificada || !_alojamientoDisponible) {
      _showDialog("Error", "Verifique la disponibilidad primero");
      return;
    }

    final confirmado = await _confirmarReserva();
    if (confirmado != true) return;

    setState(() => _isLoading = true);

    try {
      final alojamientoDoc = await FirebaseFirestore.instance
          .collection('alojamientos')
          .doc(_selectedAlojamientoId)
          .get();

      if (!alojamientoDoc.exists) {
        throw Exception("El alojamiento seleccionado no existe");
      }

      final reservaData = await _prepareReservaData(
          alojamientoDoc.data()!, user.uid, huespedes);

      await FirebaseFirestore.instance.collection('reservas').add(reservaData);

      _showSuccess("Reserva creada exitosamente");
      _limpiarFormulario();
    } catch (e) {
      _showError("Error al crear reserva", e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _prepareReservaData(
      Map<String, dynamic> alojamientoData,
      String userId,
      int huespedes) async {
    final precioPorNochePorPersona =
        (alojamientoData['precio'] as num).toDouble();
    final precioAlojamiento = precioPorNochePorPersona * _noches * huespedes;

    final actividadesInfo = _selectedActividades.map((id, cantidad) {
      final actividad = _actividades.firstWhere((a) => a['id'] == id);
      return MapEntry(id, {
        'nombre': actividad['nombre'],
        'cantidad': cantidad,
        'precioUnitario': actividad['precio'],
      });
    });

    final alimentosInfo = _selectedAlimentos.map((id, cantidad) {
      final alimento = _alimentos.firstWhere((a) => a['id'] == id);
      return MapEntry(id, {
        'nombre': alimento['nombre'],
        'cantidad': cantidad,
        'precioUnitario': alimento['precio'],
        'tipo': alimento['tipo'],
      });
    });

    return {
      'usuarioId': userId,
      'titular': _nombreController.text,
      'email': _emailController.text,
      'telefono': _telefonoController.text,
      'alojamientoId': _selectedAlojamientoId,
      'alojamientoNombre': alojamientoData['nombre'],
      'alojamientoTipo': alojamientoData['tipo'],
      'actividades': actividadesInfo,
      'alimentos': alimentosInfo,
      'fechaEntrada': Timestamp.fromDate(_fechaEntrada!),
      'fechaSalida': Timestamp.fromDate(_fechaSalida!),
      'noches': _noches,
      'huespedes': huespedes,
      'precioAlojamiento': precioAlojamiento,
      'precioActividades': _selectedActividades.entries.fold(0.0, (sum, entry) {
        final actividad = _actividades.firstWhere((a) => a['id'] == entry.key);
        return sum + (actividad['precio'] as num).toDouble() * entry.value;
      }),
      'precioAlimentos': _selectedAlimentos.entries.fold(0.0, (sum, entry) {
        final alimento = _alimentos.firstWhere((a) => a['id'] == entry.key);
        return sum + (alimento['precio'] as num).toDouble() * entry.value;
      }),
      'total': precioAlojamiento +
          _selectedActividades.entries.fold(0.0, (sum, entry) {
            final actividad =
                _actividades.firstWhere((a) => a['id'] == entry.key);
            return sum + (actividad['precio'] as num).toDouble() * entry.value;
          }) +
          _selectedAlimentos.entries.fold(0.0, (sum, entry) {
            final alimento = _alimentos.firstWhere((a) => a['id'] == entry.key);
            return sum + (alimento['precio'] as num).toDouble() * entry.value;
          }),
      'fechaCreacion': Timestamp.now(),
      'estado': 'confirmada',
      'ultimaActualizacion': Timestamp.now(),
    };
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

  void _showError(String title, dynamic error) {
    _showDialog(title, error.toString());
  }

  void _showSuccess(String message) {
    _showDialog("Éxito", message);
  }

  void _limpiarFormulario() {
    setState(() {
      _nombreController.clear();
      _emailController.clear();
      _telefonoController.clear();
      _huespedesController.text = '1';
      _fechaEntrada = null;
      _fechaSalida = null;
      _selectedAlojamientoId = null;
      _selectedTipoAlojamiento = null;
      _tipoSeleccionado = false;
      _selectedActividades.clear();
      _selectedTipoAlimento = null;
      _tipoAlimentoSeleccionado = false;
      _selectedAlimentos.clear();
      _noches = 0;
      _disponibilidadVerificada = false;
      _alojamientoDisponible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Nueva Reserva",
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(8.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClienteSection(),
                    _buildFechasSection(),
                    _buildAlojamientoSection(),
                    _buildActividadesSection(),
                    _buildAlimentosSection(),
                    _buildResumenReserva(),
                    _buildConfirmButton(),
                  ],
                ),
              ),
            ),
    );
  }
}
