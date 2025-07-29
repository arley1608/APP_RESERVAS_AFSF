import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

class ReservationScreen extends StatefulWidget {
  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  // Controladores para formularios
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _huespedesController =
      TextEditingController(text: '1');
  final TextEditingController _abonoController = TextEditingController();

  // Fechas de reserva
  DateTime? _fechaEntrada;
  DateTime? _fechaSalida;

  // Estados de carga
  bool _isLoadingAlojamientos = false;
  bool _isLoadingDisponibilidad = false;
  bool _isLoadingReserva = false;
  bool _isLoadingActividades = false;
  bool _isLoadingAlimentos = false;

  // Datos de alojamiento
  String? _tipoAlojamientoSeleccionado;
  final Map<String, Map<String, dynamic>> _alojamientosSeleccionados = {};
  double? _precioTotal;
  bool _disponibilidadVerificada = false;
  bool _todosAlojamientosDisponibles = false;

  // Actividades
  bool _mostrarActividades = false;
  bool _deseaActividades = false;
  List<QueryDocumentSnapshot> _actividadesDisponibles = [];
  Map<String, int> _actividadesSeleccionadas = {};

  // Alimentos
  bool _mostrarAlimentos = false;
  bool _deseaAlimentos = false;
  List<QueryDocumentSnapshot> _alimentosDisponibles = [];
  Map<String, int> _alimentosSeleccionados = {};

  // Métodos de pago
  String? _metodoPagoSeleccionado;
  final List<String> _metodosPago = [
    'Efectivo',
    'Tarjeta de Crédito',
    'Tarjeta de Débito',
    'Transferencia Bancaria',
    'Depósito',
    'Otro'
  ];
  double _saldoPendiente = 0;

  // Tipos de alojamiento disponibles
  final List<String> _tiposAlojamiento = [
    "Habitación Superior",
    "Habitación Standard",
    "Cabaña",
    "Apartamento",
    "Zona de Camping",
    "Zona de Camping con Carpa",
    "Hamaca",
  ];

  List<DocumentSnapshot> _listaAlojamientosDisponibles = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _verificarAutenticacion();
    _cargarAlojamientos();
    _abonoController.addListener(_calcularSaldoPendiente);
  }

  Future<void> _verificarAutenticacion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarError('Debes iniciar sesión para hacer reservas');
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _huespedesController.dispose();
    _abonoController.removeListener(_calcularSaldoPendiente);
    _abonoController.dispose();
    super.dispose();
  }

  void _calcularSaldoPendiente() {
    final abono = double.tryParse(_abonoController.text) ?? 0;
    final total = _calcularPrecioTotal() ?? 0;
    setState(() {
      _saldoPendiente = max(0, total - abono);
    });
  }

  Future<void> _cargarAlojamientos() async {
    try {
      setState(() => _isLoadingAlojamientos = true);
      final snapshot = await FirebaseFirestore.instance
          .collection('alojamientos')
          .get()
          .timeout(const Duration(seconds: 10));

      setState(() {
        _listaAlojamientosDisponibles = snapshot.docs;
      });
    } on TimeoutException {
      _mostrarError('Tiempo de espera agotado. Verifique su conexión.');
    } catch (e) {
      _mostrarError('No se pudieron cargar los alojamientos.');
      debugPrint('Error al cargar alojamientos: $e');
    } finally {
      setState(() => _isLoadingAlojamientos = false);
    }
  }

  Future<void> _cargarActividades() async {
    try {
      setState(() => _isLoadingActividades = true);
      final snapshot = await FirebaseFirestore.instance
          .collection('actividades')
          .get()
          .timeout(const Duration(seconds: 10));

      setState(() {
        _actividadesDisponibles = snapshot.docs;
      });
    } catch (e) {
      _mostrarError('No se pudieron cargar las actividades.');
      debugPrint('Error al cargar actividades: $e');
    } finally {
      setState(() => _isLoadingActividades = false);
    }
  }

  Future<void> _cargarAlimentos() async {
    try {
      setState(() => _isLoadingAlimentos = true);
      final snapshot = await FirebaseFirestore.instance
          .collection('alimentos')
          .get()
          .timeout(const Duration(seconds: 10));

      setState(() {
        _alimentosDisponibles = snapshot.docs;
      });
    } catch (e) {
      _mostrarError('No se pudieron cargar los alimentos.');
      debugPrint('Error al cargar alimentos: $e');
    } finally {
      setState(() => _isLoadingAlimentos = false);
    }
  }

  void _toggleAlojamientoSeleccionado(DocumentSnapshot alojamiento) {
    if (_alojamientosSeleccionados.length >= 10 &&
        !_alojamientosSeleccionados.containsKey(alojamiento.id)) {
      _mostrarError('Máximo 10 alojamientos por reserva');
      return;
    }

    setState(() {
      final alojamientoId = alojamiento.id;
      if (_alojamientosSeleccionados.containsKey(alojamientoId)) {
        _alojamientosSeleccionados.remove(alojamientoId);
      } else {
        _alojamientosSeleccionados[alojamientoId] = {
          'doc': alojamiento,
          'huespedes': 1,
        };
      }
      _validarHuespedes();
      _precioTotal = _calcularPrecioTotal();
      _calcularSaldoPendiente();
    });
  }

  void _validarHuespedes() {
    final totalHuespedes = _alojamientosSeleccionados.values
        .fold<int>(0, (int sum, item) => sum + (item['huespedes'] as int));
    final maxHuespedes = int.tryParse(_huespedesController.text) ?? 1;

    if (totalHuespedes > maxHuespedes) {
      _mostrarError(
          'La suma de huéspedes por alojamiento ($totalHuespedes) supera el total ($maxHuespedes)');
    }
  }

  void _updateHuespedes(String alojamientoId, int newValue) {
    setState(() {
      _alojamientosSeleccionados[alojamientoId]!['huespedes'] = newValue;
      _validarHuespedes();
      _precioTotal = _calcularPrecioTotal();
      _calcularSaldoPendiente();
    });
  }

  Future<void> _verificarDisponibilidad() async {
    if (_alojamientosSeleccionados.isEmpty) {
      _mostrarError('Seleccione al menos un alojamiento');
      return;
    }

    if (_fechaEntrada == null || _fechaSalida == null) {
      _mostrarError('Seleccione ambas fechas (entrada y salida)');
      return;
    }

    if (_fechaEntrada!.isAfter(_fechaSalida!)) {
      _mostrarError('La fecha de entrada debe ser anterior a la de salida');
      return;
    }

    if (_fechaSalida!.difference(_fechaEntrada!).inDays < 1) {
      _mostrarError('La estadía mínima es de 1 noche');
      return;
    }

    final totalHuespedes = _alojamientosSeleccionados.values
        .fold<int>(0, (int sum, item) => sum + (item['huespedes'] as int));
    final maxHuespedes = int.tryParse(_huespedesController.text) ?? 1;

    if (totalHuespedes > maxHuespedes) {
      _mostrarError(
          'La suma de huéspedes por alojamiento ($totalHuespedes) supera el total ($maxHuespedes)');
      return;
    }

    setState(() {
      _isLoadingDisponibilidad = true;
      _disponibilidadVerificada = false;
      _todosAlojamientosDisponibles = false;
    });

    try {
      bool todosDisponibles = true;
      final alojamientoIds = _alojamientosSeleccionados.keys.toList();

      for (final alojamientoId in alojamientoIds) {
        // Consulta modificada para evitar índices compuestos
        final query = await FirebaseFirestore.instance
            .collection('reservas')
            .where('alojamientos.alojamientoId', isEqualTo: alojamientoId)
            .get();

        // Verificación manual de disponibilidad
        for (final doc in query.docs) {
          final reserva = doc.data();
          final reservaEntrada =
              (reserva['fechaEntrada'] as Timestamp).toDate();
          final reservaSalida = (reserva['fechaSalida'] as Timestamp).toDate();

          // Verificar solapamiento de fechas
          if (_fechaEntrada!.isBefore(reservaSalida) &&
              _fechaSalida!.isAfter(reservaEntrada)) {
            todosDisponibles = false;
            break;
          }
        }

        if (!todosDisponibles) break;
      }

      setState(() {
        _disponibilidadVerificada = true;
        _todosAlojamientosDisponibles = todosDisponibles;
        _precioTotal = _calcularPrecioTotal();
        _mostrarActividades = todosDisponibles;
        _mostrarAlimentos = todosDisponibles;
      });

      if (todosDisponibles) {
        _mostrarExito(
          'Todos los alojamientos están disponibles para las fechas seleccionadas\n'
          'Fechas: ${DateFormat('dd/MM/yyyy').format(_fechaEntrada!)} - ${DateFormat('dd/MM/yyyy').format(_fechaSalida!)}\n'
          'Precio Total: \$${_precioTotal?.toStringAsFixed(2) ?? "0.00"}',
        );

        if (_todosAlojamientosDisponibles) {
          await _cargarActividades();
          await _cargarAlimentos();
        }
      } else {
        _mostrarError('Uno o más alojamientos no están disponibles');
      }
    } catch (e) {
      _mostrarError('Error al verificar disponibilidad: ${e.toString()}');
    } finally {
      setState(() => _isLoadingDisponibilidad = false);
    }
  }

  double? _calcularPrecioTotal() {
    if (_fechaEntrada == null || _fechaSalida == null) return null;

    final numNoches = _fechaSalida!.difference(_fechaEntrada!).inDays;
    if (numNoches <= 0) return null;

    double total = 0;

    _alojamientosSeleccionados.forEach((id, item) {
      final alojamiento = item['doc'] as DocumentSnapshot;
      final data = alojamiento.data() as Map<String, dynamic>;
      final precioPorNoche = (data['precio'] as num).toDouble();
      final huespedes = item['huespedes'] as int;
      total += precioPorNoche * huespedes * numNoches;
    });

    if (_deseaActividades && _actividadesSeleccionadas.isNotEmpty) {
      for (var entry in _actividadesSeleccionadas.entries) {
        final actividadId = entry.key;
        final cantidad = entry.value;

        try {
          final actividad = _actividadesDisponibles.firstWhere(
            (doc) => doc.id == actividadId,
          );
          final data = actividad.data() as Map<String, dynamic>;
          final precioActividad = (data['precio'] as num).toDouble();
          total += precioActividad * cantidad;
        } catch (e) {
          debugPrint('Error al calcular precio de actividad: $e');
        }
      }
    }

    if (_deseaAlimentos && _alimentosSeleccionados.isNotEmpty) {
      for (var entry in _alimentosSeleccionados.entries) {
        final alimentoId = entry.key;
        final cantidad = entry.value;

        try {
          final alimento = _alimentosDisponibles.firstWhere(
            (doc) => doc.id == alimentoId,
          );
          final data = alimento.data() as Map<String, dynamic>;
          final precioAlimento = (data['precio'] as num).toDouble();
          total += precioAlimento * cantidad;
        } catch (e) {
          debugPrint('Error al calcular precio de alimento: $e');
        }
      }
    }

    return total;
  }

  Future<void> _crearReserva() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaEntrada == null || _fechaSalida == null) {
      _mostrarError('Seleccione las fechas de entrada y salida');
      return;
    }
    if (_alojamientosSeleccionados.isEmpty) {
      _mostrarError('Seleccione al menos un alojamiento');
      return;
    }
    if (!_disponibilidadVerificada) {
      _mostrarError('Verifique la disponibilidad antes de reservar');
      return;
    }
    if (!_todosAlojamientosDisponibles) {
      _mostrarError('Uno o más alojamientos no están disponibles');
      return;
    }

    final totalHuespedes = _alojamientosSeleccionados.values
        .fold<int>(0, (int sum, item) => sum + (item['huespedes'] as int));
    final maxHuespedes = int.tryParse(_huespedesController.text) ?? 1;

    if (totalHuespedes > maxHuespedes) {
      _mostrarError('La suma de huéspedes por alojamiento supera el total');
      return;
    }

    final abono = double.tryParse(_abonoController.text) ?? 0;
    if (abono <= 0) {
      _mostrarError('El abono debe ser mayor a cero');
      return;
    }

    if (_metodoPagoSeleccionado == null) {
      _mostrarError('Seleccione un método de pago');
      return;
    }

    final precioTotal = _calcularPrecioTotal();
    if (abono > (precioTotal ?? 0)) {
      _mostrarError('El abono no puede ser mayor al total');
      return;
    }

    setState(() => _isLoadingReserva = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado. Por favor inicie sesión.');
      }

      // Usamos una transacción para asegurar consistencia
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Verificación de disponibilidad dentro de la transacción
        bool todosDisponibles = true;
        final alojamientoIds = _alojamientosSeleccionados.keys.toList();

        for (final alojamientoId in alojamientoIds) {
          final query = await FirebaseFirestore.instance
              .collection('reservas')
              .where('alojamientos.alojamientoId', isEqualTo: alojamientoId)
              .get();

          for (final doc in query.docs) {
            final reserva = doc.data();
            final reservaEntrada =
                (reserva['fechaEntrada'] as Timestamp).toDate();
            final reservaSalida =
                (reserva['fechaSalida'] as Timestamp).toDate();

            if (_fechaEntrada!.isBefore(reservaSalida) &&
                _fechaSalida!.isAfter(reservaEntrada)) {
              todosDisponibles = false;
              break;
            }
          }

          if (!todosDisponibles) {
            throw Exception(
                'El alojamiento $alojamientoId ya no está disponible');
          }
        }

        // Crear la reserva
        final reservaData = {
          'usuarioId': user.uid,
          'nombre': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'huespedesTotales': int.tryParse(_huespedesController.text) ?? 1,
          'fechaEntrada': Timestamp.fromDate(_fechaEntrada!),
          'fechaSalida': Timestamp.fromDate(_fechaSalida!),
          'alojamientos': _alojamientosSeleccionados.entries.map((entry) {
            final alojamiento = entry.value['doc'] as DocumentSnapshot;
            final huespedes = entry.value['huespedes'] as int;
            final data = alojamiento.data() as Map<String, dynamic>;
            return {
              'alojamientoId': alojamiento.id,
              'alojamientoNombre': data['nombre'],
              'tipoAlojamiento': data['tipo'],
              'huespedes': huespedes,
              'precioPorAlojamiento': (data['precio'] as num).toDouble() *
                  huespedes *
                  _fechaSalida!.difference(_fechaEntrada!).inDays,
            };
          }).toList(),
          'actividades': _actividadesSeleccionadas.entries.map((entry) {
            final actividad = _actividadesDisponibles.firstWhere(
              (doc) => doc.id == entry.key,
            );
            final data = actividad.data() as Map<String, dynamic>;
            return {
              'actividadId': entry.key,
              'nombre': data['nombre'],
              'precio': data['precio'],
              'cantidad': entry.value,
              'subtotal': (data['precio'] as num).toDouble() * entry.value,
            };
          }).toList(),
          'alimentos': _alimentosSeleccionados.entries.map((entry) {
            final alimento = _alimentosDisponibles.firstWhere(
              (doc) => doc.id == entry.key,
            );
            final data = alimento.data() as Map<String, dynamic>;
            return {
              'alimentoId': entry.key,
              'nombre': data['nombre'],
              'precio': data['precio'],
              'cantidad': entry.value,
              'subtotal': (data['precio'] as num).toDouble() * entry.value,
            };
          }).toList(),
          'precioTotal': precioTotal,
          'abono': abono,
          'metodoPago': _metodoPagoSeleccionado,
          'saldoPendiente': _saldoPendiente,
          'estado': 'pendiente',
          'creadoEn': FieldValue.serverTimestamp(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        };

        final docRef = FirebaseFirestore.instance.collection('reservas').doc();
        transaction.set(docRef, reservaData);
      });

      _mostrarExito(
          'Reserva creada correctamente con ${_alojamientosSeleccionados.length} alojamientos\n'
          'Actividades agendadas: ${_actividadesSeleccionadas.length}\n'
          'Servicios de alimentación: ${_alimentosSeleccionados.length}\n'
          'Abono inicial: \$${abono.toStringAsFixed(2)}\n'
          'Saldo pendiente: \$${_saldoPendiente.toStringAsFixed(2)}');
      _limpiarFormulario();
    } on FirebaseException catch (e) {
      String mensajeError;
      switch (e.code) {
        case 'permission-denied':
          mensajeError = 'No tienes permisos para crear reservas.';
          break;
        case 'unavailable':
          mensajeError = 'Servicio no disponible. Verifica tu conexión.';
          break;
        default:
          mensajeError = 'Error de Firebase: ${e.message}';
      }
      _mostrarError(mensajeError);
      debugPrint('Error Firebase: ${e.code} - ${e.message}');
    } catch (e) {
      _mostrarError('Error al crear reserva: ${e.toString()}');
      debugPrint('Error inesperado: ${e.toString()}');
    } finally {
      setState(() => _isLoadingReserva = false);
    }
  }

  // [Mantener todos los demás métodos auxiliares y widgets de construcción de UI]
  // ... (todos los métodos _build* y widgets permanecen iguales)

  @override
  Widget build(BuildContext context) {
    final alojamientosFiltrados = _filtrarAlojamientos();
    final numNoches = _fechaEntrada != null && _fechaSalida != null
        ? _fechaSalida!.difference(_fechaEntrada!).inDays
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Reserva',
            style: TextStyle(fontSize: 28, color: Colors.white)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingAlojamientos && _listaAlojamientosDisponibles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección 1: Datos Personales
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos Personales',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nombreController,
                              decoration: InputDecoration(
                                labelText: 'Nombre Completo',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Ingrese su nombre' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Correo Electrónico',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              validator: (value) => !value!.contains('@')
                                  ? 'Ingrese un correo válido'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _telefonoController,
                              decoration: InputDecoration(
                                labelText: 'Teléfono',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              validator: (value) => value!.length < 8
                                  ? 'Mínimo 8 caracteres'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sección 2: Detalles de la Reserva
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detalles de la Reserva',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _huespedesController,
                              decoration: InputDecoration(
                                labelText: 'Número Total de Huéspedes',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.people),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: Icon(Icons.calendar_today,
                                  color: Colors.green[700]),
                              title: Text('Fecha de Entrada'),
                              subtitle: Text(_fechaEntrada == null
                                  ? 'Seleccionar fecha'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(_fechaEntrada!)),
                              trailing: Icon(Icons.arrow_forward_ios),
                              onTap: () => _seleccionarFecha(true),
                            ),
                            const Divider(),
                            ListTile(
                              leading: Icon(Icons.calendar_today,
                                  color: Colors.green[700]),
                              title: Text('Fecha de Salida'),
                              subtitle: Text(_fechaSalida == null
                                  ? 'Seleccionar fecha'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(_fechaSalida!)),
                              trailing: Icon(Icons.arrow_forward_ios),
                              onTap: () => _seleccionarFecha(false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sección 3: Tipo de Alojamiento
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tipo de Alojamiento',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _tipoAlojamientoSeleccionado,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Seleccione un tipo',
                              ),
                              items: _tiposAlojamiento.map((tipo) {
                                return DropdownMenuItem<String>(
                                  value: tipo,
                                  child: Text(tipo),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _tipoAlojamientoSeleccionado = value;
                                  _alojamientosSeleccionados.clear();
                                  _disponibilidadVerificada = false;
                                  _precioTotal = _calcularPrecioTotal();
                                  _calcularSaldoPendiente();
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Seleccione un tipo' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sección 4: Alojamientos Disponibles
                    if (_tipoAlojamientoSeleccionado != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Alojamientos Disponibles ($_tipoAlojamientoSeleccionado)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (alojamientosFiltrados.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                              'No hay alojamientos disponibles de este tipo'),
                        )
                      else
                        ...alojamientosFiltrados.map((alojamiento) {
                          final data =
                              alojamiento.data() as Map<String, dynamic>;
                          final isSelected = _alojamientosSeleccionados
                              .containsKey(alojamiento.id);
                          final huespedes = isSelected
                              ? _alojamientosSeleccionados[alojamiento.id]![
                                  'huespedes'] as int
                              : 1;

                          return Card(
                            margin: EdgeInsets.only(bottom: 10),
                            color: isSelected ? Colors.green[50] : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.green
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  _toggleAlojamientoSeleccionado(alojamiento),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['nombre'],
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(Icons.check_circle,
                                              color: Colors.green),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tipo: ${data['tipo']}',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600]),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                        'Capacidad: ${data['capacidad']} personas'),
                                    Text(
                                      'Precio: \$${data['precio']} por persona/noche',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    if (data['descripcion'] != null)
                                      Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(data['descripcion']),
                                      ),
                                    if (isSelected)
                                      _buildHuespedesCounter(alojamiento.id,
                                          huespedes, data['capacidad']),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 20),

                      // Resumen de alojamientos seleccionados
                      if (_alojamientosSeleccionados.isNotEmpty) ...[
                        Text(
                          'Alojamientos seleccionados: ${_alojamientosSeleccionados.length}/10',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                        SizedBox(height: 10),
                        ..._alojamientosSeleccionados.entries.map((entry) {
                          final alojamiento =
                              entry.value['doc'] as DocumentSnapshot;
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '- ${alojamiento['nombre']} (${entry.value['huespedes']} huéspedes)',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          );
                        }),
                        SizedBox(height: 20),
                      ],

                      if (_alojamientosSeleccionados.isNotEmpty &&
                          _fechaEntrada != null &&
                          _fechaSalida != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isLoadingDisponibilidad
                                ? null
                                : _verificarDisponibilidad,
                            child: _isLoadingDisponibilidad
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text('Verificar Disponibilidad',
                                    style: TextStyle(fontSize: 18)),
                          ),
                        ),

                      if (_disponibilidadVerificada)
                        Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Card(
                            color: _todosAlojamientosDisponibles
                                ? Colors.green[50]
                                : Colors.red[50],
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    _todosAlojamientosDisponibles
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _todosAlojamientosDisponibles
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _todosAlojamientosDisponibles
                                          ? 'Todos los alojamientos están disponibles'
                                          : 'Uno o más alojamientos no están disponibles',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _todosAlojamientosDisponibles
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],

                    // Sección 5: Actividades
                    if (_mostrarActividades) ...[
                      SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actividades Adicionales',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                  '¿Desea agendar alguna actividad durante su estadía?'),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _deseaActividades
                                            ? Colors.green[700]
                                            : Colors.grey[300],
                                        foregroundColor: _deseaActividades
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _deseaActividades = true;
                                        });
                                      },
                                      child: Text('Sí'),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: !_deseaActividades
                                            ? Colors.red[700]
                                            : Colors.grey[300],
                                        foregroundColor: !_deseaActividades
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _deseaActividades = false;
                                          _actividadesSeleccionadas.clear();
                                          _precioTotal = _calcularPrecioTotal();
                                          _calcularSaldoPendiente();
                                        });
                                      },
                                      child: Text('No'),
                                    ),
                                  ),
                                ],
                              ),
                              if (_deseaActividades) ...[
                                SizedBox(height: 20),
                                Text('Seleccione las actividades que desea:'),
                                SizedBox(height: 10),
                                if (_isLoadingActividades)
                                  Center(child: CircularProgressIndicator())
                                else if (_actividadesDisponibles.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child:
                                        Text('No hay actividades disponibles'),
                                  )
                                else
                                  ..._actividadesDisponibles.map((actividad) {
                                    final data = actividad.data()
                                        as Map<String, dynamic>;
                                    final isSelected = _actividadesSeleccionadas
                                        .containsKey(actividad.id);
                                    final cantidad = isSelected
                                        ? _actividadesSeleccionadas[
                                            actividad.id]!
                                        : 1;

                                    return Card(
                                      margin: EdgeInsets.only(bottom: 10),
                                      color:
                                          isSelected ? Colors.green[50] : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isSelected
                                              ? Colors.green
                                              : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _actividadesSeleccionadas
                                                  .remove(actividad.id);
                                            } else {
                                              _actividadesSeleccionadas[
                                                  actividad.id] = 1;
                                            }
                                            _precioTotal =
                                                _calcularPrecioTotal();
                                            _calcularSaldoPendiente();
                                          });
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      data['nombre'],
                                                      style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Icon(Icons.check_circle,
                                                        color: Colors.green),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Precio: \$${data['precio']} por persona',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                              if (isSelected)
                                                _buildActividadCounter(
                                                    actividad.id, cantidad),
                                              if (data['descripcion'] != null)
                                                Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 8),
                                                  child:
                                                      Text(data['descripcion']),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Sección 6: Alimentos
                    if (_mostrarAlimentos) ...[
                      SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Servicio de Alimentos',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                  '¿Desea incluir servicio de alimentos durante su estadía?'),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _deseaAlimentos
                                            ? Colors.green[700]
                                            : Colors.grey[300],
                                        foregroundColor: _deseaAlimentos
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _deseaAlimentos = true;
                                        });
                                      },
                                      child: Text('Sí'),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: !_deseaAlimentos
                                            ? Colors.red[700]
                                            : Colors.grey[300],
                                        foregroundColor: !_deseaAlimentos
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _deseaAlimentos = false;
                                          _alimentosSeleccionados.clear();
                                          _precioTotal = _calcularPrecioTotal();
                                          _calcularSaldoPendiente();
                                        });
                                      },
                                      child: Text('No'),
                                    ),
                                  ),
                                ],
                              ),
                              if (_deseaAlimentos) ...[
                                SizedBox(height: 20),
                                Text(
                                    'Seleccione los alimentos que desea incluir:'),
                                SizedBox(height: 10),
                                if (_isLoadingAlimentos)
                                  Center(child: CircularProgressIndicator())
                                else if (_alimentosDisponibles.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                        'No hay opciones de alimento disponibles'),
                                  )
                                else
                                  ..._alimentosDisponibles.map((alimento) {
                                    final data =
                                        alimento.data() as Map<String, dynamic>;
                                    final isSelected = _alimentosSeleccionados
                                        .containsKey(alimento.id);
                                    final cantidad = isSelected
                                        ? _alimentosSeleccionados[alimento.id]!
                                        : 1;

                                    return Card(
                                      margin: EdgeInsets.only(bottom: 10),
                                      color:
                                          isSelected ? Colors.green[50] : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isSelected
                                              ? Colors.green
                                              : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _alimentosSeleccionados
                                                  .remove(alimento.id);
                                            } else {
                                              _alimentosSeleccionados[
                                                  alimento.id] = 1;
                                            }
                                            _precioTotal =
                                                _calcularPrecioTotal();
                                            _calcularSaldoPendiente();
                                          });
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      data['nombre'],
                                                      style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Icon(Icons.check_circle,
                                                        color: Colors.green),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Precio: \$${data['precio']} por servicio',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                              if (isSelected)
                                                _buildAlimentoCounter(
                                                    alimento.id, cantidad),
                                              if (data['descripcion'] != null)
                                                Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 8),
                                                  child:
                                                      Text(data['descripcion']),
                                                ),
                                              if (data['tipo'] != null)
                                                Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 4),
                                                  child: Chip(
                                                    label: Text(data['tipo']),
                                                    backgroundColor:
                                                        Colors.blue[50],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Sección 7: Pago
                    if (_precioTotal != null && _precioTotal! > 0) ...[
                      SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Información de Pago',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                controller: _abonoController,
                                decoration: InputDecoration(
                                  labelText: 'Monto abonado',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.attach_money),
                                  suffixText: '\$',
                                ),
                                keyboardType: TextInputType.numberWithOptions(
                                    decimal: true),
                                validator: (value) {
                                  final abono =
                                      double.tryParse(value ?? '') ?? 0;
                                  if (abono <= 0)
                                    return 'El abono debe ser mayor a cero';
                                  final total = _calcularPrecioTotal() ?? 0;
                                  if (abono > total)
                                    return 'El abono no puede superar el total';
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _metodoPagoSeleccionado,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Método de pago',
                                ),
                                items: _metodosPago.map((metodo) {
                                  return DropdownMenuItem<String>(
                                    value: metodo,
                                    child: Text(metodo),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _metodoPagoSeleccionado = value;
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Seleccione un método de pago'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Sección 8: Resumen de Reserva
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen de Reserva',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            SizedBox(height: 16),
                            if (_alojamientosSeleccionados.isNotEmpty)
                              Column(
                                children: _alojamientosSeleccionados.entries
                                    .map((entry) {
                                  final alojamiento =
                                      entry.value['doc'] as DocumentSnapshot;
                                  final data = alojamiento.data()
                                      as Map<String, dynamic>;
                                  final huespedes =
                                      entry.value['huespedes'] as int;
                                  final precioPorNoche =
                                      (data['precio'] as num).toDouble();

                                  return Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(data['nombre'],
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Huéspedes:',
                                                  style: TextStyle(
                                                      color: Colors.grey[600])),
                                              Text('$huespedes',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Precio/noche:',
                                                  style: TextStyle(
                                                      color: Colors.grey[600])),
                                              Text(
                                                  '\$${(precioPorNoche * huespedes).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Total:',
                                                  style: TextStyle(
                                                      color: Colors.grey[600])),
                                              Text(
                                                  '\$${(precioPorNoche * huespedes * numNoches).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Divider(),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (_deseaActividades &&
                                _actividadesSeleccionadas.isNotEmpty) ...[
                              SizedBox(height: 16),
                              Text(
                                'Actividades seleccionadas:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              ..._actividadesSeleccionadas.entries.map((entry) {
                                final actividadId = entry.key;
                                final cantidad = entry.value;
                                final actividad =
                                    _actividadesDisponibles.firstWhere(
                                  (doc) => doc.id == actividadId,
                                );
                                final data =
                                    actividad.data() as Map<String, dynamic>;
                                final precio =
                                    (data['precio'] as num).toDouble();

                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                                '${data['nombre']} (x$cantidad)',
                                                style: TextStyle(
                                                    color: Colors.grey[600])),
                                            Text(
                                                '\$${(precio * cantidad).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      Divider(),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (_deseaAlimentos &&
                                _alimentosSeleccionados.isNotEmpty) ...[
                              SizedBox(height: 16),
                              Text(
                                'Alimentos seleccionados:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              ..._alimentosSeleccionados.entries.map((entry) {
                                final alimentoId = entry.key;
                                final cantidad = entry.value;
                                final alimento =
                                    _alimentosDisponibles.firstWhere(
                                  (doc) => doc.id == alimentoId,
                                );
                                final data =
                                    alimento.data() as Map<String, dynamic>;
                                final precio =
                                    (data['precio'] as num).toDouble();

                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                                '${data['nombre']} (x$cantidad)',
                                                style: TextStyle(
                                                    color: Colors.grey[600])),
                                            Text(
                                                '\$${(precio * cantidad).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      Divider(),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Reserva:',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  Text(
                                      '\$${_precioTotal?.toStringAsFixed(2) ?? "0.00"}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Abonado:',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  Text(
                                      '\$${double.tryParse(_abonoController.text)?.toStringAsFixed(2) ?? "0.00"}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Saldo Pendiente:',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  Text(
                                      '\$${_saldoPendiente.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: _saldoPendiente > 0
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                            ),
                            if (_metodoPagoSeleccionado != null)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Método de pago:',
                                        style:
                                            TextStyle(color: Colors.grey[600])),
                                    Text(_metodoPagoSeleccionado!,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            Divider(),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Huéspedes totales:',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  Text(_huespedesController.text,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Fecha Entrada:',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  Text(
                                      _fechaEntrada != null
                                          ? DateFormat('dd/MM/yyyy')
                                              .format(_fechaEntrada!)
                                          : 'No seleccionada',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Fecha Salida:',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  Text(
                                      _fechaSalida != null
                                          ? DateFormat('dd/MM/yyyy')
                                              .format(_fechaSalida!)
                                          : 'No seleccionada',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Noches:',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  Text(numNoches.toString(),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Divider(),
                            if (_precioTotal != null)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Precio Total:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '\$${_precioTotal!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Complete los datos para ver el precio',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Botón de Confirmación
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: (_isLoadingReserva ||
                                !_todosAlojamientosDisponibles)
                            ? null
                            : _crearReserva,
                        child: _isLoadingReserva
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Confirmar Reserva',
                                style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _seleccionarFecha(bool esEntrada) async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: esEntrada
          ? DateTime.now()
          : _fechaEntrada?.add(Duration(days: 1)) ??
              DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green[700],
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null) {
      setState(() {
        if (esEntrada) {
          _fechaEntrada = fechaSeleccionada;
          if (_fechaSalida != null &&
              _fechaSalida!.isBefore(_fechaEntrada!.add(Duration(days: 1)))) {
            _fechaSalida = _fechaEntrada!.add(Duration(days: 1));
          }
        } else {
          _fechaSalida = fechaSeleccionada;
        }
        _disponibilidadVerificada = false;
        _precioTotal = _calcularPrecioTotal();
        _calcularSaldoPendiente();
      });
    }
  }

  List<DocumentSnapshot> _filtrarAlojamientos() {
    if (_tipoAlojamientoSeleccionado == null) return [];
    return _listaAlojamientosDisponibles.where((alojamiento) {
      final data = alojamiento.data() as Map<String, dynamic>;
      return data['tipo'] == _tipoAlojamientoSeleccionado;
    }).toList();
  }

  Widget _buildHuespedesCounter(
      String alojamientoId, int currentValue, int capacidadMaxima) {
    final maxHuespedes = int.tryParse(_huespedesController.text) ?? 1;
    final otrosHuespedes = _alojamientosSeleccionados.values
        .where((item) => (item['doc'] as DocumentSnapshot).id != alojamientoId)
        .fold<int>(0, (int sum, item) => sum + (item['huespedes'] as int));
    final maxPermitido = min(capacidadMaxima, maxHuespedes - otrosHuespedes);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: currentValue > 1
              ? () => _updateHuespedes(alojamientoId, currentValue - 1)
              : null,
        ),
        Text('$currentValue huéspedes', style: TextStyle(fontSize: 16)),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: currentValue < maxPermitido
              ? () => _updateHuespedes(alojamientoId, currentValue + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildActividadCounter(String actividadId, int currentValue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: currentValue > 1
              ? () {
                  setState(() {
                    _actividadesSeleccionadas[actividadId] = currentValue - 1;
                    _precioTotal = _calcularPrecioTotal();
                    _calcularSaldoPendiente();
                  });
                }
              : null,
        ),
        Text('$currentValue personas', style: TextStyle(fontSize: 16)),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            setState(() {
              _actividadesSeleccionadas[actividadId] = currentValue + 1;
              _precioTotal = _calcularPrecioTotal();
              _calcularSaldoPendiente();
            });
          },
        ),
      ],
    );
  }

  Widget _buildAlimentoCounter(String alimentoId, int currentValue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: currentValue > 1
              ? () {
                  setState(() {
                    _alimentosSeleccionados[alimentoId] = currentValue - 1;
                    _precioTotal = _calcularPrecioTotal();
                    _calcularSaldoPendiente();
                  });
                }
              : null,
        ),
        Text('$currentValue servicios', style: TextStyle(fontSize: 16)),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            setState(() {
              _alimentosSeleccionados[alimentoId] = currentValue + 1;
              _precioTotal = _calcularPrecioTotal();
              _calcularSaldoPendiente();
            });
          },
        ),
      ],
    );
  }

  void _mostrarExito(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Éxito',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Error',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _emailController.clear();
    _telefonoController.clear();
    _huespedesController.text = '1';
    _abonoController.clear();
    setState(() {
      _fechaEntrada = null;
      _fechaSalida = null;
      _tipoAlojamientoSeleccionado = null;
      _alojamientosSeleccionados.clear();
      _precioTotal = null;
      _disponibilidadVerificada = false;
      _todosAlojamientosDisponibles = false;
      _mostrarActividades = false;
      _deseaActividades = false;
      _actividadesSeleccionadas.clear();
      _actividadesDisponibles.clear();
      _mostrarAlimentos = false;
      _deseaAlimentos = false;
      _alimentosSeleccionados.clear();
      _alimentosDisponibles.clear();
      _metodoPagoSeleccionado = null;
      _saldoPendiente = 0;
    });
  }
}
