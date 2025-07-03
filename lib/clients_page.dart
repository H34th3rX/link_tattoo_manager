import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import 'appbar.dart';
import './integrations/clients_service.dart';

// Constantes globales para la página de clientes
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const double borderRadius = 12.0;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> with TickerProviderStateMixin {
  String? _userName;
  late Future<void> _loadUserData;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _preferredContactCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  bool _isPopupOpen = false;
  bool _showInactiveClients = true;
  String? _error;
  String? _successMessage;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  Map<String, dynamic>? _selectedClient;
  late AnimationController _errorAnimationController;
  late AnimationController _successAnimationController;

  @override
  void initState() {
    super.initState();
    _loadUserData = _fetchUserData();
    _errorAnimationController = AnimationController(
      duration: themeAnimationDuration,
      vsync: this,
    );
    _successAnimationController = AnimationController(
      duration: themeAnimationDuration,
      vsync: this,
    );
    _searchCtrl.addListener(_filterClients);

    _fetchClients();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _preferredContactCtrl.dispose();
    _searchCtrl.dispose();
    _errorAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final snapshot = await Supabase.instance.client
          .from('employees')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _userName = snapshot?['username'] as String? ?? user.email!.split('@')[0];
        });
      }
    } catch (e) {
      _showError('Error al cargar datos del usuario');
    }
  }

  Future<void> _fetchClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final response = await ClientsService.getClients(user.id);
      if (mounted) {
        setState(() {
          _clients = (response as List<dynamic>)
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _filteredClients = List.from(_clients);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al cargar los clientes. Verifica tu conexión.');
      }
    }
  }

  void _filterClients() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        final name = client['name']?.toString().toLowerCase() ?? '';
        final email = client['email']?.toString().toLowerCase() ?? '';
        final phone = client['phone']?.toString().toLowerCase() ?? '';
        final isActive = client['status'] ?? true;
        
        final matchesSearch = name.contains(query) || 
                             email.contains(query) || 
                             phone.contains(query);
        
        final matchesStatus = _showInactiveClients || isActive;
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _toggleInactiveClients() {
    setState(() {
      _showInactiveClients = !_showInactiveClients;
    });
    _filterClients();
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _loading = false;
    });
    _errorAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _errorAnimationController.reverse();
          setState(() => _error = null);
        }
      });
    });
  }

  void _showSuccess(String message) {
    setState(() => _successMessage = message);
    _successAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _successAnimationController.reverse();
          setState(() => _successMessage = null);
        }
      });
    });
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      _showError('Error al cerrar sesión.');
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationsBottomSheet(),
    );
  }

  void _openCreateClientPopup() {
    _resetForm();
    _selectedClient = null;
    setState(() => _isPopupOpen = true);
  }

  void _openEditClientPopup(Map<String, dynamic> client) {
    _selectedClient = client;
    _nameCtrl.text = client['name'] ?? '';
    _phoneCtrl.text = client['phone'] ?? '';
    _emailCtrl.text = client['email'] ?? '';
    _notesCtrl.text = client['notes'] ?? '';
    _preferredContactCtrl.text = client['preferred_contact_method'] ?? '';
    setState(() => _isPopupOpen = true);
  }

  void _closePopup() {
    setState(() => _isPopupOpen = false);
    _resetForm();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _notesCtrl.clear();
    _preferredContactCtrl.clear();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null;
      final notes = _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      final preferredContactMethod = _preferredContactCtrl.text.trim().toLowerCase();

      if (_selectedClient == null) {
        await ClientsService.createClient(
          employeeId: user.id,
          name: name,
          phone: phone,
          email: email,
          notes: notes,
          preferredContactMethod: preferredContactMethod,
        );
        _showSuccess('Cliente creado exitosamente');
      } else {
        await ClientsService.updateClient(
          clientId: _selectedClient!['id'],
          employeeId: user.id,
          name: name,
          phone: phone,
          email: email,
          notes: notes,
          preferredContactMethod: preferredContactMethod,
        );
        _showSuccess('Cliente actualizado exitosamente');
      }
      
      if (mounted) {
        _closePopup();
        await _fetchClients();
      }
    } catch (e) {
      _showError('Error al guardar el cliente: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteClient(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar este cliente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      await ClientsService.deleteClient(id, user.id);
      if (mounted) {
        setState(() {
          _clients.removeWhere((client) => client['id'] == id);
          _filteredClients.removeWhere((client) => client['id'] == id);
          _loading = false;
        });
        _showSuccess('Cliente eliminado exitosamente');
      }
    } catch (e) {
      _showError('Error al eliminar el cliente.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleClientStatus(String id, bool currentStatus) async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      
      await ClientsService.toggleClientStatus(
        clientId: id,
        employeeId: user.id,
        newStatus: !currentStatus,
      );
      
      if (mounted) {
        setState(() {
          final clientIndex = _clients.indexWhere((c) => c['id'] == id);
          if (clientIndex != -1) {
            _clients[clientIndex]['status'] = !currentStatus;
          }
          final filteredIndex = _filteredClients.indexWhere((c) => c['id'] == id);
          if (filteredIndex != -1) {
            _filteredClients[filteredIndex]['status'] = !currentStatus;
          }
          _loading = false;
        });
        _showSuccess('Estado del cliente actualizado');
      }
    } catch (e) {
      _showError('Error al cambiar el estado del cliente.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final user = Supabase.instance.client.auth.currentUser!;
    final bool isDark = themeProvider.isDark;

    return FutureBuilder(
      future: _loadUserData,
      builder: (context, snapshot) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Scaffold(
              backgroundColor: isDark ? backgroundColor : Colors.grey[100],
              appBar: CustomAppBar(
                title: 'Gestión de Clientes',
                onNotificationPressed: _showNotifications,
                isWide: isWide,
              ),
              drawer: isWide
                  ? null
                  : Drawer(
                      child: _userName != null
                          ? NavPanel(
                              user: user,
                              onLogout: _logout,
                              userName: _userName!,
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
              body: Stack(
                children: [
                  BlurredBackground(isDark: isDark),
                  isWide
                      ? Row(
                          children: [
                            SizedBox(
                              width: 280,
                              child: _userName != null
                                  ? NavPanel(
                                      user: user,
                                      onLogout: _logout,
                                      userName: _userName!,
                                    )
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _buildMainContent(isDark, isWide),
                            ),
                          ],
                        )
                      : _buildMainContent(isDark, isWide),
                  // Popup centrado en el contenido principal
                  if (_isPopupOpen)
                    Positioned.fill(
                      left: isWide ? 280 : 0, // Offset para el nav panel en web
                      child: ClientPopup(
                        onClose: _closePopup,
                        formKey: _formKey,
                        nameCtrl: _nameCtrl,
                        phoneCtrl: _phoneCtrl,
                        emailCtrl: _emailCtrl,
                        notesCtrl: _notesCtrl,
                        preferredContactCtrl: _preferredContactCtrl,
                        selectedClient: _selectedClient,
                        loading: _loading,
                        error: _error,
                        saveClient: _saveClient,
                      ),
                    ),
                  // Mensajes de error y éxito
                  if (_error != null)
                    Positioned(
                      bottom: 20,
                      left: isWide ? 296 : 16, // Offset para el nav panel
                      right: 16,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(_errorAnimationController),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: errorColor,
                              borderRadius: BorderRadius.circular(borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_successMessage != null)
                    Positioned(
                      bottom: 20,
                      left: isWide ? 296 : 16, // Offset para el nav panel
                      right: 16,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(_successAnimationController),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: successColor,
                              borderRadius: BorderRadius.circular(borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainContent(bool isDark, bool isWide) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 24,
              vertical: 16, // Reducido de 24 a 16
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 16),
                _buildSearchBar(isDark),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildClientsList(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? textColor : Colors.black87,
                ),
                child: const Text('Mis Clientes'),
              ),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
                child: Text('${_filteredClients.length} de ${_clients.length} clientes mostrados'),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _loading ? null : _openCreateClientPopup,
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text(
              'Nuevo Cliente',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Column(
      children: [
        AnimatedContainer(
          duration: themeAnimationDuration,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: isDark ? textColor : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Buscar clientes por nombre, email o teléfono...',
              hintStyle: TextStyle(color: isDark ? hintColor : Colors.grey[600]),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? hintColor : Colors.grey[600],
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: isDark ? hintColor : Colors.grey[600],
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        _filterClients();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedContainer(
              duration: themeAnimationDuration,
              decoration: BoxDecoration(
                color: _showInactiveClients 
                    ? (isDark ? Colors.grey[800] : Colors.white)
                    : primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showInactiveClients 
                      ? (isDark ? Colors.grey[600]! : Colors.grey[300]!)
                      : primaryColor,
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: _toggleInactiveClients,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showInactiveClients 
                            ? Icons.visibility 
                            : Icons.visibility_off,
                        size: 18,
                        color: _showInactiveClients 
                            ? (isDark ? hintColor : Colors.grey[600])
                            : primaryColor,
                      ),
                      const SizedBox(width: 6),
                      AnimatedDefaultTextStyle(
                        duration: themeAnimationDuration,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _showInactiveClients 
                              ? (isDark ? hintColor : Colors.grey[600])
                              : primaryColor,
                        ),
                        child: Text(_showInactiveClients ? 'Mostrar todos' : 'Solo activos'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            _buildClientStats(isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildClientStats(bool isDark) {
    final activeClients = _clients.where((client) => client['status'] ?? true).length;
    final inactiveClients = _clients.length - activeClients;
    
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: successColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? textColor : Colors.black87,
                ),
                child: Text('$activeClients'),
              ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? textColor : Colors.black87,
                ),
                child: Text('$inactiveClients'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientsList(bool isDark) {
    if (_loading && _clients.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_filteredClients.isEmpty) {
      String emptyMessage;
      String emptySubmessage;
      
      if (_searchCtrl.text.isNotEmpty) {
        emptyMessage = 'No se encontraron clientes';
        emptySubmessage = !_showInactiveClients 
            ? 'Intenta buscar en todos los clientes o revisa los filtros'
            : 'Intenta con otros términos de búsqueda';
      } else if (!_showInactiveClients && _clients.any((c) => !(c['status'] ?? true))) {
        emptyMessage = 'Solo clientes activos';
        emptySubmessage = 'Hay clientes inactivos disponibles. Toca "Mostrar todos" para verlos.';
      } else {
        emptyMessage = 'No hay clientes registrados';
        emptySubmessage = 'Agrega tu primer cliente para comenzar';
      }
      
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: isDark ? hintColor : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
                child: Text(emptyMessage),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[500],
                ),
                child: Text(
                  emptySubmessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchClients,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _getMaxCrossAxisExtent(MediaQuery.of(context).size.width),
                childAspectRatio: _getChildAspectRatio(MediaQuery.of(context).size.width),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final client = _filteredClients[index];
                  return AnimatedAppearance(
                    delay: index * 50,
                    child: ClientCard(
                      client: client,
                      isDark: isDark,
                      onEdit: () => _openEditClientPopup(client),
                      onDelete: () => _deleteClient(client['id']),
                      onToggleStatus: () => _toggleClientStatus(
                        client['id'],
                        client['status'] ?? true,
                      ),
                      isLoading: _loading,
                    ),
                  );
                },
                childCount: _filteredClients.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxCrossAxisExtent(double width) {
    if (width < 600) return 800;   // 1 columna para móviles
    if (width < 900) return 400;   // 2 columnas para tablets pequeños
    return 350;                    // 3 columnas para web
  }

  double _getChildAspectRatio(double width) {
    if (width < 600) return 1.6;   // Más alto para móviles (era 1.5)
    if (width < 900) return 1.4;   // Tablets pequeños
    return 1.1;                    // Web - más compacto (era 1.6)
  }
}

class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Notificaciones',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text('No hay notificaciones nuevas'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final bool isLoading;

  const ClientCard({
    super.key,
    required this.client,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = client['status'] ?? true;
    final preferredContact = client['preferred_contact_method'] ?? 'No especificado';
    final notes = client['notes'] ?? 'Sin notas';
    final bool isWide = MediaQuery.of(context).size.width >= 800;

    return AnimatedContainer(
      duration: themeAnimationDuration,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08),
            blurRadius: isDark ? 6 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con avatar, nombre y switch
            Row(
              children: [
                Container(
                  width: isWide ? 48 : 44, // Más grande en web
                  height: isWide ? 48 : 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive
                          ? [primaryColor, primaryColor.withValues(alpha: 0.7)]
                          : [Colors.grey, Colors.grey.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isWide ? 24 : 22),
                    boxShadow: [
                      BoxShadow(
                        color: (isActive ? primaryColor : Colors.grey).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: isWide ? 32 : 28, // Más grande en web
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: themeAnimationDuration,
                        style: TextStyle(
                          color: isDark ? textColor : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        child: Text(
                          client['name'] ?? 'Sin nombre',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? successColor : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedDefaultTextStyle(
                            duration: themeAnimationDuration,
                            style: TextStyle(
                              color: isActive ? successColor : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            child: Text(isActive ? 'Activo' : 'Inactivo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: isActive ? 'Desactivar cliente' : 'Activar cliente',
                  child: Transform.scale(
                    scale: 0.7,
                    child: AnimatedContainer(
                      duration: themeAnimationDuration,
                      child: Switch(
                        value: isActive,
                        onChanged: isLoading ? null : (_) => onToggleStatus(),
                        activeColor: primaryColor,
                        inactiveThumbColor: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Información del cliente
            if (client['email'] != null || client['phone'] != null || preferredContact != 'No especificado' || notes != 'Sin notas') ...[
              AnimatedContainer(
                duration: themeAnimationDuration,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.grey[700]?.withValues(alpha: 0.3)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[600]! : Colors.grey[200]!,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (client['email'] != null)
                      _buildInfoRow(Icons.email, client['email']),
                    if (client['email'] != null && client['phone'] != null)
                      const SizedBox(height: 4),
                    if (client['phone'] != null)
                      _buildInfoRow(Icons.phone, client['phone']),
                    if (preferredContact != 'No especificado') ...[
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.contact_phone_outlined, 'Pref: $preferredContact'),
                    ],
                    if (notes != 'Sin notas') ...[
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.note_outlined, notes),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Botones de acción
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isWide ? 36 : 32,
                      height: isWide ? 36 : 32,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.visibility, size: isWide ? 20 : 18),
                        color: Colors.blue,
                        onPressed: isLoading ? null : () {
                          Navigator.pushNamed(
                            context, 
                            '/client_profile',
                            arguments: client,
                          );
                        },
                        tooltip: 'Ver perfil',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: isWide ? 36 : 32,
                      height: isWide ? 36 : 32,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.edit, size: isWide ? 20 : 18),
                        color: primaryColor,
                        onPressed: isLoading ? null : onEdit,
                        tooltip: 'Editar',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: isWide ? 36 : 32,
                      height: isWide ? 36 : 32,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete, size: isWide ? 20 : 18),
                        color: Colors.red,
                        onPressed: isLoading ? null : onDelete,
                        tooltip: 'Eliminar',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? hintColor : Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: themeAnimationDuration,
            style: TextStyle(
              color: isDark ? hintColor : Colors.grey[600],
              fontSize: 14,
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class ClientPopup extends StatefulWidget {
  final VoidCallback onClose;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController preferredContactCtrl;
  final Map<String, dynamic>? selectedClient;
  final bool loading;
  final String? error;
  final Future<void> Function() saveClient;

  const ClientPopup({
    super.key,
    required this.onClose,
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.notesCtrl,
    required this.preferredContactCtrl,
    required this.selectedClient,
    required this.loading,
    required this.error,
    required this.saveClient,
  });

  @override
  State<ClientPopup> createState() => _ClientPopupState();
}

class _ClientPopupState extends State<ClientPopup>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedContactMethod = 'email';
  final List<Map<String, dynamic>> _contactMethods = [
    {'value': 'email', 'label': 'Email', 'icon': Icons.email},
    {'value': 'telefono', 'label': 'Teléfono', 'icon': Icons.phone},
    {'value': 'whatsapp', 'label': 'WhatsApp', 'icon': Icons.chat},
    {'value': 'sms', 'label': 'SMS', 'icon': Icons.sms},
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    if (widget.selectedClient != null) {
      final existingMethod = widget.selectedClient!['preferred_contact_method']?.toString().toLowerCase();
      if (existingMethod != null && _contactMethods.any((m) => m['value'] == existingMethod)) {
        _selectedContactMethod = existingMethod;
      }
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeWithAnimation() async {
    await _animationController.reverse();
    widget.onClose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'El nombre es requerido';
    if (value.length < 2 || value.length > 50) {
      return 'El nombre debe tener entre 2 y 50 caracteres';
    }
    if (!RegExp(r'^[a-zA-ZÀ-ÿñÑ\s]+$').hasMatch(value)) {
      return 'El nombre solo puede contener letras y espacios';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'El teléfono es requerido';
    if (!RegExp(r'^\+?[\d\s\-()]{7,15}$').hasMatch(value)) {
      return 'Formato de teléfono no válido';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value)) {
      return 'Formato de email no válido';
    }
    return null;
  }

  Future<void> _handleSave() async {
    widget.preferredContactCtrl.text = _selectedContactMethod;
    await widget.saveClient();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: (0.5 * _opacityAnimation.value).clamp(0.0, 1.0)),
          child: Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    constraints: const BoxConstraints(maxWidth: 550),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: widget.formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(isDark),
                              const SizedBox(height: 28),
                              _buildFormFields(isDark),
                              const SizedBox(height: 24),
                              if (widget.error != null) _buildErrorMessage(),
                              _buildActionButtons(isDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.selectedClient == null ? Icons.person_add : Icons.edit,
            color: Colors.black,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.selectedClient == null ? 'Nuevo Cliente' : 'Editar Cliente',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? textColor : Colors.black87,
                ),
              ),
              Text(
                widget.selectedClient == null 
                    ? 'Agrega la información del cliente'
                    : 'Modifica los datos del cliente',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _closeWithAnimation,
            color: isDark ? textColor : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields(bool isDark) {
    return Column(
      children: [
        _buildAnimatedTextField(
          controller: widget.nameCtrl,
          label: 'Nombre completo',
          icon: Icons.person_outline,
          validator: _validateName,
          isDark: isDark,
          isRequired: true,
          delay: 0,
        ),
        const SizedBox(height: 20),
        
        _buildAnimatedTextField(
          controller: widget.phoneCtrl,
          label: 'Teléfono',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
          isDark: isDark,
          delay: 100,
        ),
        const SizedBox(height: 20),
        
        _buildAnimatedTextField(
          controller: widget.emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
          isDark: isDark,
          delay: 150,
        ),
        const SizedBox(height: 20),
        
        _buildContactMethodSelector(isDark),
        const SizedBox(height: 20),
        
        _buildAnimatedTextField(
          controller: widget.notesCtrl,
          label: 'Notas adicionales',
          icon: Icons.note_outlined,
          maxLines: 3,
          isDark: isDark,
          delay: 250,
        ),
      ],
    );
  }

  Widget _buildContactMethodSelector(bool isDark) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.contact_phone_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Método de contacto preferido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: _contactMethods.map((method) {
                      final isSelected = _selectedContactMethod == method['value'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedContactMethod = method['value'];
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  method['icon'],
                                  color: isSelected ? Colors.black : (isDark ? hintColor : Colors.grey[600]),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  method['label'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.black : (isDark ? hintColor : Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = false,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              validator: validator,
              style: TextStyle(
                color: isDark ? textColor : Colors.black87,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: isRequired ? '$label *' : label,
                labelStyle: TextStyle(
                  color: isDark ? hintColor : Colors.grey[600],
                  fontSize: 14,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: errorColor),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: errorColor, width: 2),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            errorColor.withValues(alpha: 0.1),
            errorColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: errorColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: errorColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline, color: errorColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.error!,
              style: TextStyle(
                color: errorColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: widget.loading ? null : _closeWithAnimation,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close,
                  size: 18,
                  color: isDark ? textColor : Colors.black87,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cancelar',
                  style: TextStyle(
                    color: isDark ? textColor : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: widget.loading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.selectedClient == null ? Icons.add : Icons.save,
                        color: Colors.black,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.selectedClient == null ? 'Crear Cliente' : 'Actualizar',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class AnimatedAppearance extends StatefulWidget {
  final Widget child;
  final int delay;

  const AnimatedAppearance({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  State<AnimatedAppearance> createState() => _AnimatedAppearanceState();
}

class _AnimatedAppearanceState extends State<AnimatedAppearance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}

class BlurredBackground extends StatelessWidget {
  final bool isDark;

  const BlurredBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/logo.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: themeAnimationDuration,
            color: isDark
                ? const Color.fromRGBO(0, 0, 0, 0.7)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
