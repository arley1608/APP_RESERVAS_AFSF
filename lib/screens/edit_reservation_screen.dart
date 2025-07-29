import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EditReservationScreen extends StatefulWidget {
  @override
  _EditReservationScreenState createState() => _EditReservationScreenState();
}

class _EditReservationScreenState extends State<EditReservationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _reservasStream;
  DateTime _fechaConsulta = DateTime.now();
  bool _isAdmin = false;
  bool _isOperator = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _reservasStream = _firestore
        .collection('reservas')
        .where('fechaEntrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                _fechaConsulta.year, _fechaConsulta.month, _fechaConsulta.day)))
        .orderBy('fechaEntrada')
        .snapshots();
  }

  Future<void> _loadUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc =
          await _firestore.collection('usuarios').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.data()?['rol'] == 'admin';
        _isOperator = userDoc.data()?['rol'] == 'operador';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaConsulta,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.grey[800]!,
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

    if (picked != null && picked != _fechaConsulta) {
      setState(() {
        _fechaConsulta = picked;
        _reservasStream = _firestore
            .collection('reservas')
            .where('fechaEntrada',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(picked.year, picked.month, picked.day)))
            .orderBy('fechaEntrada')
            .snapshots();
      });
    }
  }

  Color _getStatusColor(String? status) {
    final normalizedStatus = status?.isNotEmpty ?? false
        ? '${status![0].toUpperCase()}${status.substring(1).toLowerCase()}'
        : 'Pendiente';

    switch (normalizedStatus) {
      case 'Confirmada':
        return Colors.green;
      case 'Cancelada':
        return Colors.red;
      case 'Pendiente':
        return Colors.orange;
      case 'Completada':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reservas Activas'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reservasStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar reservas'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text('No hay reservas activas para esta fecha'));
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var reserva = snapshot.data!.docs[index];
              var data = reserva.data() as Map<String, dynamic>;
              return _buildReservaCard(reserva.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildReservaCard(String reservaId, Map<String, dynamic> data) {
    final fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    final fechaSalida = (data['fechaSalida'] as Timestamp).toDate();
    final noches = fechaSalida.difference(fechaEntrada).inDays;
    final puedeEliminar = _puedeEliminarReserva(data);

    final estado = data['estado'] ?? 'pendiente';
    final estadoNormalizado = estado.isNotEmpty
        ? '${estado[0].toUpperCase()}${estado.substring(1).toLowerCase()}'
        : 'Pendiente';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reserva #${reservaId.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Chip(
                  label: Text(
                    estadoNormalizado,
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _getStatusColor(estado),
                ),
              ],
            ),
            Divider(),
            Text(
              'Datos Personales',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildInfoRow('Nombre', data['nombre'] ?? 'No especificado'),
            _buildInfoRow('Email', data['email'] ?? 'No especificado'),
            _buildInfoRow('Teléfono', data['telefono'] ?? 'No especificado'),
            SizedBox(height: 8),
            Text(
              'Alojamiento',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildInfoRow('Tipo', data['tipoAlojamiento'] ?? 'No especificado'),
            _buildInfoRow('Huéspedes', data['huespedes']?.toString() ?? '1'),
            SizedBox(height: 8),
            Text(
              'Fechas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildInfoRow(
                'Entrada', DateFormat('dd/MM/yyyy').format(fechaEntrada)),
            _buildInfoRow(
                'Salida', DateFormat('dd/MM/yyyy').format(fechaSalida)),
            _buildInfoRow('Noches', noches.toString()),
            SizedBox(height: 8),
            Text(
              'Pagos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildInfoRow(
                'Total', '\$${(data['precioTotal'] ?? 0).toStringAsFixed(2)}'),
            if (data['abono'] != null)
              _buildInfoRow('Abonado', '\$${data['abono'].toStringAsFixed(2)}'),
            if (data['saldoPendiente'] != null)
              _buildInfoRow(
                'Saldo',
                '\$${data['saldoPendiente'].toStringAsFixed(2)}',
                style: TextStyle(
                  color: (data['saldoPendiente'] ?? 0) > 0
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: Size(100, 40),
                  ),
                  onPressed: () => _editarReserva(reservaId, data),
                  child: Text('Editar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    minimumSize: Size(100, 40),
                  ),
                  onPressed: () => _cancelarReserva(reservaId),
                  child: Text('Cancelar'),
                ),
                if (puedeEliminar)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      minimumSize: Size(100, 40),
                    ),
                    onPressed: () => _confirmarEliminacion(reservaId, context),
                    child: Text('Eliminar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: style ?? TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoExito(String mensaje) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Éxito', style: TextStyle(color: Colors.green)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Aceptar', style: TextStyle(color: Colors.green[700])),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoError(String mensaje) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Aceptar', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  Future<void> _editarReserva(
      String reservaId, Map<String, dynamic> data) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReservationEditScreen(
          reservaId: reservaId,
          reservaData: data,
        ),
      ),
    );

    if (result == true) {
      await _mostrarDialogoExito('Reserva actualizada correctamente');
    }
  }

  Future<void> _cancelarReserva(String reservaId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar cancelación'),
        content: Text('¿Estás seguro de cancelar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sí, cancelar',
                style: TextStyle(color: Colors.orange[700])),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('reservas').doc(reservaId).update({
          'estado': 'cancelada',
          'fechaCancelacion': FieldValue.serverTimestamp(),
        });
        await _mostrarDialogoExito('Reserva cancelada correctamente');
      } catch (e) {
        await _mostrarDialogoError('Error al cancelar reserva: $e');
      }
    }
  }

  bool _puedeEliminarReserva(Map<String, dynamic> reservaData) {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (_isAdmin) return true;
    if (_isOperator && reservaData['creadoPor'] == user.uid) return true;
    return false;
  }

  Future<void> _confirmarEliminacion(
      String reservaId, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text(
            '¿Estás seguro de eliminar permanentemente esta reserva? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('reservas').doc(reservaId).delete();
        await _mostrarDialogoExito('Reserva eliminada correctamente');
      } catch (e) {
        await _mostrarDialogoError('Error al eliminar reserva: $e');
      }
    }
  }
}

class ReservationEditScreen extends StatefulWidget {
  final String reservaId;
  final Map<String, dynamic> reservaData;

  const ReservationEditScreen({
    Key? key,
    required this.reservaId,
    required this.reservaData,
  }) : super(key: key);

  @override
  _ReservationEditScreenState createState() => _ReservationEditScreenState();
}

class _ReservationEditScreenState extends State<ReservationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late TextEditingController _huespedesController;
  late TextEditingController _precioTotalController;
  late TextEditingController _abonoController;
  late TextEditingController _notasController;
  late DateTime _fechaEntrada;
  late DateTime _fechaSalida;
  late int _noches;
  late String _estado;
  late String _tipoAlojamiento;
  late String _metodoPago;

  final List<String> _estados = [
    'Pendiente',
    'Confirmada',
    'Cancelada',
    'Completada'
  ];
  final List<String> _tiposAlojamiento = [
    'Cabaña Deluxe',
    'Habitación Standard',
    'Suite Ejecutiva',
    'Departamento Familiar'
  ];
  final List<String> _metodosPago = [
    'Efectivo',
    'Tarjeta Crédito',
    'Transferencia',
    'PayPal'
  ];

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  void _inicializarDatos() {
    _fechaEntrada = (widget.reservaData['fechaEntrada'] as Timestamp).toDate();
    _fechaSalida = (widget.reservaData['fechaSalida'] as Timestamp).toDate();
    _noches = _fechaSalida.difference(_fechaEntrada).inDays;

    String estadoFromData = widget.reservaData['estado'] ?? 'Pendiente';
    _estado = estadoFromData.isNotEmpty
        ? '${estadoFromData[0].toUpperCase()}${estadoFromData.substring(1).toLowerCase()}'
        : 'Pendiente';

    if (!_estados.contains(_estado)) {
      _estado = 'Pendiente';
    }

    _tipoAlojamiento =
        widget.reservaData['tipoAlojamiento'] ?? 'Habitación Standard';
    _metodoPago = widget.reservaData['metodoPago'] ?? 'Efectivo';

    _nombreController =
        TextEditingController(text: widget.reservaData['nombre'] ?? '');
    _emailController =
        TextEditingController(text: widget.reservaData['email'] ?? '');
    _telefonoController =
        TextEditingController(text: widget.reservaData['telefono'] ?? '');
    _huespedesController = TextEditingController(
        text: widget.reservaData['huespedes']?.toString() ?? '1');
    _precioTotalController = TextEditingController(
        text: (widget.reservaData['precioTotal'] ?? 0).toStringAsFixed(2))
      ..addListener(_actualizarSaldo);
    _abonoController = TextEditingController(
        text: (widget.reservaData['abono'] ?? 0).toStringAsFixed(2))
      ..addListener(_actualizarSaldo);
    _notasController =
        TextEditingController(text: widget.reservaData['notas'] ?? '');
  }

  void _actualizarSaldo() {
    setState(() {});
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _huespedesController.dispose();
    _precioTotalController.dispose();
    _abonoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isEntrada) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isEntrada ? _fechaEntrada : _fechaSalida,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.grey[800]!,
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

    if (picked != null) {
      setState(() {
        if (isEntrada) {
          _fechaEntrada = picked;
          if (_fechaEntrada.isAfter(_fechaSalida)) {
            _fechaSalida = _fechaEntrada.add(Duration(days: 1));
          }
        } else {
          _fechaSalida = picked;
          if (_fechaSalida.isBefore(_fechaEntrada)) {
            _fechaEntrada = _fechaSalida.subtract(Duration(days: 1));
          }
        }
        _noches = _fechaSalida.difference(_fechaEntrada).inDays;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmada':
        return Colors.green;
      case 'Cancelada':
        return Colors.red;
      case 'Pendiente':
        return Colors.orange;
      case 'Completada':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSaldoPendiente() {
    final total = double.tryParse(_precioTotalController.text) ?? 0;
    final abono = double.tryParse(_abonoController.text) ?? 0;
    final saldo = total - abono;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Saldo Pendiente:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '\$${saldo.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: saldo > 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarCambios() async {
    if (_formKey.currentState!.validate()) {
      try {
        final total = double.tryParse(_precioTotalController.text) ?? 0;
        final abono = double.tryParse(_abonoController.text) ?? 0;

        await FirebaseFirestore.instance
            .collection('reservas')
            .doc(widget.reservaId)
            .update({
          'nombre': _nombreController.text,
          'email': _emailController.text,
          'telefono': _telefonoController.text,
          'huespedes': int.tryParse(_huespedesController.text) ?? 1,
          'tipoAlojamiento': _tipoAlojamiento,
          'fechaEntrada': Timestamp.fromDate(_fechaEntrada),
          'fechaSalida': Timestamp.fromDate(_fechaSalida),
          'precioTotal': total,
          'abono': abono,
          'saldoPendiente': total - abono,
          'estado': _estado,
          'metodoPago': _metodoPago,
          'notas': _notasController.text,
        });

        Navigator.pop(context, true);
      } catch (e) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error', style: TextStyle(color: Colors.red)),
            content: Text('No se pudieron guardar los cambios: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Editar Reserva #${widget.reservaId.substring(0, 6).toUpperCase()}'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _guardarCambios,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección de Estado y Fechas
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estado:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_estado).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(_estado),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _estado,
                                icon: Icon(Icons.arrow_drop_down,
                                    color: _getStatusColor(_estado)),
                                style: TextStyle(
                                  color: _getStatusColor(_estado),
                                  fontWeight: FontWeight.bold,
                                ),
                                items: _estados.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _estado = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              'Fecha Entrada',
                              DateFormat('EEE, d MMM y').format(_fechaEntrada),
                              () => _selectDate(context, true),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              'Fecha Salida',
                              DateFormat('EEE, d MMM y').format(_fechaSalida),
                              () => _selectDate(context, false),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Chip(
                          label: Text(
                            '$_noches ${_noches == 1 ? 'Noche' : 'Noches'}',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Sección de Información del Cliente
              _buildSectionTitle('Información del Cliente'),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTextFormField(
                          _nombreController, 'Nombre Completo', Icons.person),
                      SizedBox(height: 12),
                      _buildTextFormField(
                          _emailController, 'Email', Icons.email,
                          keyboardType: TextInputType.emailAddress),
                      SizedBox(height: 12),
                      _buildTextFormField(
                          _telefonoController, 'Teléfono', Icons.phone,
                          keyboardType: TextInputType.phone),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Sección de Alojamiento
              _buildSectionTitle('Detalles del Alojamiento'),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDropdownFormField(
                        'Tipo de Alojamiento',
                        _tipoAlojamiento,
                        _tiposAlojamiento,
                        Icons.home,
                        (newValue) =>
                            setState(() => _tipoAlojamiento = newValue!),
                      ),
                      SizedBox(height: 12),
                      _buildTextFormField(
                        _huespedesController,
                        'Número de Huéspedes',
                        Icons.people,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value!.isEmpty) return 'Campo requerido';
                          if (int.tryParse(value) == null)
                            return 'Número inválido';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Sección de Pagos
              _buildSectionTitle('Información de Pago'),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDropdownFormField(
                        'Método de Pago',
                        _metodoPago,
                        _metodosPago,
                        Icons.payment,
                        (newValue) => setState(() => _metodoPago = newValue!),
                      ),
                      SizedBox(height: 12),
                      _buildTextFormField(
                        _precioTotalController,
                        'Precio Total (\$)',
                        Icons.attach_money,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value!.isEmpty) return 'Campo requerido';
                          if (double.tryParse(value) == null)
                            return 'Valor inválido';
                          return null;
                        },
                        onChanged: (value) => _actualizarSaldo(),
                      ),
                      SizedBox(height: 12),
                      _buildTextFormField(
                        _abonoController,
                        'Abono Inicial (\$)',
                        Icons.credit_card,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) => _actualizarSaldo(),
                      ),
                      SizedBox(height: 12),
                      _buildSaldoPendiente(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Sección de Notas
              _buildSectionTitle('Notas Adicionales'),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _notasController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Escribe aquí cualquier nota adicional...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Botones de Acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.green[700]!),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('CANCELAR',
                          style: TextStyle(color: Colors.green[700])),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _guardarCambios,
                      child: Text('GUARDAR CAMBIOS',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.green[700]!),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownFormField(
    String label,
    String value,
    List<String> items,
    IconData icon,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.green[700]!),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.green[700]),
          style: TextStyle(color: Colors.grey[800], fontSize: 16),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateField(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today, color: Colors.green[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.green[700]!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: TextStyle(fontSize: 16)),
            Icon(Icons.arrow_drop_down, color: Colors.green[700]),
          ],
        ),
      ),
    );
  }
}
