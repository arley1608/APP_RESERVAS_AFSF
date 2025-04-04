import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ReservationScreen extends StatefulWidget {
  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  // Controladores
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _huespedesController =
      TextEditingController(text: '1');

  // Fechas
  DateTime? _fechaEntrada;
  DateTime? _fechaSalida;

  // Estados de carga
  bool _isLoadingAlojamientos = false;
  bool _isLoadingDisponibilidad = false;
  bool _isLoadingReserva = false;

  // Datos del alojamiento
  String? _tipoAlojamientoSeleccionado;
  List<DocumentSnapshot> _alojamientosSeleccionados = [];
  double? _precioTotal;
  bool _disponibilidadVerificada = false;
  bool _todosAlojamientosDisponibles =
      false; // Cambiado de _alojamientosDisponibles

  // Listas
  final List<String> _tiposAlojamiento = [
    'Habitación Superior',
    'Habitación Standard',
    'Cabaña',
    'Apartamento',
    'Zona de Camping'
  ];
  List<DocumentSnapshot> _listaAlojamientosDisponibles =
      []; // Cambiado de _alojamientosDisponibles

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _cargarAlojamientos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _huespedesController.dispose();
    super.dispose();
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

      for (var alojamiento in _alojamientosSeleccionados) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('reservas')
            .where('alojamientoId', isEqualTo: alojamiento.id)
            .get();

        final reservasSuperpuestas = querySnapshot.docs.where((reserva) {
          final reservaData = reserva.data() as Map<String, dynamic>;
          final fechaEntradaReserva =
              (reservaData['fechaEntrada'] as Timestamp).toDate();
          final fechaSalidaReserva =
              (reservaData['fechaSalida'] as Timestamp).toDate();

          return fechaEntradaReserva.isBefore(_fechaSalida!) &&
              fechaSalidaReserva.isAfter(_fechaEntrada!);
        }).toList();

        if (reservasSuperpuestas.isNotEmpty) {
          todosDisponibles = false;
          break;
        }
      }

      setState(() {
        _disponibilidadVerificada = true;
        _todosAlojamientosDisponibles = todosDisponibles;
        _precioTotal = _calcularPrecioTotal();
      });

      if (!todosDisponibles) {
        throw Exception('Uno o más alojamientos no están disponibles');
      }

      _mostrarExito(
        'Todos los alojamientos están disponibles para las fechas seleccionadas\n'
        'Fechas: ${DateFormat('dd/MM/yyyy').format(_fechaEntrada!)} - ${DateFormat('dd/MM/yyyy').format(_fechaSalida!)}\n'
        'Precio Total: \$${_precioTotal!.toStringAsFixed(2)}',
      );
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      setState(() => _isLoadingDisponibilidad = false);
    }
  }

  double? _calcularPrecioTotal() {
    if (_fechaEntrada == null || _fechaSalida == null) return null;

    final numHuespedes = int.tryParse(_huespedesController.text) ?? 1;
    final numNoches = _fechaSalida!.difference(_fechaEntrada!).inDays;

    if (numNoches <= 0 || numHuespedes <= 0) return null;

    double total = 0;
    for (var alojamiento in _alojamientosSeleccionados) {
      final data = alojamiento.data() as Map<String, dynamic>;
      final precioPorNoche = (data['precio'] as num?)?.toDouble() ?? 0;
      total += precioPorNoche * numHuespedes * numNoches;
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

    setState(() => _isLoadingReserva = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final precioTotal = _calcularPrecioTotal();
      if (precioTotal == null) throw Exception('Error al calcular el precio');

      final batch = FirebaseFirestore.instance.batch();
      final reservasRef = FirebaseFirestore.instance.collection('reservas');

      final reservationGroupId =
          FirebaseFirestore.instance.collection('reservas').doc().id;

      for (var alojamiento in _alojamientosSeleccionados) {
        final docRef = reservasRef.doc();
        batch.set(docRef, {
          'reservationGroupId': reservationGroupId,
          'alojamientoId': alojamiento.id,
          'alojamientoNombre': alojamiento['nombre'],
          'tipoAlojamiento': alojamiento['tipo'],
          'usuarioId': user.uid,
          'nombre': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'huespedes': int.parse(_huespedesController.text),
          'fechaEntrada': Timestamp.fromDate(_fechaEntrada!),
          'fechaSalida': Timestamp.fromDate(_fechaSalida!),
          'precioPorAlojamiento': (alojamiento['precio'] as num).toDouble() *
              int.parse(_huespedesController.text) *
              _fechaSalida!.difference(_fechaEntrada!).inDays,
          'precioTotal': precioTotal,
          'estado': 'pendiente',
          'creadoEn': FieldValue.serverTimestamp(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      _mostrarExito(
          'Reserva creada correctamente para ${_alojamientosSeleccionados.length} alojamientos');
      _limpiarFormulario();
    } catch (e) {
      _mostrarError('Error al crear reserva: ${e.toString()}');
    } finally {
      setState(() => _isLoadingReserva = false);
    }
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _emailController.clear();
    _telefonoController.clear();
    _huespedesController.text = '1';
    setState(() {
      _fechaEntrada = null;
      _fechaSalida = null;
      _tipoAlojamientoSeleccionado = null;
      _alojamientosSeleccionados.clear();
      _precioTotal = null;
      _disponibilidadVerificada = false;
      _todosAlojamientosDisponibles = false;
    });
  }

  Future<void> _seleccionarFecha(bool esEntrada) async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: esEntrada
          ? DateTime.now()
          : _fechaEntrada?.add(const Duration(days: 1)) ??
              DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
              _fechaSalida!
                  .isBefore(_fechaEntrada!.add(const Duration(days: 1)))) {
            _fechaSalida = _fechaEntrada!.add(const Duration(days: 1));
          }
        } else {
          _fechaSalida = fechaSeleccionada;
        }
        _disponibilidadVerificada = false;
        _precioTotal = _calcularPrecioTotal();
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

  void _mostrarExito(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text('Éxito',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Aceptar"),
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
            const SizedBox(width: 10),
            Text('Error',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      keyboardType: keyboardType,
      validator: validator,
      onChanged: (value) {
        if (onChanged != null) onChanged(value);
        setState(() {
          _precioTotal = _calcularPrecioTotal();
        });
      },
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(Icons.calendar_today, color: Colors.green[700]),
      title: Text(label),
      subtitle: Text(date == null
          ? 'Seleccionar fecha'
          : DateFormat('dd/MM/yyyy').format(date)),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }

  Widget _buildAlojamientoCard({
    required Map<String, dynamic> data,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected ? Colors.green[50] : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.green : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tipo: ${data['tipo']}',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text('Capacidad: ${data['capacidad']} personas'),
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
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(data['descripcion']),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildResumenItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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
                    _buildSectionCard(
                      title: 'Datos Personales',
                      children: [
                        _buildTextFormField(
                          controller: _nombreController,
                          label: 'Nombre Completo',
                          icon: Icons.person,
                          validator: (value) =>
                              value!.isEmpty ? 'Ingrese su nombre' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: _emailController,
                          label: 'Correo Electrónico',
                          icon: Icons.email,
                          validator: (value) => !value!.contains('@')
                              ? 'Ingrese un correo válido'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: _telefonoController,
                          label: 'Teléfono',
                          icon: Icons.phone,
                          validator: (value) =>
                              value!.length < 8 ? 'Mínimo 8 caracteres' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sección 2: Detalles de la Reserva
                    _buildSectionCard(
                      title: 'Detalles de la Reserva',
                      children: [
                        _buildTextFormField(
                          controller: _huespedesController,
                          label: 'Número de Huéspedes',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final num = int.tryParse(value ?? '');
                            return num == null || num < 1
                                ? 'Número inválido'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDateTile(
                          label: 'Fecha de Entrada',
                          date: _fechaEntrada,
                          onTap: () => _seleccionarFecha(true),
                        ),
                        const Divider(),
                        _buildDateTile(
                          label: 'Fecha de Salida',
                          date: _fechaSalida,
                          onTap: () => _seleccionarFecha(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sección 3: Tipo de Alojamiento
                    _buildSectionCard(
                      title: 'Tipo de Alojamiento',
                      children: [
                        DropdownButtonFormField<String>(
                          value: _tipoAlojamientoSeleccionado,
                          decoration: const InputDecoration(
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
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Seleccione un tipo' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sección 4: Alojamientos Disponibles
                    if (_tipoAlojamientoSeleccionado != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Alojamientos Disponibles ($_tipoAlojamientoSeleccionado)',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (alojamientosFiltrados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              'No hay alojamientos disponibles de este tipo'),
                        )
                      else
                        ...alojamientosFiltrados.map((alojamiento) {
                          final data =
                              alojamiento.data() as Map<String, dynamic>;
                          final isSelected = _alojamientosSeleccionados
                              .any((a) => a.id == alojamiento.id);

                          return _buildAlojamientoCard(
                            data: data,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _alojamientosSeleccionados.removeWhere(
                                      (a) => a.id == alojamiento.id);
                                } else {
                                  _alojamientosSeleccionados.add(alojamiento);
                                }
                                _disponibilidadVerificada = false;
                                _precioTotal = _calcularPrecioTotal();
                              });
                            },
                          );
                        }),
                      const SizedBox(height: 20),

                      // Resumen de alojamientos seleccionados
                      if (_alojamientosSeleccionados.isNotEmpty) ...[
                        Text(
                          'Alojamientos seleccionados: ${_alojamientosSeleccionados.length}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ..._alojamientosSeleccionados.map((alojamiento) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '- ${alojamiento['nombre']}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],

                      if (_alojamientosSeleccionados.isNotEmpty &&
                          _fechaEntrada != null &&
                          _fechaSalida != null)
                        _buildActionButton(
                          text: 'Verificar Disponibilidad',
                          color: Colors.blue,
                          onPressed: _verificarDisponibilidad,
                          isLoading: _isLoadingDisponibilidad,
                        ),

                      if (_disponibilidadVerificada)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Card(
                            color: _todosAlojamientosDisponibles
                                ? Colors.green[50]
                                : Colors.red[50],
                            child: Padding(
                              padding: const EdgeInsets.all(16),
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
                                  const SizedBox(width: 10),
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

                    // Sección 5: Resumen de Reserva
                    _buildSectionCard(
                      title: 'Resumen de Reserva',
                      children: [
                        _buildResumenItem(
                          'Alojamientos seleccionados:',
                          _alojamientosSeleccionados.length.toString(),
                        ),
                        if (_tipoAlojamientoSeleccionado != null)
                          _buildResumenItem(
                            'Tipo:',
                            _tipoAlojamientoSeleccionado!,
                          ),
                        _buildResumenItem(
                          'Huéspedes:',
                          _huespedesController.text,
                        ),
                        _buildResumenItem(
                          'Fecha Entrada:',
                          _fechaEntrada != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaEntrada!)
                              : 'No seleccionada',
                        ),
                        _buildResumenItem(
                          'Fecha Salida:',
                          _fechaSalida != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaSalida!)
                              : 'No seleccionada',
                        ),
                        _buildResumenItem(
                          'Noches:',
                          numNoches.toString(),
                        ),
                        const Divider(),
                        if (_precioTotal != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Precio Total:',
                                style: TextStyle(fontWeight: FontWeight.bold),
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
                          const Text(
                            'Complete los datos para ver el precio',
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón de Confirmación
                    _buildActionButton(
                      text: 'Confirmar Reserva',
                      color: Colors.green[700]!,
                      onPressed:
                          (_isLoadingReserva || !_todosAlojamientosDisponibles)
                              ? null
                              : _crearReserva,
                      isLoading: _isLoadingReserva,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
