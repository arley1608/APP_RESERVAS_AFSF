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
  late Stream<List<DocumentSnapshot>> _reservationsStream;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAllReservations();
  }

  Future<void> _loadAllReservations() async {
    try {
      // Solución: Cargar todos los documentos sin filtros iniciales
      // y procesar el filtrado localmente para evitar errores de índice
      _reservationsStream = _firestore
          .collection('reservas')
          .snapshots()
          .map((snapshot) => snapshot.docs);

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
    final confirmed = await _showConfirmationDialog(
      title: 'Cancelar Reserva',
      message: '¿Estás seguro de cancelar esta reserva?',
      confirmText: 'Sí, Cancelar',
      confirmColor: Colors.red,
    );

    if (confirmed) {
      try {
        await _firestore.collection('reservas').doc(reservationId).update({
          'estado': 'cancelada',
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
        _showSuccessDialog(
            'Reserva cancelada', 'La reserva ha sido cancelada exitosamente.');
      } catch (e) {
        _showErrorDialog(
            'Error al cancelar', 'No se pudo cancelar la reserva: $e');
      }
    }
  }

  Future<void> _activateReservation(String reservationId) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Activar Reserva',
      message: '¿Confirmas que deseas activar esta reserva?',
      confirmText: 'Sí, Activar',
      confirmColor: Colors.green,
    );

    if (confirmed) {
      try {
        await _firestore.collection('reservas').doc(reservationId).update({
          'estado': 'confirmada',
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
        _showSuccessDialog(
            'Reserva activada', 'La reserva ha sido activada exitosamente.');
      } catch (e) {
        _showErrorDialog(
            'Error al activar', 'No se pudo activar la reserva: $e');
      }
    }
  }

  Future<void> _navigateToManageScreen(String reservationId) async {
    // Implementa la navegación a la pantalla de gestión
  }

  Future<void> _navigateToCompleteScreen(String reservationId) async {
    // Implementa la navegación a la pantalla de finalización
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
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText, style: TextStyle(color: confirmColor)),
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

  Future<void> _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _currentDate) {
      setState(() {
        _currentDate = picked;
      });
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
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _showDatePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllReservations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : StreamBuilder<List<DocumentSnapshot>>(
                  stream: _reservationsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Solución: Filtrado local en lugar de consulta filtrada
                    final filteredReservations = snapshot.data!.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['fechaEntrada'] == null) return false;
                      final fechaEntrada =
                          (data['fechaEntrada'] as Timestamp).toDate();
                      return fechaEntrada.isAfter(
                          _currentDate.subtract(const Duration(days: 30)));
                    }).toList();

                    if (filteredReservations.isEmpty) {
                      return const Center(
                          child: Text(
                              'No hay reservas en el período seleccionado'));
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Mostrando reservas desde: ${DateFormat('dd/MM/yyyy').format(_currentDate.subtract(const Duration(days: 30)))}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredReservations.length,
                            itemBuilder: (context, index) {
                              final reservation = filteredReservations[index];
                              final data =
                                  reservation.data() as Map<String, dynamic>;
                              return _buildReservationCard(
                                  reservation.id, data);
                            },
                          ),
                        ),
                      ],
                    );
                  },
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
    final tipoAlojamiento = data['tipoAlojamiento']?.toString() ?? 'Estándar';

    bool checkServiceIncluded(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value > 0;
      if (value is String) {
        return value.toLowerCase() == 'si' ||
            value.toLowerCase() == 'sí' ||
            value.toLowerCase() == 'true' ||
            value.toLowerCase() == 'yes' ||
            value.toLowerCase() == 'incluido' ||
            value.toLowerCase() == 'con alimentos';
      }
      return false;
    }

    final alimentosField =
        _findFieldName(data, ['alimento', 'comida', 'food', 'alimentacion']);
    final actividadesField =
        _findFieldName(data, ['actividad', 'tour', 'activity', 'excursion']);

    final incluyeAlimentos = alimentosField != null
        ? checkServiceIncluded(data[alimentosField])
        : false;
    final incluyeActividades = actividadesField != null
        ? checkServiceIncluded(data[actividadesField])
        : false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
            _buildInfoRow('Tipo de alojamiento', tipoAlojamiento),
            _buildInfoRow(
              'Alimentación incluida',
              incluyeAlimentos ? 'Sí' : 'No',
              style: TextStyle(
                color: incluyeAlimentos ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildInfoRow(
              'Actividades incluidas',
              incluyeActividades ? 'Sí' : 'No',
              style: TextStyle(
                color: incluyeActividades ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildInfoRow('Total', '\$${total.toStringAsFixed(2)}'),
            if (abono > 0)
              _buildInfoRow('Abono', '\$${abono.toStringAsFixed(2)}'),
            _buildInfoRow(
              'Saldo',
              '\$${(total - abono).toStringAsFixed(2)}',
              style: TextStyle(
                color: (total - abono) > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (estado == 'pendiente')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () => _cancelReservation(reservationId),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                      ),
                      onPressed: () => _activateReservation(reservationId),
                      child: const Text('ACTIVAR'),
                    ),
                  ),
                ],
              ),
            if (estado == 'confirmada')
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                          ),
                          onPressed: () =>
                              _navigateToManageScreen(reservationId),
                          child: const Text('GESTIONAR'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[700],
                          ),
                          onPressed: () =>
                              _navigateToCompleteScreen(reservationId),
                          child: const Text('FINALIZAR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String? _findFieldName(
      Map<String, dynamic> data, List<String> possibleNames) {
    for (final field in data.keys) {
      for (final name in possibleNames) {
        if (field.toLowerCase().contains(name)) {
          return field;
        }
      }
    }
    return null;
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
