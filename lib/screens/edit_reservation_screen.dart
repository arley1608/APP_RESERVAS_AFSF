import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'reservation_screen.dart';

class EditReservationScreen extends StatefulWidget {
  final String rol;
  final String uid;

  const EditReservationScreen({
    Key? key,
    required this.rol,
    required this.uid,
  }) : super(key: key);

  @override
  _EditReservationScreenState createState() => _EditReservationScreenState();
}

class _EditReservationScreenState extends State<EditReservationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<QuerySnapshot> _reservationsStream;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReservations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  void _loadReservations() {
    try {
      setState(() => _isLoading = true);

      if (widget.rol == 'operador') {
        // Operador ve TODAS sus reservas sin filtro de estado
        _reservationsStream = FirebaseFirestore.instance
            .collection('reservas')
            .where('usuarioId', isEqualTo: widget.uid)
            .orderBy('fechaEntrada', descending: false)
            .snapshots();
      } else {
        // Admin ve pendientes y confirmadas para editar
        _reservationsStream = FirebaseFirestore.instance
            .collection('reservas')
            .where('estado', whereIn: ['pendiente', 'confirmada'])
            .orderBy('fechaEntrada', descending: false)
            .snapshots();
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar reservas: ${e.toString()}';
      });
    }
  }

  Future<void> _cancelReservation(String reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text('Cancelar Reserva',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: const Text('¿Estás seguro que deseas cancelar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService
            .updateReserva(reservationId, {'estado': 'cancelada'});
        _showSuccessDialog('Reserva cancelada exitosamente');
      } catch (e) {
        _showErrorDialog('No se pudo cancelar la reserva: $e');
      }
    }
  }

  void _editReservation(String reservationId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReservationScreen(
          reservationId: reservationId,
          reservationData: data,
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Text('Éxito', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
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
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmada': return Colors.green;
      case 'cancelada': return Colors.red;
      case 'completada': return Colors.blue;
      case 'activa': return Colors.teal;
      default: return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'confirmada': return Icons.check_circle;
      case 'cancelada': return Icons.cancel;
      case 'completada': return Icons.task_alt;
      case 'activa': return Icons.hotel;
      default: return Icons.pending;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.rol == 'operador' ? 'Mis Reservas' : 'Editar Reservas',
          style: TextStyle(
              fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 35, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nombre, email o teléfono',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : StreamBuilder<QuerySnapshot>(
                        stream: _reservationsStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final reservations =
                              snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return _searchQuery.isEmpty ||
                                (data['nombre']
                                        ?.toString()
                                        .toLowerCase()
                                        .contains(_searchQuery) ??
                                    false) ||
                                (data['email']
                                        ?.toString()
                                        .toLowerCase()
                                        .contains(_searchQuery) ??
                                    false) ||
                                (data['telefono']
                                        ?.toString()
                                        .toLowerCase()
                                        .contains(_searchQuery) ??
                                    false);
                          }).toList();

                          if (reservations.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    widget.rol == 'operador'
                                        ? 'No tienes reservas registradas'
                                        : 'No se encontraron reservas',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: reservations.length,
                            itemBuilder: (context, index) {
                              final reservation = reservations[index];
                              final data =
                                  reservation.data() as Map<String, dynamic>;
                              // Operador ve tarjeta simplificada
                              if (widget.rol == 'operador') {
                                return _buildOperadorCard(
                                    reservation.id, data);
                              }
                              return _buildAdminCard(reservation.id, data);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Tarjeta simplificada para operador: solo estado y datos de la reserva original
  Widget _buildOperadorCard(
      String reservationId, Map<String, dynamic> data) {
    final fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    final fechaSalida = (data['fechaSalida'] as Timestamp).toDate();
    final estado = data['estado']?.toString().toLowerCase() ?? 'pendiente';
    final noches = fechaSalida.difference(fechaEntrada).inDays;
    final total = (data['precioTotal'] ?? 0).toDouble();
    final abono = (data['abono'] ?? 0).toDouble();
    final saldo = total - abono;
    final puedeEditar =
        estado == 'pendiente' || estado == 'confirmada';
    final puedeCancelar =
        estado == 'pendiente' || estado == 'confirmada';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reserva #${reservationId.substring(0, 8)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700]),
                ),
                Chip(
                  avatar: Icon(_getStatusIcon(estado),
                      color: Colors.white, size: 14),
                  label: Text(estado.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                  backgroundColor: _getStatusColor(estado),
                ),
              ],
            ),
            const Divider(),

            // Datos del cliente
            _buildInfoRow('Cliente', data['nombre'] ?? 'N/A'),
            _buildInfoRow('Teléfono', data['telefono'] ?? 'N/A'),
            _buildInfoRow('Entrada', _formatDate(data['fechaEntrada'])),
            _buildInfoRow('Salida', _formatDate(data['fechaSalida'])),
            _buildInfoRow('Noches', '$noches'),

            const Divider(),

            // Resumen económico de la reserva original
            _buildInfoRow('Total reserva',
                '\$${total.toStringAsFixed(2)}'),
            _buildInfoRow('Abono pagado',
                '\$${abono.toStringAsFixed(2)}'),
            _buildInfoRow(
              'Saldo inicial',
              '\$${saldo.toStringAsFixed(2)}',
              style: TextStyle(
                color: saldo > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Método de pago
            if (data['metodoPago'] != null)
              _buildInfoRow('Método de pago', data['metodoPago']),

            // Notas si las hay
            if (data['notas'] != null &&
                data['notas'].toString().isNotEmpty) ...[
              const Divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data['notas'],
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],

            // Botones solo si puede editar o cancelar
            if (puedeEditar || puedeCancelar) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (puedeEditar)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('EDITAR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () =>
                            _editReservation(reservationId, data),
                      ),
                    ),
                  if (puedeEditar && puedeCancelar)
                    const SizedBox(width: 12),
                  if (puedeCancelar)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('CANCELAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () =>
                            _cancelReservation(reservationId),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tarjeta completa para admin
  Widget _buildAdminCard(
      String reservationId, Map<String, dynamic> data) {
    final fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    final fechaSalida = (data['fechaSalida'] as Timestamp).toDate();
    final estado = data['estado']?.toString().toLowerCase() ?? 'pendiente';
    final noches = fechaSalida.difference(fechaEntrada).inDays;
    final total = (data['precioTotal'] ?? 0).toDouble();
    final abono = (data['abono'] ?? 0).toDouble();
    final saldo = total - abono;
    final isCanceled = estado == 'cancelada';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reserva #${reservationId.substring(0, 8)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700]),
                ),
                Chip(
                  label: Text(estado.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                  backgroundColor: _getStatusColor(estado),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Cliente', data['nombre'] ?? 'N/A'),
            _buildInfoRow('Teléfono', data['telefono'] ?? 'N/A'),
            _buildInfoRow('Entrada', _formatDate(data['fechaEntrada'])),
            _buildInfoRow('Salida', _formatDate(data['fechaSalida'])),
            _buildInfoRow('Noches', '$noches'),
            _buildInfoRow('Total', '\$${total.toStringAsFixed(2)}'),
            _buildInfoRow('Abono', '\$${abono.toStringAsFixed(2)}'),
            _buildInfoRow(
              'Saldo',
              '\$${saldo.toStringAsFixed(2)}',
              style: TextStyle(
                color: saldo > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (data['notas'] != null &&
                data['notas'].toString().isNotEmpty) ...[
              const Divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data['notas'],
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 20),
                    label: const Text('EDITAR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isCanceled
                        ? null
                        : () => _editReservation(reservationId, data),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text('CANCELAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCanceled ? Colors.grey : Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isCanceled
                        ? null
                        : () => _cancelReservation(reservationId),
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value,
              style: style ??
                  const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}