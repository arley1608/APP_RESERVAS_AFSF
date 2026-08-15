import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class GuestAccountScreen extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> reservationData;

  const GuestAccountScreen({
    Key? key,
    required this.reservationId,
    required this.reservationData,
  }) : super(key: key);

  @override
  _GuestAccountScreenState createState() => _GuestAccountScreenState();
}

class _GuestAccountScreenState extends State<GuestAccountScreen> {
  final FirestoreService _service = FirestoreService();
  List<QueryDocumentSnapshot> _actividadesDisponibles = [];
  List<QueryDocumentSnapshot> _alimentosDisponibles = [];
  bool _isLoading = false;
  bool _isLoadingExtras = true;

  @override
  void initState() {
    super.initState();
    _cargarExtras();
  }

  Future<void> _cargarExtras() async {
    try {
      final acts = await FirebaseFirestore.instance
          .collection('actividades')
          .get();
      final alis = await FirebaseFirestore.instance
          .collection('alimentos')
          .get();
      setState(() {
        _actividadesDisponibles = acts.docs;
        _alimentosDisponibles = alis.docs;
        _isLoadingExtras = false;
      });
    } catch (e) {
      setState(() => _isLoadingExtras = false);
    }
  }

  Future<void> _agregarConsumo(
      String tipo, String id, String nombre, double precio) async {
    int cantidad = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(
                tipo == 'actividad' ? Icons.sports : Icons.restaurant,
                color: Colors.green[700]),
            SizedBox(width: 10),
            Expanded(
                child: Text('Agregar consumo',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('\$${precio.toStringAsFixed(2)} por unidad',
                  style: TextStyle(color: Colors.grey[600])),
              SizedBox(height: 20),
              Text('Cantidad:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    iconSize: 36,
                    onPressed: cantidad > 1
                        ? () => setDialogState(() => cantidad--)
                        : null,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$cantidad',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.green),
                    iconSize: 36,
                    onPressed: () => setDialogState(() => cantidad++),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Center(
                child: Text(
                  'Subtotal: \$${(precio * cantidad).toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700]),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700]),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Agregar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final nuevoConsumo = {
          'tipo': tipo,
          'itemId': id,
          'nombre': nombre,
          'precio': precio,
          'cantidad': cantidad,
          'subtotal': precio * cantidad,
          'fecha': Timestamp.now(),
        };

        await FirebaseFirestore.instance
            .collection('reservas')
            .doc(widget.reservationId)
            .update({
          'consumos': FieldValue.arrayUnion([nuevoConsumo]),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$nombre agregado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _showErrorDialog('Error al agregar consumo: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _eliminarConsumo(
      int index, Map<String, dynamic> consumo, List consumos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text('Eliminar consumo',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text('¿Eliminar "${consumo['nombre']}" de la cuenta?'),
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
        final nuevosConsumos = List.from(consumos)..removeAt(index);
        await FirebaseFirestore.instance
            .collection('reservas')
            .doc(widget.reservationId)
            .update({
          'consumos': nuevosConsumos,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Consumo eliminado'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        _showErrorDialog('Error al eliminar consumo: ${e.toString()}');
      }
    }
  }

  Future<void> _hacerCheckout(Map<String, dynamic> data) async {
    final fechaEntrada = (data['fechaEntrada'] as Timestamp).toDate();
    final fechaSalida = (data['fechaSalida'] as Timestamp).toDate();
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final entradaSinHora =
        DateTime(fechaEntrada.year, fechaEntrada.month, fechaEntrada.day);
    final salidaSinHora =
        DateTime(fechaSalida.year, fechaSalida.month, fechaSalida.day);

    final nochesOriginales = salidaSinHora.difference(entradaSinHora).inDays;
    final nochesReales = hoySinHora.difference(entradaSinHora).inDays;

    // Se cobra únicamente por las noches efectivamente usadas, sea
    // menos (checkout anticipado, incluyendo mismo día = 0 noches) o
    // más (checkout tardío = noches extra al mismo precio por noche).
    final nochesCobradas = nochesReales;
    final esCheckoutAnticipado = hoySinHora.isBefore(salidaSinHora);
    final esCheckoutTardio = hoySinHora.isAfter(salidaSinHora);
    final nochesExtra = esCheckoutTardio ? nochesReales - nochesOriginales : 0;
    final huboCambioDeFechas = esCheckoutAnticipado || esCheckoutTardio;

    double precioBaseRecalculado = 0;
    double precioBaseOriginal = 0;

    final alojamientos = (data['alojamientos'] as List?) ?? [];
    for (final aloj in alojamientos) {
      final totalAloj = (aloj['precioPorAlojamiento'] as num).toDouble();
      precioBaseOriginal += totalAloj;
      if (huboCambioDeFechas && nochesOriginales > 0) {
        final precioPorNoche = totalAloj / nochesOriginales;
        precioBaseRecalculado += precioPorNoche * nochesCobradas;
      } else {
        precioBaseRecalculado += totalAloj;
      }
    }

    double extrasOriginales = 0;
    final actividades = (data['actividades'] as List?) ?? [];
    final alimentos = (data['alimentos'] as List?) ?? [];
    for (final a in actividades) {
      extrasOriginales += (a['subtotal'] as num).toDouble();
    }
    for (final a in alimentos) {
      extrasOriginales += (a['subtotal'] as num).toDouble();
    }

    final consumos = (data['consumos'] as List?) ?? [];
    final consumosTotal = consumos.fold<double>(
        0, (sum, c) => sum + ((c['subtotal'] ?? 0) as num).toDouble());

    final abono = (data['abono'] ?? 0).toDouble();
    final totalFinal = precioBaseRecalculado + extrasOriginales + consumosTotal;
    final saldo = totalFinal - abono;

    String? metodoPagoSaldo;
    final List<String> metodosPago = [
      'Efectivo',
      'Tarjeta de Crédito',
      'Tarjeta de Débito',
      'Transferencia Bancaria',
      'Depósito',
      'Otro',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.logout, color: Colors.blue[700], size: 28),
            SizedBox(width: 10),
            Text('Confirmar Check-out',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (huboCambioDeFechas) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esCheckoutTardio
                          ? Colors.red[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: esCheckoutTardio
                              ? Colors.red
                              : Colors.orange),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: esCheckoutTardio
                                ? Colors.red
                                : Colors.orange,
                            size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  esCheckoutTardio
                                      ? 'Check-out tardío'
                                      : 'Check-out anticipado',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: esCheckoutTardio
                                          ? Colors.red[700]
                                          : Colors.orange[700])),
                              SizedBox(height: 4),
                              Text(
                                'Salida programada: ${DateFormat('dd/MM/yyyy').format(fechaSalida)}\n'
                                'Salida real: ${DateFormat('dd/MM/yyyy').format(hoy)}\n'
                                'Noches originales: $nochesOriginales\n'
                                'Noches cobradas: $nochesCobradas'
                                '${esCheckoutTardio ? ' ($nochesExtra noche${nochesExtra == 1 ? '' : 's'} extra)' : ''}',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                Text('Resumen final:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 12),
                _buildResumenFila('Cliente', data['nombre'] ?? 'N/A'),
                SizedBox(height: 8),
                if (huboCambioDeFechas) ...[
                  _buildResumenFila(
                    'Alojamiento original',
                    '\$${precioBaseOriginal.toStringAsFixed(2)}',
                    color: Colors.grey,
                  ),
                  _buildResumenFila(
                    'Alojamiento recalculado ($nochesCobradas noche${nochesCobradas == 1 ? '' : 's'})',
                    '\$${precioBaseRecalculado.toStringAsFixed(2)}',
                    color:
                        esCheckoutTardio ? Colors.red[700] : Colors.green[700],
                  ),
                ] else
                  _buildResumenFila(
                    'Alojamiento',
                    '\$${precioBaseOriginal.toStringAsFixed(2)}',
                  ),
                if (extrasOriginales > 0)
                  _buildResumenFila('Actividades/Alimentos reserva',
                      '\$${extrasOriginales.toStringAsFixed(2)}'),
                if (consumosTotal > 0)
                  _buildResumenFila(
                      'Consumos durante estadía',
                      '\$${consumosTotal.toStringAsFixed(2)}',
                      color: Colors.orange),
                Divider(),
                _buildResumenFila(
                    'Total final', '\$${totalFinal.toStringAsFixed(2)}',
                    bold: true),
                _buildResumenFila(
                    'Abono pagado', '\$${abono.toStringAsFixed(2)}'),
                Divider(),
                _buildResumenFila(
                  saldo > 0 ? 'Saldo a cobrar' : 'Devolución al huésped',
                  '\$${saldo.abs().toStringAsFixed(2)}',
                  color: saldo > 0 ? Colors.red : Colors.green,
                  bold: true,
                ),
                SizedBox(height: 20),
                if (saldo > 0) ...[
                  Text('Método de pago del saldo:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: metodoPagoSaldo,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      labelText: 'Seleccione método de pago',
                      prefixIcon: Icon(Icons.payment),
                    ),
                    items: metodosPago
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => metodoPagoSaldo = v),
                  ),
                ] else if (saldo < 0) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(children: [
                      Icon(Icons.savings, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Devolver \$${saldo.abs().toStringAsFixed(2)} al huésped',
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                  ),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Sin saldo pendiente',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
              onPressed: saldo > 0 && metodoPagoSaldo == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text('Confirmar Check-out',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _service.updateReserva(widget.reservationId, {
          'estado': 'completada',
          'checkOutEn': FieldValue.serverTimestamp(),
          'fechaSalidaReal': Timestamp.fromDate(hoy),
          'nochesReales': nochesReales,
          'nochesCobradas': nochesCobradas,
          'nochesExtra': nochesExtra,
          'precioBaseRecalculado': precioBaseRecalculado,
          'totalFinal': totalFinal,
          'saldoFinal': saldo,
          if (metodoPagoSaldo != null) 'metodoPagoSaldo': metodoPagoSaldo,
        });

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Icon(Icons.task_alt, color: Colors.blue, size: 28),
                SizedBox(width: 10),
                Text('Check-out completado',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('La reserva ha sido completada exitosamente.'),
                  SizedBox(height: 12),
                  if (huboCambioDeFechas)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Estadía recalculada: $nochesCobradas noche${nochesCobradas == 1 ? '' : 's'} cobrada${nochesCobradas == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: esCheckoutTardio
                                ? Colors.red[700]
                                : Colors.orange[700]),
                      ),
                    ),
                  if (saldo > 0)
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
                          Row(children: [
                            Icon(Icons.attach_money, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Cobrado: \$${saldo.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                          ]),
                          SizedBox(height: 4),
                          Text('Método: $metodoPagoSaldo',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 14)),
                        ],
                      ),
                    )
                  else if (saldo < 0)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(children: [
                        Icon(Icons.savings, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Devolver \$${saldo.abs().toStringAsFixed(2)} al huésped',
                            style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                      ]),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Pago completo',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ]),
                    ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700]),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('Finalizar',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        _showErrorDialog('Error al hacer check-out: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildResumenFila(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: TextStyle(color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cuenta del Huésped',
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservas')
            .doc(widget.reservationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final estado = data['estado'] ?? 'activa';
          final total = (data['precioTotal'] ?? 0).toDouble();
          final abono = (data['abono'] ?? 0).toDouble();
          final consumos = (data['consumos'] as List?) ?? [];
          final consumosTotal = consumos.fold<double>(
              0, (sum, c) => sum + ((c['subtotal'] ?? 0) as num).toDouble());
          final totalFinal = total + consumosTotal;
          final saldo = totalFinal - abono;
          final esActiva = estado == 'activa';

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info del huésped ──
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Información del Huésped',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700])),
                            Chip(
                              label: Text(estado.toUpperCase(),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                              backgroundColor:
                                  estado == 'activa' ? Colors.teal : Colors.blue,
                            ),
                          ],
                        ),
                        Divider(),
                        _buildFila('Cliente', data['nombre'] ?? 'N/A'),
                        _buildFila('Teléfono', data['telefono'] ?? 'N/A'),
                        _buildFila('Email', data['email'] ?? 'N/A'),
                        _buildFila(
                            'Entrada',
                            DateFormat('dd/MM/yyyy').format(
                                (data['fechaEntrada'] as Timestamp).toDate())),
                        _buildFila(
                            'Salida',
                            DateFormat('dd/MM/yyyy').format(
                                (data['fechaSalida'] as Timestamp).toDate())),
                        _buildFila('Huéspedes',
                            '${data['huespedesTotales'] ?? 1}'),
                        if (data['notas'] != null &&
                            data['notas'].toString().isNotEmpty) ...[
                          Divider(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes,
                                  size: 16, color: Colors.grey[600]),
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
                        if (data['alojamientos'] != null) ...[
                          Divider(),
                          Text('Alojamientos:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700])),
                          ...((data['alojamientos'] as List).map((a) => Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                    '• ${a['alojamientoNombre']} (${a['huespedes']} huéspedes)',
                                    style: TextStyle(fontSize: 14)),
                              ))),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // ── Cuenta corriente ──
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cuenta Corriente',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700])),
                        Divider(),
                        _buildFilaCuenta('Reserva base', total, Icons.hotel),
                        if (data['actividades'] != null)
                          ...((data['actividades'] as List).map((a) =>
                              _buildFilaCuenta(
                                  '${a['nombre']} (x${a['cantidad']})',
                                  (a['subtotal'] as num).toDouble(),
                                  Icons.sports))),
                        if (data['alimentos'] != null)
                          ...((data['alimentos'] as List).map((a) =>
                              _buildFilaCuenta(
                                  '${a['nombre']} (x${a['cantidad']})',
                                  (a['subtotal'] as num).toDouble(),
                                  Icons.restaurant))),

                        // ── Consumos durante la estadía CON botón eliminar ──
                        if (consumos.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text('Consumos durante estadía:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700])),
                          SizedBox(height: 4),
                          ...consumos.asMap().entries.map((entry) {
                            final index = entry.key;
                            final c = entry.value;
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    c['tipo'] == 'actividad'
                                        ? Icons.sports
                                        : Icons.restaurant,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${c['nombre']} (x${c['cantidad']})',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '\$${(c['subtotal'] as num).toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.orange),
                                  ),
                                  if (esActiva)
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                      onPressed: () => _eliminarConsumo(
                                          index, c, consumos),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],

                        Divider(thickness: 2),
                        _buildFilaCuenta(
                            'Total final', totalFinal, Icons.calculate,
                            bold: true),
                        _buildFilaCuenta(
                            'Abono pagado', -abono, Icons.payments,
                            color: Colors.green),
                        Divider(thickness: 2),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('SALDO A COBRAR:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                '\$${saldo.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: saldo > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // ── Agregar consumos (solo si está activa) ──
                if (esActiva) ...[
                  Text('Agregar Consumos',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700])),
                  SizedBox(height: 12),
                  if (_isLoadingExtras)
                    Center(child: CircularProgressIndicator())
                  else ...[
                    if (_actividadesDisponibles.isNotEmpty) ...[
                      Text('Actividades',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700])),
                      SizedBox(height: 8),
                      ..._actividadesDisponibles.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[50],
                              child:
                                  Icon(Icons.sports, color: Colors.green[700]),
                            ),
                            title: Text(d['nombre'],
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '\$${(d['precio'] as num).toStringAsFixed(2)} por persona'),
                            trailing: IconButton(
                              icon: Icon(Icons.add_circle,
                                  color: Colors.green[700], size: 32),
                              onPressed: () => _agregarConsumo(
                                  'actividad',
                                  doc.id,
                                  d['nombre'],
                                  (d['precio'] as num).toDouble()),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 12),
                    ],
                    if (_alimentosDisponibles.isNotEmpty) ...[
                      Text('Alimentos',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700])),
                      SizedBox(height: 8),
                      ..._buildAlimentosAgrupadosConsumo(),
                    ],
                  ],
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.logout, color: Colors.white),
                      label: Text('HACER CHECK-OUT',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed:
                          _isLoading ? null : () => _hacerCheckout(data),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFila(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.normal, fontSize: 14)),
        ],
      ),
    );
  }

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

  static const List<String> _ordenTiposAlimento = [
    "Desayuno", "Almuerzo", "Cena", "Bebida", "Snack", "Postre", "Especial",
  ];

  // Agrupa los alimentos disponibles por tipo (mismo orden del
  // catálogo), con un encabezado por grupo, para que el recepcionista
  // encuentre rápido lo que busca al agregar un consumo.
  List<Widget> _buildAlimentosAgrupadosConsumo() {
    final Map<String, List<QueryDocumentSnapshot>> grupos = {};
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
        padding: EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Icon(_iconoTipoAlimento(tipo), size: 16, color: Colors.orange[700]),
            SizedBox(width: 6),
            Text(tipo,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange[700])),
          ],
        ),
      ));
      for (final doc in grupos[tipo]!) {
        final d = doc.data() as Map<String, dynamic>;
        widgets.add(Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[50],
              child: Icon(_iconoTipoAlimento(d['tipo']),
                  color: Colors.orange[700]),
            ),
            title: Text(d['nombre'],
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '\$${(d['precio'] as num).toStringAsFixed(2)} por servicio'),
            trailing: IconButton(
              icon: Icon(Icons.add_circle,
                  color: Colors.orange[700], size: 32),
              onPressed: () => _agregarConsumo('alimento', doc.id,
                  d['nombre'], (d['precio'] as num).toDouble()),
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _buildFilaCuenta(String label, double valor, IconData icon,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(
            '\$${valor.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                color: color),
          ),
        ],
      ),
    );
  }
}