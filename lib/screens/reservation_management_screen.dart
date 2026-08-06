import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'guest_account_screen.dart';

class ReservationManagementScreen extends StatefulWidget {
  const ReservationManagementScreen({Key? key}) : super(key: key);

  @override
  _ReservationManagementScreenState createState() =>
      _ReservationManagementScreenState();
}

class _ReservationManagementScreenState
    extends State<ReservationManagementScreen> {
  final FirestoreService _service = FirestoreService();
  late Stream<QuerySnapshot> _reservationsStream;
  String _filterStatus = 'todas';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  DateTime? _fechaFiltroDesde;
  DateTime? _fechaFiltroHasta;

  final List<String> _statusOptions = [
    'todas',
    'pendiente',
    'confirmada',
    'activa',
    'completada',
    'cancelada',
  ];

  @override
  void initState() {
    super.initState();
    _reservationsStream = _service.getReservas();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Corta el ID de forma segura: los IDs autogenerados de Firestore
  // siempre tienen 20+ caracteres, pero por si algún día se usan IDs
  // personalizados más cortos, evitamos un RangeError.
  String _idCorto(String id) => id.length >= 8 ? id.substring(0, 8) : id;

  Future<void> _hacerCheckin(String reservationId, Map<String, dynamic> data) async {
    final fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final entradaSinHora =
        DateTime(fechaEntrada.year, fechaEntrada.month, fechaEntrada.day);

    if (hoySinHora.isBefore(entradaSinHora)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.event_busy, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Check-in no disponible',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No es posible activar esta reserva todavía.'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.calendar_today,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text('Fecha de entrada:',
                          style: TextStyle(color: Colors.grey[700])),
                    ]),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy').format(fechaEntrada),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.orange[700]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Faltan ${entradaSinHora.difference(hoySinHora).inDays} día(s) para el check-in',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700]),
              onPressed: () => Navigator.pop(context),
              child: Text('Entendido', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.login, color: Colors.green[700], size: 28),
          SizedBox(width: 10),
          Text('Confirmar Check-in',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Confirmar llegada del huésped?',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${data['nombre']}',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Entrada: ${DateFormat('dd/MM/yyyy').format(fechaEntrada)}'),
                  Text('Salida: ${DateFormat('dd/MM/yyyy').format((data['fechaSalida'] as Timestamp).toDate())}'),
                  Text('Huéspedes: ${data['huespedesTotales'] ?? 1}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar Check-in',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.updateReserva(reservationId, {
          'estado': 'activa',
          'checkInEn': FieldValue.serverTimestamp(),
          'consumos': [],
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GuestAccountScreen(
                reservationId: reservationId,
                reservationData: data,
              ),
            ),
          );
        }
      } catch (e) {
        _showErrorDialog('Error al hacer check-in: ${e.toString()}');
      }
    }
  }

  void _abrirCuenta(String reservationId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuestAccountScreen(
          reservationId: reservationId,
          reservationData: data,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.error, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmada':
        return Colors.green;
      case 'activa':
        return Colors.teal;
      case 'cancelada':
        return Colors.red;
      case 'completada':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'confirmada':
        return Icons.check_circle;
      case 'activa':
        return Icons.hotel;
      case 'cancelada':
        return Icons.cancel;
      case 'completada':
        return Icons.task_alt;
      default:
        return Icons.pending;
    }
  }

  Widget _buildSelectorFecha(
      String placeholder, DateTime? fecha, VoidCallback onTap, VoidCallback onClear) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 18, color: Colors.green[700]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              fecha == null
                  ? placeholder
                  : DateFormat('dd/MM/yyyy').format(fecha),
              style: TextStyle(
                  color: fecha == null ? Colors.grey[600] : Colors.black),
            ),
          ),
          if (fecha != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 18, color: Colors.grey),
            ),
        ]),
      ),
    );
  }

  Future<void> _seleccionarFecha(bool esDesde) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esDesde
          ? (_fechaFiltroDesde ?? DateTime.now())
          : (_fechaFiltroHasta ?? _fechaFiltroDesde ?? DateTime.now()),
      firstDate: esDesde ? DateTime(2020) : (_fechaFiltroDesde ?? DateTime(2020)),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Colors.green[700]!),
        ),
        child: child!,
      ),
    );
    if (fecha != null) {
      setState(() {
        if (esDesde) {
          _fechaFiltroDesde = fecha;
          // Si la fecha hasta es anterior a la nueva fecha desde, limpiarla
          if (_fechaFiltroHasta != null &&
              _fechaFiltroHasta!.isBefore(fecha)) {
            _fechaFiltroHasta = null;
          }
        } else {
          _fechaFiltroHasta = fecha;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Reservas',
            style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por nombre o teléfono',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 12),

                // Estado
                DropdownButtonFormField<String>(
                  value: _filterStatus,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por estado',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _statusOptions
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Row(children: [
                              if (s != 'todas')
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(s),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(s == 'todas'
                                  ? 'Todas las reservas'
                                  : s[0].toUpperCase() + s.substring(1)),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _filterStatus = v ?? 'todas'),
                ),
                SizedBox(height: 12),

                // Filtro por fecha
                Row(
                  children: [
                    Expanded(
                      child: _buildSelectorFecha(
                        'Desde',
                        _fechaFiltroDesde,
                        () => _seleccionarFecha(true),
                        () => setState(() => _fechaFiltroDesde = null),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildSelectorFecha(
                        'Hasta',
                        _fechaFiltroHasta,
                        () => _seleccionarFecha(false),
                        () => setState(() => _fechaFiltroHasta = null),
                      ),
                    ),
                    if (_fechaFiltroDesde != null || _fechaFiltroHasta != null)
                      Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: IconButton(
                          icon: Icon(Icons.filter_alt_off, color: Colors.red),
                          tooltip: 'Limpiar fechas',
                          onPressed: () => setState(() {
                            _fechaFiltroDesde = null;
                            _fechaFiltroHasta = null;
                          }),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _reservationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final reservations =
                    (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final estado =
                      data['estado']?.toString().toLowerCase() ?? 'pendiente';

                  final matchesStatus =
                      _filterStatus == 'todas' || estado == _filterStatus;

                  final matchesSearch = _searchQuery.isEmpty ||
                      (data['nombre']
                              ?.toString()
                              .toLowerCase()
                              .contains(_searchQuery) ??
                          false) ||
                      (data['telefono']
                              ?.toString()
                              .toLowerCase()
                              .contains(_searchQuery) ??
                          false) ||
                      (data['email']
                              ?.toString()
                              .toLowerCase()
                              .contains(_searchQuery) ??
                          false);

                  // Filtro por fecha de entrada
                  bool matchesFecha = true;
                  if (data['fechaEntrada'] != null) {
                    final fechaEntrada =
                        (data['fechaEntrada'] as Timestamp).toDate();
                    final entradaSinHora = DateTime(fechaEntrada.year,
                        fechaEntrada.month, fechaEntrada.day);

                    if (_fechaFiltroDesde != null) {
                      final desdeSinHora = DateTime(_fechaFiltroDesde!.year,
                          _fechaFiltroDesde!.month, _fechaFiltroDesde!.day);
                      if (entradaSinHora.isBefore(desdeSinHora)) {
                        matchesFecha = false;
                      }
                    }
                    if (_fechaFiltroHasta != null) {
                      final hastaSinHora = DateTime(_fechaFiltroHasta!.year,
                          _fechaFiltroHasta!.month, _fechaFiltroHasta!.day);
                      if (entradaSinHora.isAfter(hastaSinHora)) {
                        matchesFecha = false;
                      }
                    }
                  }

                  return matchesStatus && matchesSearch && matchesFecha;
                }).toList();

                if (reservations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No se encontraron reservas',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final doc = reservations[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildReservationCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationCard(
      String reservationId, Map<String, dynamic> data) {
    final fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    final fechaSalida = (data['fechaSalida'] as Timestamp).toDate();
    final estado = data['estado']?.toString().toLowerCase() ?? 'pendiente';
    final noches = fechaSalida.difference(fechaEntrada).inDays;
    final total = (data['precioTotal'] ?? 0).toDouble();
    final abono = (data['abono'] ?? 0).toDouble();
    final consumosTotal = ((data['consumos'] as List?) ?? []).fold<double>(
        0, (sum, c) => sum + ((c['subtotal'] ?? 0) as num).toDouble());
    final saldo = total + consumosTotal - abono;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reserva #${_idCorto(reservationId)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700]),
                ),
                Chip(
                  avatar: Icon(_getStatusIcon(estado),
                      color: Colors.white, size: 16),
                  label: Text(estado.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: _getStatusColor(estado),
                ),
              ],
            ),
            Divider(),
            _buildFila('Cliente', data['nombre'] ?? 'N/A'),
            _buildFila('Teléfono', data['telefono'] ?? 'N/A'),
            _buildFila('Entrada', DateFormat('dd/MM/yyyy').format(fechaEntrada)),
            _buildFila('Salida', DateFormat('dd/MM/yyyy').format(fechaSalida)),
            _buildFila('Noches', '$noches'),
            _buildFila('Total reserva', '\$${total.toStringAsFixed(2)}'),
            if (consumosTotal > 0)
              _buildFila('Consumos', '\$${consumosTotal.toStringAsFixed(2)}',
                  color: Colors.orange),
            _buildFila('Abono', '\$${abono.toStringAsFixed(2)}'),
            _buildFila(
              'Saldo pendiente',
              '\$${saldo.toStringAsFixed(2)}',
              color: saldo > 0 ? Colors.red : Colors.green,
              bold: true,
            ),
            SizedBox(height: 12),

            if (estado == 'pendiente' || estado == 'confirmada')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.login, color: Colors.white),
                  label: Text('CHECK-IN',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _hacerCheckin(reservationId, data),
                ),
              ),

            if (estado == 'activa')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.receipt_long, color: Colors.white),
                  label: Text('VER CUENTA',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _abrirCuenta(reservationId, data),
                ),
              ),

            if (estado == 'completada')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.visibility),
                  label: Text('VER DETALLE'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _abrirCuenta(reservationId, data),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFila(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                  color: color)),
        ],
      ),
    );
  }
}