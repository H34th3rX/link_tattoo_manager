import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme_provider.dart';


// Constantes globales para la página de perfil del cliente
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const double borderRadius = 12.0;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

class ClientProfilePage extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientProfilePage({super.key, required this.client});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Simulated data for the client
  late Map<String, dynamic> _clientStats;
  late List<Map<String, dynamic>> _recentTattoos;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _initializeClientData();
    _animationController.forward();
  }

  void _initializeClientData() {
    // Simulated client statistics
    _clientStats = {
      'tattoos_count': 3,
      'total_spent': 550,
      'pending_appointments': 1,
    };

    // Simulated recent tattoos
    _recentTattoos = [
      {
        'id': '1',
        'name': 'Rosa en el antebrazo',
        'artist': 'Carlos Mendoza',
        'date': '2024-01-15',
        'price': 250,
        'status': 'Completado',
      },
      {
        'id': '2',
        'name': 'Mariposa en el hombro',
        'artist': 'Ana Ruiz',
        'date': '2023-08-22',
        'price': 180,
        'status': 'Completado',
      },
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getClientInitials() {
    final name = widget.client['name'] as String? ?? 'Cliente';
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return 'C';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDark;
    final bool isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: isDark ? backgroundColor : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? backgroundColor : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? textColor : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Perfil Cliente',
          style: TextStyle(
            color: primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: isDark ? textColor : Colors.black87,
            ),
            onPressed: () {
              //  Navigate to edit client page
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          BlurredBackground(isDark: isDark),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 40 : 24,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClientInfoCard(isDark),
                          const SizedBox(height: 24),
                          _buildStatsCards(isDark),
                          const SizedBox(height: 32),
                          _buildRecentTattoosSection(isDark),
                          const SizedBox(height: 32),
                          _buildActionButtons(isDark),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard(bool isDark) {
    final clientName = widget.client['name'] as String? ?? 'Cliente';
    final clientPhone = widget.client['phone'] as String? ?? '+1 234-567-8901';
    final clientEmail = widget.client['email'] as String? ?? 'cliente@email.com';
    final registrationDate = widget.client['registration_date'] as String? ?? '2023-03-01';

    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getClientInitials(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.phone, clientPhone, isDark),
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.email, clientEmail, isDark),
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.calendar_today, 'Cliente desde: ${_formatDate(registrationDate)}', isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: primaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? hintColor : Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '${_clientStats['tattoos_count']}',
            'Tatuajes',
            Icons.brush,
            isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '\$${_clientStats['total_spent']}',
            'Gastado',
            Icons.attach_money,
            isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '${_clientStats['pending_appointments']}',
            'Pendiente',
            Icons.schedule,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? hintColor : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTattoosSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tatuajes Recientes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? textColor : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentTattoos.length,
          itemBuilder: (context, index) {
            final tattoo = _recentTattoos[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTattooCard(tattoo, isDark),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTattooCard(Map<String, dynamic> tattoo, bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tattoo['name'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? textColor : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Por ${tattoo['artist']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? hintColor : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tattoo['date'],
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? hintColor : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${tattoo['price']}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: successColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  tattoo['status'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: successColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/appointments');
            },
            icon: const Icon(Icons.calendar_today, color: Colors.black),
            label: const Text(
              'Agendar Nueva Cita',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate to full history
            },
            icon: Icon(
              Icons.history,
              color: isDark ? textColor : Colors.black87,
            ),
            label: Text(
              'Ver Historial Completo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? textColor : Colors.black87,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
