import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

class ReservationScreen extends StatefulWidget {
  final String? reservationId;
  final Map<String, dynamic>? reservationData;

  const ReservationScreen({
    Key? key,
    this.reservationId,
    this.reservationData,
  }) : super(key: key);

  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _huespedesController =
      TextEditingController(text: '1');
  final TextEditingController _abonoController = TextEditingController();

  DateTime? _fechaEntrada;
  DateTime? _fechaSalida;

  bool _isLoadingAlojamientos = false;
  bool _isLoadingDisponibilidad = false;
  bool _isLoadingReserva = false;
  bool _isLoadingActividades = false;
  bool _isLoadingAlimentos = false;

  String? _tipoAlojamientoSeleccionado;
  final Map<String, Map<String, dynamic>> _alojamientosSeleccionados = {};
  double? _precioTotal;
  bool _disponibilidadVerificada = false;
  bool _todosAlojamientosDisponibles = false;

  bool _mostrarActividades = false;
  bool _deseaActividades = false;
  List<QueryDocumentSnapshot> _actividadesDisponibles = [];
  Map<String, int> _actividadesSeleccionadas = {};

  bool _mostrarAlimentos = false;
  bool _deseaAlimentos = false;
  List<QueryDocumentSnapshot> _alimentosDisponibles = [];
  Map<String, int> _alimentosSeleccionados = {};

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

  bool get _esEdicion => widget.reservationId != null;

  @override
  void initState() {
    super.initState();
    _cargarAlojamientos().then((_) {
      if (_esEdicion && widget.reservationData != null) {
        _precargarDatos();
      }
    });
    _abonoController.addListener(_calcularSaldoPendiente);
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

  // ─── Precarga de datos para edición ───────────────────────

  void _precargarDatos() async {
    final data = widget.reservationData!;

    _nombreController.text = data['nombre'] ?? '';
    _emailController.text = data['email'] ?? '';
    _telefonoController.text = data['telefono'] ?? '';
    _huespedesController.text = (data['huespedesTotales'] ?? 1).toString();
    _abonoController.text = (data['abono'] ?? 0).toStringAsFixed(2);
    _metodoPagoSeleccionado = data['metodoPago'];

    if (data['fechaEntrada'] != null) {
      _fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    }
    if (data['fechaSalida'] != null) {
      _fechaSalida = (data['fechaSalida'] as Timestamp).toDate();
    }

    // Precargar alojamientos
    if (data['alojamientos'] != null) {
      for (final aloj in data['alojamientos']) {
        final id = aloj['alojamientoId'] as String;
        try {
          final doc = _listaAlojamientosDisponibles.firstWhere(
            (d) => d.id == id,
          );
          _alojamientosSeleccionados[id] = {
            'doc': doc,
            'huespedes': aloj['huespedes'] ?? 1,
          };
          _tipoAlojamientoSeleccionado = aloj['tipoAlojamiento'];
        } catch (_) {}
      }
    }

    // Precargar actividades
    final actividades = data['actividades'] as List? ?? [];
    if (actividades.isNotEmpty) {
      _deseaActividades = true;
      _mostrarActividades = true;
      await _cargarActividades();
      for (final act in actividades) {
        _actividadesSeleccionadas[act['actividadId']] = act['cantidad'] ?? 1;
      }
    }

    // Precargar alimentos
    final alimentos = data['alimentos'] as List? ?? [];
    if (alimentos.isNotEmpty) {
      _deseaAlimentos = true;
      _mostrarAlimentos = true;
      await _cargarAlimentos();
      for (final ali in alimentos) {
        _alimentosSeleccionados[ali['alimentoId']] = ali['cantidad'] ?? 1;
      }
    }

    setState(() {
      _disponibilidadVerificada = true;
      _todosAlojamientosDisponibles = true;
      _mostrarActividades = true;
      _mostrarAlimentos = true;
      _precioTotal = _calcularPrecioTotal();
      _saldoPendiente = (_precioTotal ?? 0) - (data['abono'] ?? 0);
    });
  }

  // ─── Carga de datos ────────────────────────────────────────

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
      setState(() => _listaAlojamientosDisponibles = snapshot.docs);
    } on TimeoutException {
      _mostrarError('Tiempo de espera agotado. Verifique su conexión.');
    } catch (e) {
      _mostrarError('No se pudieron cargar los alojamientos.');
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
      setState(() => _actividadesDisponibles = snapshot.docs);
    } catch (e) {
      _mostrarError('No se pudieron cargar las actividades.');
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
      setState(() => _alimentosDisponibles = snapshot.docs);
    } catch (e) {
      _mostrarError('No se pudieron cargar los alimentos.');
    } finally {
      setState(() => _isLoadingAlimentos = false);
    }
  }

  // ─── Selección de alojamientos ─────────────────────────────

  void _toggleAlojamientoSeleccionado(DocumentSnapshot alojamiento) {
    if (_alojamientosSeleccionados.length >= 10 &&
        !_alojamientosSeleccionados.containsKey(alojamiento.id)) {
      _mostrarError('Máximo 10 alojamientos por reserva');
      return;
    }
    setState(() {
      if (_alojamientosSeleccionados.containsKey(alojamiento.id)) {
        _alojamientosSeleccionados.remove(alojamiento.id);
      } else {
        _alojamientosSeleccionados[alojamiento.id] = {
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
          'La suma de huéspedes ($totalHuespedes) supera el total ($maxHuespedes)');
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

  // ─── Verificación de disponibilidad ───────────────────────

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

    setState(() {
      _isLoadingDisponibilidad = true;
      _disponibilidadVerificada = false;
      _todosAlojamientosDisponibles = false;
    });

    try {
      bool todosDisponibles = true;
      for (final alojamientoId in _alojamientosSeleccionados.keys) {
        final query = await FirebaseFirestore.instance
            .collection('reservas')
            .where('alojamientos.alojamientoId', isEqualTo: alojamientoId)
            .get();

        for (final doc in query.docs) {
          // En edición, ignorar la propia reserva
          if (_esEdicion && doc.id == widget.reservationId) continue;

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
          'Alojamientos disponibles\n'
          'Fechas: ${DateFormat('dd/MM/yyyy').format(_fechaEntrada!)} - ${DateFormat('dd/MM/yyyy').format(_fechaSalida!)}\n'
          'Precio Total: \$${_precioTotal?.toStringAsFixed(2) ?? "0.00"}',
        );
        await _cargarActividades();
        await _cargarAlimentos();
      } else {
        _mostrarError('Uno o más alojamientos no están disponibles');
      }
    } catch (e) {
      _mostrarError('Error al verificar disponibilidad: ${e.toString()}');
    } finally {
      setState(() => _isLoadingDisponibilidad = false);
    }
  }

  // ─── Cálculo de precio ─────────────────────────────────────

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

    if (_deseaActividades) {
      for (var entry in _actividadesSeleccionadas.entries) {
        try {
          final actividad =
              _actividadesDisponibles.firstWhere((doc) => doc.id == entry.key);
          final data = actividad.data() as Map<String, dynamic>;
          total += (data['precio'] as num).toDouble() * entry.value;
        } catch (_) {}
      }
    }

    if (_deseaAlimentos) {
      for (var entry in _alimentosSeleccionados.entries) {
        try {
          final alimento =
              _alimentosDisponibles.firstWhere((doc) => doc.id == entry.key);
          final data = alimento.data() as Map<String, dynamic>;
          total += (data['precio'] as num).toDouble() * entry.value;
        } catch (_) {}
      }
    }

    return total;
  }

  // ─── Guardar reserva (crear o editar) ─────────────────────

Future<void> _guardarReserva() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaEntrada == null || _fechaSalida == null) {
      _mostrarError('Seleccione las fechas de entrada y salida');
      return;
    }
    if (_alojamientosSeleccionados.isEmpty) {
      _mostrarError('Seleccione al menos un alojamiento');
      return;
    }
    if (!_disponibilidadVerificada || !_todosAlojamientosDisponibles) {
      _mostrarError('Verifique la disponibilidad antes de continuar');
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
    final precioTotal = _calcularPrecioTotal() ?? 0;
    if (abono > precioTotal) {
      _mostrarError('El abono no puede ser mayor al total');
      return;
    }

    setState(() => _isLoadingReserva = true);

    try {
      final reservaData = {
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
        'actividades': _deseaActividades
            ? _actividadesSeleccionadas.entries.map((entry) {
                final actividad = _actividadesDisponibles
                    .firstWhere((doc) => doc.id == entry.key);
                final data = actividad.data() as Map<String, dynamic>;
                return {
                  'actividadId': entry.key,
                  'nombre': data['nombre'],
                  'precio': data['precio'],
                  'cantidad': entry.value,
                  'subtotal':
                      (data['precio'] as num).toDouble() * entry.value,
                };
              }).toList()
            : [],
        'alimentos': _deseaAlimentos
            ? _alimentosSeleccionados.entries.map((entry) {
                final alimento = _alimentosDisponibles
                    .firstWhere((doc) => doc.id == entry.key);
                final data = alimento.data() as Map<String, dynamic>;
                return {
                  'alimentoId': entry.key,
                  'nombre': data['nombre'],
                  'precio': data['precio'],
                  'cantidad': entry.value,
                  'subtotal':
                      (data['precio'] as num).toDouble() * entry.value,
                };
              }).toList()
            : [],
        'precioTotal': precioTotal,
        'abono': abono,
        'metodoPago': _metodoPagoSeleccionado,
        'saldoPendiente': _saldoPendiente,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };

      if (_esEdicion) {
        await FirebaseFirestore.instance
            .collection('reservas')
            .doc(widget.reservationId)
            .update(reservaData);

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Éxito',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ]),
              content: Text('Reserva actualizada correctamente'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Aceptar'),
                ),
              ],
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Usuario no autenticado');

        reservaData['usuarioId'] = user.uid;
        reservaData['estado'] = 'pendiente';
        reservaData['creadoEn'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('reservas')
            .add(reservaData);

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Éxito',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ]),
              content: Text(
                'Reserva creada correctamente\n'
                'Alojamientos: ${_alojamientosSeleccionados.length}\n'
                'Actividades: ${_actividadesSeleccionadas.length}\n'
                'Alimentos: ${_alimentosSeleccionados.length}\n'
                'Abono: \$${abono.toStringAsFixed(2)}\n'
                'Saldo pendiente: \$${_saldoPendiente.toStringAsFixed(2)}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Aceptar'),
                ),
              ],
            ),
          );
          Navigator.pop(context);
        }
      }
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          _mostrarError('No tienes permisos para esta operación.');
          break;
        case 'unavailable':
          _mostrarError('Servicio no disponible. Verifica tu conexión.');
          break;
        default:
          _mostrarError('Error de Firebase: ${e.message}');
      }
    } catch (e) {
      _mostrarError('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoadingReserva = false);
    }
  }
  // ─── Selección de fechas ───────────────────────────────────

  Future<void> _seleccionarFecha(bool esEntrada) async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: esEntrada
          ? (_fechaEntrada ?? DateTime.now())
          : (_fechaSalida ??
              _fechaEntrada?.add(Duration(days: 1)) ??
              DateTime.now().add(Duration(days: 1))),
      firstDate: _esEdicion ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
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
              _fechaSalida!
                  .isBefore(_fechaEntrada!.add(Duration(days: 1)))) {
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

  // ─── Helpers ───────────────────────────────────────────────

  List<DocumentSnapshot> _filtrarAlojamientos() {
    if (_tipoAlojamientoSeleccionado == null) return [];
    return _listaAlojamientosDisponibles.where((alojamiento) {
      final data = alojamiento.data() as Map<String, dynamic>;
      return data['tipo'] == _tipoAlojamientoSeleccionado;
    }).toList();
  }

  void _mostrarExito(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Text('Éxito',
              style:
                  TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ]),
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
        title: Row(children: [
          Icon(Icons.error, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text('Error',
              style:
                  TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
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

  // ─── Widgets auxiliares ────────────────────────────────────

  Widget _buildHuespedesCounter(
      String alojamientoId, int currentValue, int capacidadMaxima) {
    final maxHuespedes = int.tryParse(_huespedesController.text) ?? 1;
    final otrosHuespedes = _alojamientosSeleccionados.values
        .where(
            (item) => (item['doc'] as DocumentSnapshot).id != alojamientoId)
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
              ? () => setState(() {
                    _actividadesSeleccionadas[actividadId] = currentValue - 1;
                    _precioTotal = _calcularPrecioTotal();
                    _calcularSaldoPendiente();
                  })
              : null,
        ),
        Text('$currentValue personas', style: TextStyle(fontSize: 16)),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () => setState(() {
            _actividadesSeleccionadas[actividadId] = currentValue + 1;
            _precioTotal = _calcularPrecioTotal();
            _calcularSaldoPendiente();
          }),
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
              ? () => setState(() {
                    _alimentosSeleccionados[alimentoId] = currentValue - 1;
                    _precioTotal = _calcularPrecioTotal();
                    _calcularSaldoPendiente();
                  })
              : null,
        ),
        Text('$currentValue servicios', style: TextStyle(fontSize: 16)),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () => setState(() {
            _alimentosSeleccionados[alimentoId] = currentValue + 1;
            _precioTotal = _calcularPrecioTotal();
            _calcularSaldoPendiente();
          }),
        ),
      ],
    );
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final alojamientosFiltrados = _filtrarAlojamientos();
    final numNoches = _fechaEntrada != null && _fechaSalida != null
        ? _fechaSalida!.difference(_fechaEntrada!).inDays
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esEdicion ? 'Editar Reserva' : 'Nueva Reserva',
          style: TextStyle(
              fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 35, color: Colors.white),
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
                    _buildCard('Datos Personales', [
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
                      SizedBox(height: 16),
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
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _telefonoController,
                        decoration: InputDecoration(
                          labelText: 'Teléfono',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (value) =>
                            value!.length < 8 ? 'Mínimo 8 caracteres' : null,
                      ),
                    ]),
                    SizedBox(height: 20),

                    // Sección 2: Detalles de la Reserva
                    _buildCard('Detalles de la Reserva', [
                      TextFormField(
                        controller: _huespedesController,
                        decoration: InputDecoration(
                          labelText: 'Número Total de Huéspedes',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),
                      ListTile(
                        leading:
                            Icon(Icons.calendar_today, color: Colors.green[700]),
                        title: Text('Fecha de Entrada'),
                        subtitle: Text(_fechaEntrada == null
                            ? 'Seleccionar fecha'
                            : DateFormat('dd/MM/yyyy').format(_fechaEntrada!)),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () => _seleccionarFecha(true),
                      ),
                      Divider(),
                      ListTile(
                        leading:
                            Icon(Icons.calendar_today, color: Colors.green[700]),
                        title: Text('Fecha de Salida'),
                        subtitle: Text(_fechaSalida == null
                            ? 'Seleccionar fecha'
                            : DateFormat('dd/MM/yyyy').format(_fechaSalida!)),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () => _seleccionarFecha(false),
                      ),
                    ]),
                    SizedBox(height: 20),

                    // Sección 3: Tipo de Alojamiento
                    _buildCard('Tipo de Alojamiento', [
                      DropdownButtonFormField<String>(
                        value: _tipoAlojamientoSeleccionado,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Seleccione un tipo',
                        ),
                        items: _tiposAlojamiento
                            .map((tipo) => DropdownMenuItem<String>(
                                  value: tipo,
                                  child: Text(tipo),
                                ))
                            .toList(),
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
                    ]),
                    SizedBox(height: 20),

                    // Sección 4: Alojamientos filtrados
                    if (_tipoAlojamientoSeleccionado != null) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Alojamientos ($_tipoAlojamientoSeleccionado)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(height: 10),
                      if (alojamientosFiltrados.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(16),
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
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  _toggleAlojamientoSeleccionado(alojamiento),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(data['nombre'],
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle,
                                            color: Colors.green),
                                    ]),
                                    SizedBox(height: 4),
                                    Text('Tipo: ${data['tipo']}',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600])),
                                    Text(
                                        'Capacidad: ${data['capacidad']} personas'),
                                    Text(
                                      'Precio: \$${data['precio']} por persona/noche',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700]),
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
                      SizedBox(height: 10),

                      if (_alojamientosSeleccionados.isNotEmpty) ...[
                        Text(
                          'Seleccionados: ${_alojamientosSeleccionados.length}/10',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                        SizedBox(height: 10),
                        ..._alojamientosSeleccionados.entries.map((entry) {
                          final a = entry.value['doc'] as DocumentSnapshot;
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '- ${a['nombre']} (${entry.value['huespedes']} huéspedes)',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          );
                        }),
                        SizedBox(height: 16),
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
                                  borderRadius: BorderRadius.circular(8)),
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
                              child: Row(children: [
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
                              ]),
                            ),
                          ),
                        ),
                    ],

                    // Sección 5: Actividades
                    if (_mostrarActividades) ...[
                      SizedBox(height: 20),
                      _buildCard('Actividades Adicionales', [
                        Text(
                            '¿Desea agendar alguna actividad durante su estadía?'),
                        SizedBox(height: 10),
                        _buildSiNo(
                          valor: _deseaActividades,
                          onSi: () => setState(() => _deseaActividades = true),
                          onNo: () => setState(() {
                            _deseaActividades = false;
                            _actividadesSeleccionadas.clear();
                            _precioTotal = _calcularPrecioTotal();
                            _calcularSaldoPendiente();
                          }),
                        ),
                        if (_deseaActividades) ...[
                          SizedBox(height: 20),
                          Text('Seleccione las actividades:'),
                          SizedBox(height: 10),
                          if (_isLoadingActividades)
                            Center(child: CircularProgressIndicator())
                          else if (_actividadesDisponibles.isEmpty)
                            Text('No hay actividades disponibles')
                          else
                            ..._actividadesDisponibles.map((actividad) {
                              final data =
                                  actividad.data() as Map<String, dynamic>;
                              final isSelected = _actividadesSeleccionadas
                                  .containsKey(actividad.id);
                              final cantidad = isSelected
                                  ? _actividadesSeleccionadas[actividad.id]!
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
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() {
                                    if (isSelected) {
                                      _actividadesSeleccionadas
                                          .remove(actividad.id);
                                    } else {
                                      _actividadesSeleccionadas[actividad.id] =
                                          1;
                                    }
                                    _precioTotal = _calcularPrecioTotal();
                                    _calcularSaldoPendiente();
                                  }),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                            child: Text(data['nombre'],
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                          if (isSelected)
                                            Icon(Icons.check_circle,
                                                color: Colors.green),
                                        ]),
                                        Text(
                                          'Precio: \$${data['precio']} por persona',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700]),
                                        ),
                                        if (isSelected)
                                          _buildActividadCounter(
                                              actividad.id, cantidad),
                                        if (data['descripcion'] != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(data['descripcion']),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ]),
                    ],

                    // Sección 6: Alimentos
                    if (_mostrarAlimentos) ...[
                      SizedBox(height: 20),
                      _buildCard('Servicio de Alimentos', [
                        Text(
                            '¿Desea incluir servicio de alimentos durante su estadía?'),
                        SizedBox(height: 10),
                        _buildSiNo(
                          valor: _deseaAlimentos,
                          onSi: () => setState(() => _deseaAlimentos = true),
                          onNo: () => setState(() {
                            _deseaAlimentos = false;
                            _alimentosSeleccionados.clear();
                            _precioTotal = _calcularPrecioTotal();
                            _calcularSaldoPendiente();
                          }),
                        ),
                        if (_deseaAlimentos) ...[
                          SizedBox(height: 20),
                          Text('Seleccione los alimentos:'),
                          SizedBox(height: 10),
                          if (_isLoadingAlimentos)
                            Center(child: CircularProgressIndicator())
                          else if (_alimentosDisponibles.isEmpty)
                            Text('No hay opciones disponibles')
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
                                color: isSelected ? Colors.green[50] : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.green
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() {
                                    if (isSelected) {
                                      _alimentosSeleccionados
                                          .remove(alimento.id);
                                    } else {
                                      _alimentosSeleccionados[alimento.id] = 1;
                                    }
                                    _precioTotal = _calcularPrecioTotal();
                                    _calcularSaldoPendiente();
                                  }),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                            child: Text(data['nombre'],
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                          if (isSelected)
                                            Icon(Icons.check_circle,
                                                color: Colors.green),
                                        ]),
                                        Text(
                                          'Precio: \$${data['precio']} por servicio',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700]),
                                        ),
                                        if (isSelected)
                                          _buildAlimentoCounter(
                                              alimento.id, cantidad),
                                        if (data['descripcion'] != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(data['descripcion']),
                                          ),
                                        if (data['tipo'] != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Chip(
                                              label: Text(data['tipo']),
                                              backgroundColor: Colors.blue[50],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ]),
                    ],

                    // Sección 7: Pago
                    if (_precioTotal != null && _precioTotal! > 0) ...[
                      SizedBox(height: 20),
                      _buildCard('Información de Pago', [
                        TextFormField(
                          controller: _abonoController,
                          decoration: InputDecoration(
                            labelText: 'Monto abonado',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                            suffixText: '\$',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            final abono = double.tryParse(value ?? '') ?? 0;
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
                          items: _metodosPago
                              .map((metodo) => DropdownMenuItem<String>(
                                    value: metodo,
                                    child: Text(metodo),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _metodoPagoSeleccionado = value),
                          validator: (value) => value == null
                              ? 'Seleccione un método de pago'
                              : null,
                        ),
                      ]),
                    ],

                    // Sección 8: Resumen
                    SizedBox(height: 20),
                    _buildCard('Resumen de Reserva', [
                      if (_alojamientosSeleccionados.isNotEmpty)
                        ..._alojamientosSeleccionados.entries.map((entry) {
                          final alojamiento =
                              entry.value['doc'] as DocumentSnapshot;
                          final data =
                              alojamiento.data() as Map<String, dynamic>;
                          final huespedes = entry.value['huespedes'] as int;
                          final precio = (data['precio'] as num).toDouble();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(data['nombre'],
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              _buildResumenFila('Huéspedes:', '$huespedes'),
                              _buildResumenFila('Precio/noche:',
                                  '\$${(precio * huespedes).toStringAsFixed(2)}'),
                              _buildResumenFila('Total alojamiento:',
                                  '\$${(precio * huespedes * numNoches).toStringAsFixed(2)}'),
                              Divider(),
                            ],
                          );
                        }),
                      if (_deseaActividades &&
                          _actividadesSeleccionadas.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('Actividades:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        ..._actividadesSeleccionadas.entries.map((entry) {
                          final a = _actividadesDisponibles
                              .firstWhere((d) => d.id == entry.key);
                          final data = a.data() as Map<String, dynamic>;
                          final precio = (data['precio'] as num).toDouble();
                          return Column(children: [
                            _buildResumenFila(
                                '${data['nombre']} (x${entry.value})',
                                '\$${(precio * entry.value).toStringAsFixed(2)}'),
                            Divider(),
                          ]);
                        }),
                      ],
                      if (_deseaAlimentos &&
                          _alimentosSeleccionados.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('Alimentos:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        ..._alimentosSeleccionados.entries.map((entry) {
                          final a = _alimentosDisponibles
                              .firstWhere((d) => d.id == entry.key);
                          final data = a.data() as Map<String, dynamic>;
                          final precio = (data['precio'] as num).toDouble();
                          return Column(children: [
                            _buildResumenFila(
                                '${data['nombre']} (x${entry.value})',
                                '\$${(precio * entry.value).toStringAsFixed(2)}'),
                            Divider(),
                          ]);
                        }),
                      ],
                      _buildResumenFila(
                          'Huéspedes totales:', _huespedesController.text),
                      _buildResumenFila(
                          'Fecha Entrada:',
                          _fechaEntrada != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaEntrada!)
                              : 'No seleccionada'),
                      _buildResumenFila(
                          'Fecha Salida:',
                          _fechaSalida != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaSalida!)
                              : 'No seleccionada'),
                      _buildResumenFila('Noches:', '$numNoches'),
                      Divider(),
                      _buildResumenFila('Total Reserva:',
                          '\$${_precioTotal?.toStringAsFixed(2) ?? "0.00"}'),
                      _buildResumenFila(
                          'Abonado:',
                          '\$${double.tryParse(_abonoController.text)?.toStringAsFixed(2) ?? "0.00"}'),
                      _buildResumenFila(
                        'Saldo Pendiente:',
                        '\$${_saldoPendiente.toStringAsFixed(2)}',
                        color: _saldoPendiente > 0 ? Colors.red : Colors.green,
                      ),
                      if (_metodoPagoSeleccionado != null)
                        _buildResumenFila(
                            'Método de pago:', _metodoPagoSeleccionado!),
                    ]),
                    SizedBox(height: 20),

                    // Botón confirmar / guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: (_isLoadingReserva ||
                                !_todosAlojamientosDisponibles)
                            ? null
                            : _guardarReserva,
                        child: _isLoadingReserva
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _esEdicion
                                    ? 'Guardar Cambios'
                                    : 'Confirmar Reserva',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard(String titulo, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700])),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSiNo({
    required bool valor,
    required VoidCallback onSi,
    required VoidCallback onNo,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  valor ? Colors.green[700] : Colors.grey[300],
              foregroundColor: valor ? Colors.white : Colors.black,
            ),
            onPressed: onSi,
            child: Text('Sí'),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  !valor ? Colors.red[700] : Colors.grey[300],
              foregroundColor: !valor ? Colors.white : Colors.black,
            ),
            onPressed: onNo,
            child: Text('No'),
          ),
        ),
      ],
    );
  }

  Widget _buildResumenFila(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}