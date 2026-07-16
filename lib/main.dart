import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  runApp(const AdminHuevosApp()); 
}

class AdminData {
  static bool granjaAbierta = true;
  static bool tarjetaHabilitada = true;
  static double precioPorCarton = 320.0;
  static List<Map<String, dynamic>> cuentasBancarias = [];
}

class AdminHuevosApp extends StatefulWidget {
  const AdminHuevosApp({Key? key}) : super(key: key);

  @override
  State<AdminHuevosApp> createState() => _AdminHuevosAppAppState();
}

class _AdminHuevosAppAppState extends State<AdminHuevosApp> {
  ThemeMode _themeMode = ThemeMode.dark; 

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panel de Control - Huevos Pio Pio',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFFFFB300),
        colorScheme: const ColorScheme.light(primary: Color(0xFFFFB300), secondary: Color(0xFFFF6D00)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F11),
        primaryColor: const Color(0xFFFFB300),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFFB300), secondary: Color(0xFFE65100)),
      ),
      home: AdminDashboardScreen(onThemeToggle: toggleTheme, currentTheme: _themeMode),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final ThemeMode currentTheme;
  const AdminDashboardScreen({Key? key, required this.onThemeToggle, required this.currentTheme}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0; 
  String? _pedidoSeleccionadoId; 

  final TextEditingController _precioCtrl = TextEditingController();
  final TextEditingController _bancoCtrl = TextEditingController();
  final TextEditingController _cuentaCtrl = TextEditingController();
  final TextEditingController _titularCtrl = TextEditingController();
  String _tipoCuentaSeleccionada = "Ahorros";

  @override
  void initState() {
    super.initState();
    _configurarNotificacionesPush();
  }

  Future<void> _configurarNotificacionesPush() async {
    final fcm = FirebaseMessaging.instance;
    
    // 1. Pedir permisos al usuario (Obligatorio en Android 13+ y iOS)
    await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Suscribir este teléfono al canal de "admin"
    await fcm.subscribeToTopic('admin');
    print("Suscrito exitosamente al canal de alertas del Admin");

    // 3. Escuchar notificaciones mientras tenemos la app abierta en la pantalla
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.notification!.title ?? 'Notificación', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(message.notification!.body ?? '', style: const TextStyle(fontSize: 14)),
              ],
            ),
            backgroundColor: const Color(0xFFFF6D00),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  void _notificarAccion(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _guardarConfiguracion() async {
    await FirebaseFirestore.instance.collection('configuracion').doc('global').set({
      'granjaAbierta': AdminData.granjaAbierta,
      'tarjetaHabilitada': AdminData.tarjetaHabilitada,
      'precioPorCarton': AdminData.precioPorCarton,
      'cuentasBancarias': AdminData.cuentasBancarias,
    });
  }

  Future<void> _actualizarEstadoPedido(String id, String nuevoEstado) async {
    final Map<String, dynamic> actualizacion = {'estado': nuevoEstado};
    
    if (nuevoEstado == "Despacho") {actualizacion['fechaDespacho'] = FieldValue.serverTimestamp();}
    if (nuevoEstado == "Historial") {actualizacion['fechaEntrega'] = FieldValue.serverTimestamp();}

    await FirebaseFirestore.instance.collection('pedidos').doc(id).update(actualizacion);
  }

  Future<void> _abrirWhatsApp(String telefono) async {
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("https://wa.me/1$numeroLimpio");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _notificarAccion("No se pudo abrir WhatsApp.");
    }
  }

  Future<void> _abrirMapa(String direccion) async {
    final query = Uri.encodeComponent(direccion);
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _notificarAccion("No se pudo abrir el mapa.");
    }
  }

  Future<void> _llamarTelefono(String telefono) async {
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("tel:$numeroLimpio");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _notificarAccion("No se pudo abrir la app de llamadas.");
    }
  }

  Future<void> _abrirRecibo(String urlComprobante) async {
    final url = Uri.parse(urlComprobante);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _notificarAccion("No se pudo abrir la imagen del recibo.");
    }
  }

  void _mostrarAjustes(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlassCard(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ajustes del Sistema', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: const Color(0xFFFFB300)),
                title: Text(isDark ? 'Modo Oscuro (Activado)' : 'Modo Claro (Activado)', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                trailing: Switch(value: isDark, activeColor: const Color(0xFFFFB300), onChanged: (val) { widget.onThemeToggle(); Navigator.pop(context); }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.currentTheme == ThemeMode.dark;
    final titles = ['Buzón de Pedidos', 'Panel de Control', 'Monitor de Despacho', 'Historial de Entregas'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        backgroundColor: isDark ? const Color(0xFF131316) : Colors.white,
        elevation: isDark ? 0 : 1,
        actions: [
          IconButton(icon: const Icon(Icons.settings_rounded), onPressed: () => _mostrarAjustes(context, isDark)),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshotPedidos) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('configuracion').doc('global').snapshots(),
            builder: (context, snapshotConfig) {
              if (snapshotConfig.hasData && snapshotConfig.data!.exists) {
                final data = snapshotConfig.data!.data() as Map<String, dynamic>;
                AdminData.granjaAbierta = data['granjaAbierta'] ?? true;
                AdminData.tarjetaHabilitada = data['tarjetaHabilitada'] ?? true;
                AdminData.precioPorCarton = (data['precioPorCarton'] ?? 320.0).toDouble();
                if (data['cuentasBancarias'] != null) {
                  AdminData.cuentasBancarias = List<Map<String, dynamic>>.from(data['cuentasBancarias']);
                }
              }

              final List<QueryDocumentSnapshot> pedidosDocs = snapshotPedidos.hasData ? snapshotPedidos.data!.docs : [];
              return _buildPage(isDark, pedidosDocs);
            }
          );
        }
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() { _currentIndex = index; _pedidoSeleccionadoId = null; }),
        selectedItemColor: const Color(0xFFFFB300),
        unselectedItemColor: isDark ? Colors.white30 : Colors.black38,
        backgroundColor: isDark ? const Color(0xFF131316) : Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.all_inbox_rounded), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.toggle_on_rounded), label: 'Control'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded), label: 'Despacho'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Historial'),
        ],
      ),
    );
  }

  Widget _buildPage(bool isDark, List<QueryDocumentSnapshot> todosLosPedidos) {
    switch (_currentIndex) {
      case 0: return _buildBuzonTab(isDark, todosLosPedidos);
      case 1: return _buildControlTab(isDark);
      case 2: return _buildDespachoTab(isDark, todosLosPedidos);
      case 3: return _buildHistorialTab(isDark, todosLosPedidos);
      default: return _buildBuzonTab(isDark, todosLosPedidos);
    }
  }

  Widget _buildBuzonTab(bool isDark, List<QueryDocumentSnapshot> todosLosPedidos) {
    final buzonList = todosLosPedidos.where((p) => (p.data() as Map<String, dynamic>)['estado'] == "Buzon").toList();
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);

    if (buzonList.isEmpty) return Center(child: Text('No hay pedidos nuevos en el buzón.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)));

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: buzonList.length,
      itemBuilder: (context, index) {
        final doc = buzonList[index];
        final pedido = doc.data() as Map<String, dynamic>;
        final String pedidoId = doc.id;
        final bool estaExpandido = _pedidoSeleccionadoId == pedidoId;
        
        final int cantidad = (pedido['cantidad'] is num) ? (pedido['cantidad'] as num).toInt() : int.tryParse(pedido['cantidad'].toString()) ?? 0;

        Color metodoColor = const Color(0xFFFFB300); 
        if (pedido['metodoPago'] == "Transferencia") metodoColor = Colors.blueAccent;
        if (pedido['metodoPago'] == "Tarjeta") metodoColor = Colors.greenAccent;

        String fechaLegible = "Sin fecha";
        if (pedido['fecha'] != null) {
          final DateTime dt = (pedido['fecha'] as Timestamp).toDate();
          fechaLegible = "${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: InkWell(
            onTap: () => setState(() => _pedidoSeleccionadoId = estaExpandido ? null : pedidoId),
            borderRadius: BorderRadius.circular(28),
            child: LiquidGlassCard(
              isDark: isDark,
              gradientColors: estaExpandido ? [metodoColor.withOpacity(0.06), Colors.transparent] : null,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fechaLegible, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: metodoColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(pedido['metodoPago'].toString().toUpperCase(), style: TextStyle(color: metodoColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(pedido['cliente'] ?? 'Sin Nombre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                    const SizedBox(height: 10),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_rounded, size: 24, color: isDark ? Colors.white54 : Colors.blueGrey[400]),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pedido['direccion'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey[800], fontSize: 14))),
                        InkWell(
                          onTap: () => _abrirMapa(pedido['direccion']),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.map_rounded, color: Colors.blueAccent, size: 24),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_android_rounded, size: 24, color: isDark ? Colors.white54 : Colors.blueGrey[400]),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pedido['telefono'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey[800], fontSize: 14))),
                        InkWell(
                          onTap: () => _llamarTelefono(pedido['telefono']),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.phone_rounded, color: Colors.green, size: 24),
                          ),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$cantidad ${cantidad == 1 ? 'Cartón' : 'Cartones'}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          Text('RD\$ ${(pedido['total'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF6D00))),
                        ],
                      ),
                    ),
                    
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: estaExpandido ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _abrirWhatsApp(pedido['telefono']),
                                  icon: const Icon(Icons.chat_rounded, size: 16),
                                  label: const Text('WHATSAPP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (pedido['metodoPago'] == "Transferencia" && pedido['comprobante'] != null && pedido['comprobante'] != "")
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _abrirRecibo(pedido['comprobante']),
                                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                    label: const Text('VER RECIBO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: const BorderSide(color: Colors.blueAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              _actualizarEstadoPedido(pedidoId, "Despacho");
                              _pedidoSeleccionadoId = null;
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('PROCESAR DESPACHO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                          ),
                        ],
                      ) : const SizedBox.shrink(),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlTab(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);
    
    if (_precioCtrl.text.isEmpty && AdminData.precioPorCarton > 0) {
      _precioCtrl.text = AdminData.precioPorCarton.toStringAsFixed(0);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiquidGlassCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Inventario Abierto', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: const Text('Controla si los clientes pueden pedir'),
                    value: AdminData.granjaAbierta,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) {
                      setState(() => AdminData.granjaAbierta = v);
                      _guardarConfiguracion();
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text('Pago con Tarjetas', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: const Text('Habilitar pago Crédito/Débito'),
                    value: AdminData.tarjetaHabilitada,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) {
                      setState(() => AdminData.tarjetaHabilitada = v);
                      _guardarConfiguracion();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          LiquidGlassCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _precioCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Precio Cartón (RD\$)', border: InputBorder.none),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => AdminData.precioPorCarton = double.tryParse(_precioCtrl.text) ?? AdminData.precioPorCarton);
                      _guardarConfiguracion();
                      _notificarAccion('Precio modificado');
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), foregroundColor: Colors.white),
                    child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.w900)),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Cuentas Registradas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          ...AdminData.cuentasBancarias.map((cta) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: LiquidGlassCard(
              isDark: isDark,
              child: ListTile(
                title: Text('${cta['banco']} (${cta['tipo']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Cuenta: ${cta['cuenta']}\nTitular: ${cta['titular']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () {
                    setState(() => AdminData.cuentasBancarias.remove(cta));
                    _guardarConfiguracion();
                  },
                ),
              ),
            ),
          )).toList(),
          const SizedBox(height: 12),
          
          LiquidGlassCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Agregar Nueva Cuenta', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  _buildAdminField(_titularCtrl, 'Nombre del Titular', isDark),
                  const SizedBox(height: 8),
                  _buildAdminField(_bancoCtrl, 'Nombre del Banco', isDark),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cuentaCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: const InputDecoration(labelText: 'Número de Cuenta', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _tipoCuentaSeleccionada,
                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(labelText: 'Tipo de Cuenta', border: OutlineInputBorder()),
                    items: const [DropdownMenuItem(value: "Ahorros", child: Text("Ahorros")), DropdownMenuItem(value: "Corriente", child: Text("Corriente"))],
                    onChanged: (v) => setState(() => _tipoCuentaSeleccionada = v!),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_bancoCtrl.text.isNotEmpty && _cuentaCtrl.text.isNotEmpty) {
                        setState(() {
                          AdminData.cuentasBancarias.add({
                            "banco": _bancoCtrl.text, "cuenta": _cuentaCtrl.text,
                            "tipo": _tipoCuentaSeleccionada, "titular": _titularCtrl.text
                          });
                          _bancoCtrl.clear(); _cuentaCtrl.clear(); _titularCtrl.clear();
                        });
                        _guardarConfiguracion();
                        _notificarAccion('Cuenta añadida');
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
                    child: const Text('AÑADIR CUENTA BANCARIA', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminField(TextEditingController ctrl, String label, bool isDark) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _buildDespachoTab(bool isDark, List<QueryDocumentSnapshot> todosLosPedidos) {
    final despachoList = todosLosPedidos.where((p) => (p.data() as Map<String, dynamic>)['estado'] == "Despacho").toList();
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);

    if (despachoList.isEmpty) return Center(child: Text('No hay camiones en ruta o despachos pendientes.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)));

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: despachoList.length,
      itemBuilder: (context, index) {
        final doc = despachoList[index];
        final pedido = doc.data() as Map<String, dynamic>;
        
        String fechaDespacho = "Hace poco";
        if (pedido['fechaDespacho'] != null) {
           final dt = (pedido['fechaDespacho'] as Timestamp).toDate();
           fechaDespacho = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}";
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: LiquidGlassCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('EN RUTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                      Text('Salió: $fechaDespacho', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold))
                    ],
                  ),
                  const Divider(height: 24),
                  Text(pedido['cliente'] ?? 'Sin Nombre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Destino: ', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey[600])),
                      Expanded(child: Text(pedido['direccion'] ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600))),
                      InkWell(
                        onTap: () => _abrirMapa(pedido['direccion']),
                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.map_rounded, color: Colors.blueAccent, size: 24)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Contacto: ', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13)),
                      Expanded(child: Text(pedido['telefono'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600))),
                      InkWell(
                        onTap: () => _llamarTelefono(pedido['telefono']),
                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.phone_rounded, color: Colors.green, size: 24)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () {
                      _actualizarEstadoPedido(doc.id, "Historial");
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('CONFIRMAR COMO ENTREGADO', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistorialTab(bool isDark, List<QueryDocumentSnapshot> todosLosPedidos) {
    final historialList = todosLosPedidos.where((p) => (p.data() as Map<String, dynamic>)['estado'] == "Historial").toList();
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);

    if (historialList.isEmpty) return Center(child: Text('El historial de cierres está vacío.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)));

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: historialList.length,
      itemBuilder: (context, index) {
        final pedido = historialList[index].data() as Map<String, dynamic>;
        
        final int cantidad = (pedido['cantidad'] is num) ? (pedido['cantidad'] as num).toInt() : int.tryParse(pedido['cantidad'].toString()) ?? 0;

        String fechaFin = "Fecha desconocida";
        if (pedido['fechaEntrega'] != null) {
           final dt = (pedido['fechaEntrega'] as Timestamp).toDate();
           fechaFin = "${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: LiquidGlassCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pedido['cliente'] ?? 'Sin Nombre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 4),
                        Text('Entregado el: $fechaFin', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 12)),
                        Text('$cantidad ${cantidad == 1 ? 'Cartón' : 'Cartones'} • Metodo: ${pedido['metodoPago']}', style: TextStyle(color: isDark ? Colors.white60 : Colors.blueGrey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  Text('RD\$ ${(pedido['total'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final List<Color>? gradientColors;

  const LiquidGlassCard({
    Key? key, 
    required this.child, 
    required this.isDark,
    this.gradientColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradientColors != null 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors!,
                  )
                : null,
            color: gradientColors == null 
                ? (isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.65))
                : null,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.9), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }
}