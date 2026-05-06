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
  final esCheckoutAnticipado =
      hoySinHora.isBefore(salidaSinHora) && nochesReales > 0;

  // Calcular nuevo precio base si es checkout anticipado
  double precioBaseRecalculado = 0;
  double precioBaseOriginal = 0;

  final alojamientos = (data['alojamientos'] as List?) ?? [];
  for (final aloj in alojamientos) {
    final totalAloj = (aloj['precioPorAlojamiento'] as num).toDouble();
    precioBaseOriginal += totalAloj;
    if (esCheckoutAnticipado && nochesOriginales > 0) {
      // Extraer precio por noche y recalcular con noches reales
      final precioPorNoche = totalAloj / nochesOriginales;
      precioBaseRecalculado += precioPorNoche * nochesReales;
    } else {
      precioBaseRecalculado += totalAloj;
    }
  }

  // Agregar actividades y alimentos de la reserva original
  double extrasOriginales = 0;
  final actividades = (data['actividades'] as List?) ?? [];
  final alimentos = (data['alimentos'] as List?) ?? [];
  for (final a in actividades) {
    extrasOriginales += (a['subtotal'] as num).toDouble();
  }
  for (final a in alimentos) {
    extrasOriginales += (a['subtotal'] as num).toDouble();
  }

  // Consumos durante la estadía
  final consumos = (data['consumos'] as List?) ?? [];
  final consumosTotal = consumos.fold<double>(
      0, (sum, c) => sum + ((c['subtotal'] ?? 0) as num).toDouble());

  final abono = (data['abono'] ?? 0).toDouble();
  final totalFinal =
      precioBaseRecalculado + extrasOriginales + consumosTotal;
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
              // Aviso de checkout anticipado
              if (esCheckoutAnticipado) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Check-out anticipado',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700])),
                            SizedBox(height: 4),
                            Text(
                              'Salida programada: ${DateFormat('dd/MM/yyyy').format(fechaSalida)}\n'
                              'Salida real: ${DateFormat('dd/MM/yyyy').format(hoy)}\n'
                              'Noches originales: $nochesOriginales\n'
                              'Noches reales: $nochesReales',
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),

              _buildResumenFila('Cliente', data['nombre'] ?? 'N/A'),
              SizedBox(height: 8),

              // Precio base
              if (esCheckoutAnticipado) ...[
                _buildResumenFila(
                  'Alojamiento original',
                  '\$${precioBaseOriginal.toStringAsFixed(2)}',
                  color: Colors.grey,
                ),
                _buildResumenFila(
                  'Alojamiento recalculado ($nochesReales noches)',
                  '\$${precioBaseRecalculado.toStringAsFixed(2)}',
                  color: Colors.green[700],
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

              // Método de pago
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
                            color: Colors.green,
                            fontWeight: FontWeight.bold),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700]),
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
                if (esCheckoutAnticipado)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Estadía recalculada: $nochesReales noches',
                      style: TextStyle(color: Colors.orange[700]),
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
                              backgroundColor: estado == 'activa'
                                  ? Colors.teal
                                  : Colors.blue,
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
                        _buildFila(
                            'Huéspedes',
                            '${data['huespedesTotales'] ?? 1}'),
                        if (data['alojamientos'] != null) ...[
                          Divider(),
                          Text('Alojamientos:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700])),
                          ...((data['alojamientos'] as List)
                              .map((a) => Padding(
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

                        // Reserva base
                        _buildFilaCuenta(
                            'Reserva base', total, Icons.hotel),

                        // Actividades de la reserva original
                        if (data['actividades'] != null)
                          ...((data['actividades'] as List).map((a) =>
                              _buildFilaCuenta(
                                  '${a['nombre']} (x${a['cantidad']})',
                                  (a['subtotal'] as num).toDouble(),
                                  Icons.sports))),

                        // Alimentos de la reserva original
                        if (data['alimentos'] != null)
                          ...((data['alimentos'] as List).map((a) =>
                              _buildFilaCuenta(
                                  '${a['nombre']} (x${a['cantidad']})',
                                  (a['subtotal'] as num).toDouble(),
                                  Icons.restaurant))),

                        // Consumos durante la estadía
                        if (consumos.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text('Consumos durante estadía:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700])),
                          SizedBox(height: 4),
                          ...consumos.map((c) => _buildFilaCuenta(
                                '${c['nombre']} (x${c['cantidad']})',
                                (c['subtotal'] as num).toDouble(),
                                c['tipo'] == 'actividad'
                                    ? Icons.sports
                                    : Icons.restaurant,
                                color: Colors.orange,
                              )),
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
                                  color:
                                      saldo > 0 ? Colors.red : Colors.green,
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
                    // Actividades
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
                            subtitle:
                                Text('\$${(d['precio'] as num).toStringAsFixed(2)} por persona'),
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

                    // Alimentos
                    if (_alimentosDisponibles.isNotEmpty) ...[
                      Text('Alimentos',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700])),
                      SizedBox(height: 8),
                      ..._alimentosDisponibles.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[50],
                              child: Icon(Icons.restaurant,
                                  color: Colors.orange[700]),
                            ),
                            title: Text(d['nombre'],
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '\$${(d['precio'] as num).toStringAsFixed(2)} por servicio'),
                            trailing: IconButton(
                              icon: Icon(Icons.add_circle,
                                  color: Colors.orange[700], size: 32),
                              onPressed: () => _agregarConsumo(
                                  'alimento',
                                  doc.id,
                                  d['nombre'],
                                  (d['precio'] as num).toDouble()),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],

                  SizedBox(height: 20),

                  // Botón checkout
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
                      onPressed: _isLoading ? null : () => _hacerCheckout(data),
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
          Text('$label:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.normal, fontSize: 14)),
        ],
      ),
    );
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