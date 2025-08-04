import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditReservationScreen extends StatefulWidget {
  const EditReservationScreen({Key? key}) : super(key: key);

  @override
  _EditReservationScreen createState() => _EditReservationScreen();
}

class _EditReservationScreen extends State<EditReservationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  Future<void> _cancelReservation(String reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Reserva'),
        content: const Text('¿Estás seguro que deseas cancelar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Sí, cancelar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('reservas').doc(reservationId).update({
          'estado': 'cancelada',
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
        _showSuccessDialog(
            'Reserva cancelada', 'La reserva ha sido cancelada exitosamente.');
      } catch (e) {
        _showErrorDialog(
            'Error al cancelar', 'No se pudo cancelar la reserva: $e');
      }
    }
  }

  Future<void> _editReservation(
      String reservationId, Map<String, dynamic> data) async {
    // Aquí puedes implementar la lógica para editar la reserva
    // Por ejemplo, navegar a una pantalla de edición con los datos de la reserva
    _showSuccessDialog('Editar Reserva',
        'Función de edición para reserva #${reservationId.substring(0, 8)}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Reservas',
            style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
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
                labelText: 'Buscar reservas',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

                          final reservations = snapshot.data!.docs.where((doc) {
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
                                    false) ||
                                doc.id.toLowerCase().contains(_searchQuery);
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
    final isCanceled = estado == 'cancelada';

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
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text('EDITAR RESERVA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _editReservation(reservationId, data),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, size: 20),
                      label: const Text('CANCELAR RESERVA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCanceled ? Colors.grey : Colors.red,
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
