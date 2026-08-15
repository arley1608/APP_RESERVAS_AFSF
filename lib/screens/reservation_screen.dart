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
  final TextEditingController _notasController = TextEditingController();

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

  // Reemplaza a la antigua "_tiposAlojamiento" plana. Ahora se agrupan
  // en dos categorías: Alojamiento rural (habitación/cabaña/apto/hamaca)
  // y Zona de camping (con o sin equipo, manejados aparte más abajo).
  final List<String> _tiposRural = [
    "Habitación Superior",
    "Habitación Standard",
    "Cabaña",
    "Apartamento",
    "Hamaca",
  ];
  static const String _tipoCampingConEquipo = "Zona de Camping con Carpa";
  static const String _tipoCampingSinEquipo = "Zona de Camping";

  // 'rural' | 'camping' | null (nada elegido aún)
  String? _categoriaAlojamiento;
  // 'hospedaje' | 'pasadia'
  String _tipoReserva = 'hospedaje';
  TimeOfDay? _horaEntradaPasadia;
  TimeOfDay? _horaSalidaPasadia;
  // 'ninguno' | 'porcentaje' | 'fijo'
  String _tipoDescuento = 'ninguno';
  final TextEditingController _descuentoController = TextEditingController();

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
    _notasController.dispose();
    _descuentoController.dispose();
    super.dispose();
  }

  void _precargarDatos() async {
    final data = widget.reservationData!;

    _nombreController.text = data['nombre'] ?? '';
    _emailController.text = data['email'] ?? '';
    _telefonoController.text = data['telefono'] ?? '';
    _huespedesController.text = (data['huespedesTotales'] ?? 1).toString();
    _abonoController.text = (data['abono'] ?? 0).toStringAsFixed(2);
    // Si el método de pago guardado no está en la lista actual (dato
    // legado, cambio de nombre, etc.), lo dejamos en null para que el
    // Dropdown no truene — el usuario simplemente lo reselecciona.
    final metodoPagoGuardado = data['metodoPago'];
    _metodoPagoSeleccionado =
        _metodosPago.contains(metodoPagoGuardado) ? metodoPagoGuardado : null;
    _notasController.text = data['notas'] ?? '';

    if (data['fechaEntrada'] != null) {
      _fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    }
    if (data['fechaSalida'] != null) {
      _fechaSalida = (data['fechaSalida'] as Timestamp).toDate();
    }

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
          final tipoGuardado = aloj['tipoAlojamiento'];
          final tiposConocidos = [
            ..._tiposRural,
            _tipoCampingConEquipo,
            _tipoCampingSinEquipo,
          ];
          _tipoAlojamientoSeleccionado =
              tiposConocidos.contains(tipoGuardado) ? tipoGuardado : null;
          // Inferimos la categoría (rural/camping) a partir del tipo
          // guardado, para que la pantalla de edición abra ya en la
          // opción correcta.
          if (_tipoAlojamientoSeleccionado == _tipoCampingConEquipo ||
              _tipoAlojamientoSeleccionado == _tipoCampingSinEquipo) {
            _categoriaAlojamiento = 'camping';
          } else if (_tipoAlojamientoSeleccionado != null) {
            _categoriaAlojamiento = 'rural';
          }
        } catch (_) {}
      }
    }

    _tipoReserva = data['tipoReserva'] ?? 'hospedaje';
    if (_tipoReserva == 'pasadia') {
      if (_fechaEntrada != null) {
        _horaEntradaPasadia = TimeOfDay.fromDateTime(_fechaEntrada!);
      }
      if (_fechaSalida != null) {
        _horaSalidaPasadia = TimeOfDay.fromDateTime(_fechaSalida!);
      }
    }

    final actividades = data['actividades'] as List? ?? [];
    if (actividades.isNotEmpty) {
      _deseaActividades = true;
      _mostrarActividades = true;
      await _cargarActividades();
      for (final act in actividades) {
        _actividadesSeleccionadas[act['actividadId']] = act['cantidad'] ?? 1;
      }
    }

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
      String? motivoNoDisponible;

      // Separamos los alojamientos seleccionados en dos grupos:
      // - "unidad": habitación, cabaña, carpa con equipo — una sola
      //   reserva ocupa por completo la unidad (chequeo binario).
      // - "por cupo": ej. Zona de Camping sin equipo — admite varias
      //   reservas simultáneas mientras no se supere la capacidad
      //   total (chequeo por suma de huéspedes).
      final idsUnidad = <String>{};
      final Map<String, int> cupoSolicitado = {};
      final Map<String, int> cupoCapacidad = {};

      for (final entry in _alojamientosSeleccionados.entries) {
        final doc = entry.value['doc'] as DocumentSnapshot;
        final data = doc.data() as Map<String, dynamic>;
        final esPorCupo = data['esPorCupo'] == true;
        if (esPorCupo) {
          cupoSolicitado[entry.key] = entry.value['huespedes'] as int;
          cupoCapacidad[entry.key] = (data['capacidad'] as num).toInt();
        } else {
          idsUnidad.add(entry.key);
        }
      }

      final Map<String, int> cupoYaOcupado = {
        for (final id in cupoSolicitado.keys) id: 0
      };

      // NOTA: Firestore no permite filtrar por un subcampo dentro de un
      // array de mapas (ej. 'alojamientos.alojamientoId'), así que traemos
      // las reservas que podrían chocar (no canceladas) y comparamos en
      // Dart. Es además más eficiente: antes se hacía una consulta por
      // cada alojamiento seleccionado; ahora se hace una sola.
      final query = await FirebaseFirestore.instance
          .collection('reservas')
          .where('estado', whereIn: ['pendiente', 'confirmada', 'activa'])
          .get();

      for (final doc in query.docs) {
        if (_esEdicion && doc.id == widget.reservationId) continue;

        final reserva = doc.data();
        if (reserva['fechaEntrada'] == null || reserva['fechaSalida'] == null) {
          continue;
        }

        final reservaEntrada = (reserva['fechaEntrada'] as Timestamp).toDate();
        final reservaSalida = (reserva['fechaSalida'] as Timestamp).toDate();

        final seCruzanFechas = _fechaEntrada!.isBefore(reservaSalida) &&
            _fechaSalida!.isAfter(reservaEntrada);
        if (!seCruzanFechas) continue;

        final alojamientosDeEsaReserva =
            (reserva['alojamientos'] as List?) ?? [];

        // Chequeo de unidades individuales: conflicto binario, igual
        // que antes.
        final idsOcupadosEnEsaReserva = alojamientosDeEsaReserva
            .map((a) => (a as Map<String, dynamic>)['alojamientoId'])
            .toSet();
        if (idsUnidad.any((id) => idsOcupadosEnEsaReserva.contains(id))) {
          todosDisponibles = false;
          break;
        }

        // Chequeo de alojamientos por cupo: sumamos huéspedes ya
        // comprometidos para esas fechas en cada alojamiento por cupo
        // que estemos evaluando.
        for (final a in alojamientosDeEsaReserva) {
          final map = a as Map<String, dynamic>;
          final id = map['alojamientoId'];
          if (cupoSolicitado.containsKey(id)) {
            cupoYaOcupado[id] = (cupoYaOcupado[id] ?? 0) +
                ((map['huespedes'] ?? 0) as num).toInt();
          }
        }
      }

      // Validar que ningún alojamiento por cupo se exceda de su
      // capacidad total al sumar lo ya ocupado más lo solicitado.
      if (todosDisponibles) {
        for (final id in cupoSolicitado.keys) {
          final ocupado = cupoYaOcupado[id] ?? 0;
          final solicitado = cupoSolicitado[id]!;
          final capacidad = cupoCapacidad[id] ?? 0;
          if (ocupado + solicitado > capacidad) {
            todosDisponibles = false;
            final disponible = (capacidad - ocupado).clamp(0, capacidad);
            motivoNoDisponible = 'Cupo insuficiente: quedan $disponible de '
                '$capacidad espacios disponibles esas fechas.';
            break;
          }
        }
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
        _mostrarError(
            motivoNoDisponible ?? 'Uno o más alojamientos no están disponibles');
      }
    } catch (e) {
      _mostrarError('Error al verificar disponibilidad: ${e.toString()}');
    } finally {
      setState(() => _isLoadingDisponibilidad = false);
    }
  }

  // Subtotal de alojamiento + actividades — la ÚNICA parte sobre la
  // que puede aplicarse descuento.
  double _calcularSubtotalAlojamientoActividades() {
    double subtotal = 0;

    if (_tipoReserva == 'hospedaje' &&
        _fechaEntrada != null &&
        _fechaSalida != null) {
      final numNoches = _fechaSalida!.difference(_fechaEntrada!).inDays;
      if (numNoches > 0) {
        _alojamientosSeleccionados.forEach((id, item) {
          final alojamiento = item['doc'] as DocumentSnapshot;
          final data = alojamiento.data() as Map<String, dynamic>;
          final precioPorNoche = (data['precio'] as num).toDouble();
          final huespedes = item['huespedes'] as int;
          subtotal += precioPorNoche * huespedes * numNoches;
        });
      }
    }

    if (_deseaActividades) {
      for (var entry in _actividadesSeleccionadas.entries) {
        try {
          final actividad = _actividadesDisponibles
              .firstWhere((doc) => doc.id == entry.key);
          final data = actividad.data() as Map<String, dynamic>;
          subtotal += (data['precio'] as num).toDouble() * entry.value;
        } catch (_) {}
      }
    }

    return subtotal;
  }

  // Subtotal de alimentos — SIEMPRE queda fuera del descuento.
  double _calcularSubtotalAlimentos() {
    double subtotal = 0;
    if (_deseaAlimentos) {
      for (var entry in _alimentosSeleccionados.entries) {
        try {
          final alimento =
              _alimentosDisponibles.firstWhere((doc) => doc.id == entry.key);
          final data = alimento.data() as Map<String, dynamic>;
          subtotal += (data['precio'] as num).toDouble() * entry.value;
        } catch (_) {}
      }
    }
    return subtotal;
  }

  // Monto de descuento (en pesos) ya resuelto, sea que se haya
  // ingresado como porcentaje o como valor fijo. Nunca deja el
  // subtotal de alojamiento+actividades en negativo.
  double _calcularMontoDescuento() {
    if (_tipoDescuento == 'ninguno') return 0;
    final subtotal = _calcularSubtotalAlojamientoActividades();
    final valorIngresado =
        double.tryParse(_descuentoController.text.replaceAll(',', '.')) ?? 0;
    if (valorIngresado <= 0) return 0;

    double monto = 0;
    if (_tipoDescuento == 'porcentaje') {
      monto = subtotal * (valorIngresado / 100);
    } else if (_tipoDescuento == 'fijo') {
      monto = valorIngresado;
    }
    return monto.clamp(0, subtotal);
  }

  double? _calcularPrecioTotal() {
    if (_fechaEntrada == null || _fechaSalida == null) return null;
    if (_tipoReserva == 'hospedaje') {
      final numNoches = _fechaSalida!.difference(_fechaEntrada!).inDays;
      if (numNoches <= 0) return null;
    }

    final subtotalAlojActividades = _calcularSubtotalAlojamientoActividades();
    final descuento = _calcularMontoDescuento();
    final subtotalAlimentos = _calcularSubtotalAlimentos();

    return (subtotalAlojActividades - descuento) + subtotalAlimentos;
  }

  Future<void> _guardarReserva() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaEntrada == null || _fechaSalida == null) {
      _mostrarError(_tipoReserva == 'pasadia'
          ? 'Seleccione la fecha y ambas horas de la pasadía'
          : 'Seleccione las fechas de entrada y salida');
      return;
    }

    if (_tipoReserva == 'hospedaje') {
      if (_alojamientosSeleccionados.isEmpty) {
        _mostrarError('Seleccione al menos un alojamiento');
        return;
      }
      if (!_disponibilidadVerificada || !_todosAlojamientosDisponibles) {
        _mostrarError('Verifique la disponibilidad antes de continuar');
        return;
      }
    } else {
      if (!_fechaSalida!.isAfter(_fechaEntrada!)) {
        _mostrarError(
            'La hora de salida debe ser posterior a la hora de entrada');
        return;
      }
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
        'tipoReserva': _tipoReserva,
        'email': _emailController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'huespedesTotales': int.tryParse(_huespedesController.text) ?? 1,
        'fechaEntrada': Timestamp.fromDate(_fechaEntrada!),
        'fechaSalida': Timestamp.fromDate(_fechaSalida!),
        'notas': _notasController.text.trim(),
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
        'tipoDescuento': _tipoDescuento,
        'montoDescuento': _calcularMontoDescuento(),
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

  Future<void> _seleccionarFechaPasadia() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaEntrada ?? DateTime.now(),
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
        _actualizarFechasPasadia(fecha: fechaSeleccionada);
      });
    }
  }

  Future<void> _seleccionarHoraPasadia(bool esEntrada) async {
    final horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: esEntrada
          ? (_horaEntradaPasadia ?? TimeOfDay(hour: 8, minute: 0))
          : (_horaSalidaPasadia ?? TimeOfDay(hour: 17, minute: 0)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.green[700]!),
          ),
          child: child!,
        );
      },
    );
    if (horaSeleccionada != null) {
      setState(() {
        if (esEntrada) {
          _horaEntradaPasadia = horaSeleccionada;
        } else {
          _horaSalidaPasadia = horaSeleccionada;
        }
        _actualizarFechasPasadia();
      });
    }
  }

  // Combina la fecha de la pasadía con las horas elegidas para armar
  // _fechaEntrada/_fechaSalida (los mismos campos que usa una reserva
  // de hospedaje, solo que aquí representan hora de llegada/salida del
  // mismo día, no noches distintas).
  void _actualizarFechasPasadia({DateTime? fecha}) {
    final baseFecha = fecha ?? _fechaEntrada ?? DateTime.now();
    final soloFecha = DateTime(baseFecha.year, baseFecha.month, baseFecha.day);

    _fechaEntrada = _horaEntradaPasadia != null
        ? soloFecha.add(Duration(
            hours: _horaEntradaPasadia!.hour,
            minutes: _horaEntradaPasadia!.minute))
        : soloFecha;

    _fechaSalida = _horaSalidaPasadia != null
        ? soloFecha.add(Duration(
            hours: _horaSalidaPasadia!.hour,
            minutes: _horaSalidaPasadia!.minute))
        : null;

    // Un pasadía no requiere alojamiento ni verificación de
    // disponibilidad — en cuanto hay fecha y ambas horas, se habilitan
    // directamente actividades y alimentos.
    final horasCompletas =
        _horaEntradaPasadia != null && _horaSalidaPasadia != null;
    _mostrarActividades = horasCompletas;
    _mostrarAlimentos = horasCompletas;
    _disponibilidadVerificada = false;
    _precioTotal = _calcularPrecioTotal();
    _calcularSaldoPendiente();
  }

  Widget _buildCategoriaChip({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.green[50] : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.green[700] : Colors.grey[600],
                size: 28),
            SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: selected ? Colors.green[800] : Colors.black87)),
            SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

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

  static const List<String> _ordenTiposAlimento = [
    "Desayuno", "Almuerzo", "Cena", "Bebida", "Snack", "Postre", "Especial",
  ];

  IconData _iconoTipoAlimento(String? tipo) {
    switch (tipo) {
      case 'Desayuno':
        return Icons.free_breakfast;
      case 'Almuerzo':
        return Icons.lunch_dining;
      case 'Cena':
        return Icons.dinner_dining;
      case 'Bebida':
        return Icons.local_bar;
      case 'Snack':
        return Icons.cookie;
      case 'Postre':
        return Icons.icecream;
      case 'Especial':
        return Icons.star;
      default:
        return Icons.restaurant_menu;
    }
  }

  // Agrupa los alimentos disponibles por tipo (mismo orden del
  // catálogo), con un encabezado por grupo, para que el recepcionista
  // encuentre rápido lo que busca en vez de desplazarse por una lista
  // plana larga.
  List<Widget> _buildAlimentosAgrupados() {
    final Map<String, List<DocumentSnapshot>> grupos = {};
    for (final doc in _alimentosDisponibles) {
      final data = doc.data() as Map<String, dynamic>;
      final tipo = data['tipo']?.toString() ?? 'Otros';
      grupos.putIfAbsent(tipo, () => []).add(doc);
    }

    final tiposOrdenados = [
      ..._ordenTiposAlimento.where(grupos.containsKey),
      ...grupos.keys.where((t) => !_ordenTiposAlimento.contains(t)),
    ];

    final widgets = <Widget>[];
    for (final tipo in tiposOrdenados) {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: 12, bottom: 6),
        child: Row(
          children: [
            Icon(_iconoTipoAlimento(tipo), size: 20, color: Colors.green[700]),
            SizedBox(width: 8),
            Text(tipo,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700])),
          ],
        ),
      ));
      for (final alimento in grupos[tipo]!) {
        widgets.add(_buildAlimentoCard(alimento));
      }
    }
    return widgets;
  }

  Widget _buildAlimentoCard(DocumentSnapshot alimento) {
    final data = alimento.data() as Map<String, dynamic>;
    final isSelected = _alimentosSeleccionados.containsKey(alimento.id);
    final cantidad = isSelected ? _alimentosSeleccionados[alimento.id]! : 1;

    return Card(
      margin: EdgeInsets.only(bottom: 10),
      color: isSelected ? Colors.green[50] : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.green : Colors.grey[300]!,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (isSelected) {
            _alimentosSeleccionados.remove(alimento.id);
          } else {
            _alimentosSeleccionados[alimento.id] = 1;
          }
          _precioTotal = _calcularPrecioTotal();
          _calcularSaldoPendiente();
        }),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconoTipoAlimento(data['tipo']),
                  color: Colors.green[700], size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(data['nombre'],
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: Colors.green),
                    ]),
                    Text(
                      'Precio: \$${data['precio']} por servicio',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700]),
                    ),
                    if (isSelected)
                      _buildAlimentoCounter(alimento.id, cantidad),
                    if (data['descripcion'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(data['descripcion']),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _notasController,
                        decoration: InputDecoration(
                          labelText: 'Notas u observaciones',
                          hintText:
                              'Ej: viene con mascota, requiere cuna, alérgico a...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 3,
                        maxLength: 300,
                      ),
                    ]),
                    SizedBox(height: 20),

                    // Sección: Tipo de Reserva
                    _buildCard('Tipo de Reserva', [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoriaChip(
                              label: 'Hospedaje',
                              subtitle: 'Con alojamiento',
                              icon: Icons.hotel,
                              selected: _tipoReserva == 'hospedaje',
                              onTap: () => setState(() {
                                _tipoReserva = 'hospedaje';
                                _categoriaAlojamiento = null;
                                _tipoAlojamientoSeleccionado = null;
                                _alojamientosSeleccionados.clear();
                                _horaEntradaPasadia = null;
                                _horaSalidaPasadia = null;
                                _fechaEntrada = null;
                                _fechaSalida = null;
                                _disponibilidadVerificada = false;
                                _mostrarActividades = false;
                                _mostrarAlimentos = false;
                                _precioTotal = _calcularPrecioTotal();
                                _calcularSaldoPendiente();
                              }),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildCategoriaChip(
                              label: 'Pasadía',
                              subtitle: 'Solo por el día',
                              icon: Icons.wb_sunny,
                              selected: _tipoReserva == 'pasadia',
                              onTap: () => setState(() {
                                _tipoReserva = 'pasadia';
                                _categoriaAlojamiento = null;
                                _tipoAlojamientoSeleccionado = null;
                                _alojamientosSeleccionados.clear();
                                _fechaEntrada = null;
                                _fechaSalida = null;
                                _disponibilidadVerificada = false;
                                _mostrarActividades = false;
                                _mostrarAlimentos = false;
                                _precioTotal = _calcularPrecioTotal();
                                _calcularSaldoPendiente();
                              }),
                            ),
                          ),
                        ],
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
                      if (_tipoReserva == 'hospedaje') ...[
                        ListTile(
                          leading: Icon(Icons.calendar_today,
                              color: Colors.green[700]),
                          title: Text('Fecha de Entrada'),
                          subtitle: Text(_fechaEntrada == null
                              ? 'Seleccionar fecha'
                              : DateFormat('dd/MM/yyyy').format(_fechaEntrada!)),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () => _seleccionarFecha(true),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.calendar_today,
                              color: Colors.green[700]),
                          title: Text('Fecha de Salida'),
                          subtitle: Text(_fechaSalida == null
                              ? 'Seleccionar fecha'
                              : DateFormat('dd/MM/yyyy').format(_fechaSalida!)),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () => _seleccionarFecha(false),
                        ),
                      ] else ...[
                        ListTile(
                          leading: Icon(Icons.calendar_today,
                              color: Colors.green[700]),
                          title: Text('Fecha de la Pasadía'),
                          subtitle: Text(_fechaEntrada == null
                              ? 'Seleccionar fecha'
                              : DateFormat('dd/MM/yyyy').format(_fechaEntrada!)),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: _seleccionarFechaPasadia,
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.access_time,
                              color: Colors.green[700]),
                          title: Text('Hora de Entrada'),
                          subtitle: Text(_horaEntradaPasadia == null
                              ? 'Seleccionar hora'
                              : _horaEntradaPasadia!.format(context)),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () => _seleccionarHoraPasadia(true),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.access_time,
                              color: Colors.green[700]),
                          title: Text('Hora de Salida'),
                          subtitle: Text(_horaSalidaPasadia == null
                              ? 'Seleccionar hora'
                              : _horaSalidaPasadia!.format(context)),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () => _seleccionarHoraPasadia(false),
                        ),
                      ],
                    ]),
                    SizedBox(height: 20),

                    // Sección 3: Categoría y Tipo de Alojamiento
                    _buildCard('Tipo de Alojamiento', [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoriaChip(
                              label: 'Alojamiento rural',
                              subtitle: 'Habitación, cabaña, apto',
                              icon: Icons.house,
                              selected: _categoriaAlojamiento == 'rural',
                              onTap: () => setState(() {
                                _categoriaAlojamiento = 'rural';
                                _tipoAlojamientoSeleccionado = null;
                                _alojamientosSeleccionados.clear();
                                _disponibilidadVerificada = false;
                                _precioTotal = _calcularPrecioTotal();
                                _calcularSaldoPendiente();
                              }),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildCategoriaChip(
                              label: 'Zona de camping',
                              subtitle: 'Con o sin equipo',
                              icon: Icons.forest,
                              selected: _categoriaAlojamiento == 'camping',
                              onTap: () => setState(() {
                                _categoriaAlojamiento = 'camping';
                                _tipoAlojamientoSeleccionado = null;
                                _alojamientosSeleccionados.clear();
                                _disponibilidadVerificada = false;
                                _precioTotal = _calcularPrecioTotal();
                                _calcularSaldoPendiente();
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (_categoriaAlojamiento == 'rural') ...[
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _tipoAlojamientoSeleccionado,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Seleccione un tipo',
                          ),
                          items: _tiposRural
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
                              _categoriaAlojamiento == 'rural' && value == null
                                  ? 'Seleccione un tipo'
                                  : null,
                        ),
                      ],
                      if (_categoriaAlojamiento == 'camping') ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCategoriaChip(
                                label: 'Con equipo',
                                subtitle: 'Carpa incluida',
                                icon: Icons.cabin,
                                selected: _tipoAlojamientoSeleccionado ==
                                    _tipoCampingConEquipo,
                                onTap: () => setState(() {
                                  _tipoAlojamientoSeleccionado =
                                      _tipoCampingConEquipo;
                                  _alojamientosSeleccionados.clear();
                                  _disponibilidadVerificada = false;
                                  _precioTotal = _calcularPrecioTotal();
                                  _calcularSaldoPendiente();
                                }),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildCategoriaChip(
                                label: 'Sin equipo',
                                subtitle: 'Trae su carpa',
                                icon: Icons.backpack,
                                selected: _tipoAlojamientoSeleccionado ==
                                    _tipoCampingSinEquipo,
                                onTap: () => setState(() {
                                  _tipoAlojamientoSeleccionado =
                                      _tipoCampingSinEquipo;
                                  _alojamientosSeleccionados.clear();
                                  _disponibilidadVerificada = false;
                                  _precioTotal = _calcularPrecioTotal();
                                  _calcularSaldoPendiente();
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                          onSi: () =>
                              setState(() => _deseaActividades = true),
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
                                      _actividadesSeleccionadas[
                                          actividad.id] = 1;
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

                    // Descuento (opcional) — solo sobre alojamiento y
                    // actividades, nunca sobre alimentos.
                    if (_mostrarActividades || _mostrarAlimentos) ...[
                      SizedBox(height: 20),
                      _buildCard('Descuento (opcional)', [
                        Row(
                          children: [
                            Expanded(
                              child: _buildCategoriaChip(
                                label: 'Sin descuento',
                                subtitle: 'Precio normal',
                                icon: Icons.block,
                                selected: _tipoDescuento == 'ninguno',
                                onTap: () => setState(() {
                                  _tipoDescuento = 'ninguno';
                                  _descuentoController.clear();
                                  _precioTotal = _calcularPrecioTotal();
                                  _calcularSaldoPendiente();
                                }),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildCategoriaChip(
                                label: 'Porcentaje',
                                subtitle: 'Ej. 15%',
                                icon: Icons.percent,
                                selected: _tipoDescuento == 'porcentaje',
                                onTap: () => setState(() {
                                  _tipoDescuento = 'porcentaje';
                                  _precioTotal = _calcularPrecioTotal();
                                  _calcularSaldoPendiente();
                                }),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildCategoriaChip(
                                label: 'Valor fijo',
                                subtitle: 'Ej. \$20.000',
                                icon: Icons.attach_money,
                                selected: _tipoDescuento == 'fijo',
                                onTap: () => setState(() {
                                  _tipoDescuento = 'fijo';
                                  _precioTotal = _calcularPrecioTotal();
                                  _calcularSaldoPendiente();
                                }),
                              ),
                            ),
                          ],
                        ),
                        if (_tipoDescuento != 'ninguno') ...[
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _descuentoController,
                            decoration: InputDecoration(
                              labelText: _tipoDescuento == 'porcentaje'
                                  ? 'Porcentaje de descuento'
                                  : 'Valor del descuento',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(_tipoDescuento == 'porcentaje'
                                  ? Icons.percent
                                  : Icons.attach_money),
                              helperText:
                                  'Se aplica solo sobre alojamiento y '
                                  'actividades. Los alimentos no llevan '
                                  'descuento.',
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {
                              _precioTotal = _calcularPrecioTotal();
                              _calcularSaldoPendiente();
                            }),
                          ),
                          if (_calcularMontoDescuento() > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Descuento aplicado: -\$${_calcularMontoDescuento().toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ]),
                    ],

                    // Sección 7: Pago
                    // Sección 6: Alimentos
                    if (_mostrarAlimentos) ...[
                      SizedBox(height: 20),
                      _buildCard('Servicio de Alimentos', [
                        Text(
                            '¿Desea incluir servicio de alimentos durante su estadía?'),
                        SizedBox(height: 10),
                        _buildSiNo(
                          valor: _deseaAlimentos,
                          onSi: () =>
                              setState(() => _deseaAlimentos = true),
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
                            ..._buildAlimentosAgrupados(),
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
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              _buildResumenFila(
                                  'Huéspedes:', '$huespedes'),
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
                        color:
                            _saldoPendiente > 0 ? Colors.red : Colors.green,
                      ),
                      if (_metodoPagoSeleccionado != null)
                        _buildResumenFila(
                            'Método de pago:', _metodoPagoSeleccionado!),
                      if (_notasController.text.isNotEmpty) ...[
                        Divider(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes,
                                size: 16, color: Colors.grey[600]),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _notasController.text,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ]),
                    SizedBox(height: 20),

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
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}