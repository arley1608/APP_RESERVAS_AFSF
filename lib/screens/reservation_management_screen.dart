import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReservationManagementScreen extends StatefulWidget {
  const ReservationManagementScreen({Key? key}) : super(key: key);

  @override
  _ReservationManagementScreenState createState() =>
      _ReservationManagementScreenState();
}

class _ReservationManagementScreenState
    extends State<ReservationManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _reservationsStream;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  String _filterStatus = 'todas';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Opciones de filtrado
  final List<String> _statusOptions = [
    'todas',
    'pendiente',
    'confirmada',
    'cancelada',
    'completada'
  ];

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
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadReservations() async {
    try {
      setState(() => _isLoading = true);

      _reservationsStream = _firestore
          .collection('reservas')
          .orderBy('fechaEntrada', descending: false)
          .snapshots();

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar reservas: ${e.toString()}';
      });
      _showErrorDialog('Error al cargar reservas', e.toString());
    }
  }

  Future<void> _updateReservationStatus(
      String reservationId, String newStatus) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Cambiar Estado',
      message: '¿Confirmas cambiar el estado a ${newStatus.toUpperCase()}?',
      confirmText: 'Confirmar',
      confirmColor: _getStatusColor(newStatus),
    );

    if (confirmed) {
      try {
        await _firestore.collection('reservas').doc(reservationId).update({
          'estado': newStatus,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
        _showSuccessDialog('Estado actualizado',
            'La reserva ha sido actualizada exitosamente.');
      } catch (e) {
        _showErrorDialog(
            'Error al actualizar', 'No se pudo actualizar la reserva: $e');
      }
    }
  }

  Future<void> _showReservationDetails(
      String reservationId, Map<String, dynamic> data) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de Reserva #${reservationId.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Estado:', data['estado']?.toString() ?? 'N/A',
                  _getStatusColor(data['estado']?.toString() ?? 'pendiente')),
              _buildDetailItem('Cliente:', data['nombre'] ?? 'N/A'),
              _buildDetailItem('Email:', data['email'] ?? 'N/A'),
              _buildDetailItem('Teléfono:', data['telefono'] ?? 'N/A'),
              _buildDetailItem('Entrada:', _formatDate(data['fechaEntrada'])),
              _buildDetailItem('Salida:', _formatDate(data['fechaSalida'])),
              _buildDetailItem(
                  'Huéspedes:', data['huespedesTotales']?.toString() ?? 'N/A'),
              _buildDetailItem('Total:',
                  '\$${data['precioTotal']?.toStringAsFixed(2) ?? '0.00'}'),
              _buildDetailItem(
                  'Abono:', '\$${data['abono']?.toStringAsFixed(2) ?? '0.00'}'),
              _buildDetailItem('Saldo Pendiente:',
                  '\$${(data['precioTotal'] - (data['abono'] ?? 0)).toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              if (data['alojamientos'] != null)
                ..._buildAccommodationDetails(data['alojamientos']),
              if (data['actividades'] != null)
                ..._buildActivityDetails(data['actividades']),
              if (data['alimentos'] != null)
                ..._buildFoodDetails(data['alimentos']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
    }
    return 'N/A';
  }

  List<Widget> _buildAccommodationDetails(List<dynamic> accommodations) {
    return [
      const Divider(),
      const Text('Alojamientos:',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ...accommodations.map((acc) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '- ${acc['alojamientoNombre']} (${acc['tipoAlojamiento']})'),
                Text('  Huéspedes: ${acc['huespedes']}'),
                Text(
                    '  Precio: \$${acc['precioPorAlojamiento']?.toStringAsFixed(2) ?? '0.00'}'),
              ],
            ),
          )),
    ];
  }

  List<Widget> _buildActivityDetails(List<dynamic> activities) {
    return [
      const Divider(),
      const Text('Actividades:', style: TextStyle(fontWeight: FontWeight.bold)),
      ...activities.map((act) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- ${act['nombre']} (x${act['cantidad']})'),
                Text(
                    '  Precio: \$${act['precio']?.toStringAsFixed(2) ?? '0.00'}'),
                Text(
                    '  Subtotal: \$${act['subtotal']?.toStringAsFixed(2) ?? '0.00'}'),
              ],
            ),
          )),
    ];
  }

  List<Widget> _buildFoodDetails(List<dynamic> foods) {
    return [
      const Divider(),
      const Text('Alimentos:', style: TextStyle(fontWeight: FontWeight.bold)),
      ...foods.map((food) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- ${food['nombre']} (x${food['cantidad']})'),
                Text(
                    '  Precio: \$${food['precio']?.toStringAsFixed(2) ?? '0.00'}'),
                Text(
                    '  Subtotal: \$${food['subtotal']?.toStringAsFixed(2) ?? '0.00'}'),
              ],
            ),
          )),
    ];
  }

  Widget _buildDetailItem(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: color != null ? TextStyle(color: color) : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(color: confirmColor),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSuccessDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
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

  Future<void> _showErrorDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
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

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Reservas'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReservations,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Barra de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar reservas',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStatus,
                        items: _statusOptions.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status == 'todas'
                                  ? 'Todas las reservas'
                                  : 'Reservas ${status.toLowerCase()}',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _filterStatus = value ?? 'todas');
                        },
                        decoration: InputDecoration(
                          labelText: 'Filtrar por estado',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _showDatePicker,
                      tooltip: 'Seleccionar fecha',
                    ),
                  ],
                ),
              ],
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

                          final reservations = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final matchesStatus = _filterStatus == 'todas' ||
                                (data['estado']?.toString().toLowerCase() ==
                                    _filterStatus);
                            final matchesSearch = _searchQuery.isEmpty ||
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
                                    false) ||
                                doc.id.toLowerCase().contains(_searchQuery);
                            return matchesStatus && matchesSearch;
                          }).toList();

                          if (reservations.isEmpty) {
                            return const Center(
                                child: Text('No se encontraron reservas'));
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: reservations.length,
                            itemBuilder: (context, index) {
                              final reservation = reservations[index];
                              final data =
                                  reservation.data() as Map<String, dynamic>;
                              return _buildReservationCard(
                                  reservation.id, data);
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
    final total = data['precioTotal'] ?? 0;
    final abono = data['abono'] ?? 0;
    final saldo = total - abono;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReservationDetails(reservationId, data),
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
                      color: Colors.green[700],
                    ),
                  ),
                  Chip(
                    label: Text(
                      estado.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(estado),
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow('Cliente', data['nombre'] ?? 'No especificado'),
              _buildInfoRow('Contacto',
                  data['email'] ?? data['telefono'] ?? 'Sin contacto'),
              _buildInfoRow(
                  'Entrada', DateFormat('dd/MM/yyyy').format(fechaEntrada)),
              _buildInfoRow(
                  'Salida', DateFormat('dd/MM/yyyy').format(fechaSalida)),
              _buildInfoRow('Noches', noches.toString()),
              _buildInfoRow('Total', '\$${total.toStringAsFixed(2)}'),
              if (abono > 0)
                _buildInfoRow('Abono', '\$${abono.toStringAsFixed(2)}'),
              _buildInfoRow(
                'Saldo',
                '\$${saldo.toStringAsFixed(2)}',
                style: TextStyle(
                  color: saldo > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (estado == 'pendiente')
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _updateReservationStatus(
                            reservationId, 'cancelada'),
                        child: const Text('CANCELAR'),
                      ),
                    ),
                  if (estado == 'pendiente') const SizedBox(width: 16),
                  if (estado == 'pendiente')
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                        ),
                        onPressed: () => _updateReservationStatus(
                            reservationId, 'confirmada'),
                        child: const Text('CONFIRMAR'),
                      ),
                    ),
                  if (estado == 'confirmada')
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                        ),
                        onPressed: () => _updateReservationStatus(
                            reservationId, 'completada'),
                        child: const Text('COMPLETAR'),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      case 'completada':
        return Colors.blue;
      case 'pendiente':
      default:
        return Colors.orange;
    }
  }

  Widget _buildInfoRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: style ??
                const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}
