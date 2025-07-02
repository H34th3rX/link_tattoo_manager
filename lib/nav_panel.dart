import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme_provider.dart';

class NavPanel extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  final String userName;

  const NavPanel({super.key, required this.user, required this.onLogout, required this.userName});

  @override
  State<NavPanel> createState() => _NavPanelState();
}

class _NavPanelState extends State<NavPanel> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _pulseController;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String current = ModalRoute.of(context)?.settings.name ?? '';
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    const ui.Color primaryAccent = ui.Color(0xFFBDA206);
    const ui.Color secondaryAccent = ui.Color(0xFF00D4FF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: themeProvider.isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF1A1A1A),
                  Color(0xFF000000),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8F9FA),
                  Color(0xFFE9ECEF),
                  Color(0xFFDEE2E6),
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildModernHeader(themeProvider, primaryAccent),
          Expanded(
            child: _buildNavigationList(current, theme, themeProvider, primaryAccent, secondaryAccent),
          ),
          _buildBottomSection(theme, themeProvider, primaryAccent),
        ],
      ),
    );
  }

  Widget _buildModernHeader(ThemeProvider themeProvider, ui.Color accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeProvider.isDark ? [
            const Color(0xFFBDA206),
            const Color(0xFF8B7505),
            const Color(0xFF3A3A3A),
          ] : [
            accent,
            accent.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Colors.white, Color(0xFFF0F0F0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3 + 0.2 * _pulseController.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.user.email![0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            widget.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.user.email!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList(String current, ThemeData theme, ThemeProvider themeProvider, ui.Color primaryAccent, ui.Color secondaryAccent) {
    final navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.event_available_rounded, 'label': 'Citas', 'route': '/appointments'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Calendario', 'route': '/calendar'},
      {'icon': Icons.people_rounded, 'label': 'Clientes', 'route': '/clients'},
      {'icon': Icons.picture_as_pdf_rounded, 'label': 'Reportes', 'route': '/reports'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      itemCount: navItems.length,
      itemBuilder: (context, index) {
        final item = navItems[index];
        final isSelected = current == item['route'];
        final isHovered = _hoveredIndex == index;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MouseRegion(
            onEnter: (_) {
              setState(() => _hoveredIndex = index);
              _hoverController.forward();
            },
            onExit: (_) {
              setState(() => _hoveredIndex = -1);
              _hoverController.reverse();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSelected
                    ? LinearGradient(
                        colors: themeProvider.isDark ? [
                          const Color(0xFFBDA206).withValues(alpha: 0.3),
                          const Color(0xFF3A3A3A).withValues(alpha: 0.2),
                        ] : [
                          primaryAccent.withValues(alpha: 0.2),
                          secondaryAccent.withValues(alpha: 0.1),
                        ],
                      )
                    : isHovered
                        ? LinearGradient(
                            colors: themeProvider.isDark ? [
                              const Color(0xFFBDA206).withValues(alpha: 0.15),
                              Colors.transparent,
                            ] : [
                              primaryAccent.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          )
                        : null,
                border: isSelected
                    ? Border.all(color: primaryAccent.withValues(alpha: 0.5), width: 1)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryAccent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryAccent.withValues(alpha: 0.2)
                        : isHovered
                            ? primaryAccent.withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: isSelected
                        ? primaryAccent
                        : themeProvider.isDark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.7),
                    size: 24,
                  ),
                ),
                title: Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? primaryAccent
                        : themeProvider.isDark
                            ? Colors.white
                            : Colors.black87,
                    fontSize: 16,
                  ),
                ),
                trailing: isSelected
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: primaryAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryAccent.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      )
                    : null,
                onTap: () => Navigator.of(context).pushReplacementNamed(item['route'] as String),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection(ThemeData theme, ThemeProvider themeProvider, ui.Color accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: themeProvider.isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildThemeSwitcher(theme, themeProvider, accent),
          const SizedBox(height: 8),
          _buildLogoutButton(accent),
        ],
      ),
    );
  }

  Widget _buildThemeSwitcher(ThemeData theme, ThemeProvider themeProvider, ui.Color accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.isDark
            ? Colors.grey[800]!.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            themeProvider.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: themeProvider.isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Modo Oscuro',
            style: TextStyle(
              color: themeProvider.isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 50,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: themeProvider.isDark
                  ? const LinearGradient(colors: [Color(0xFFBDA206), Color(0xFF3A3A3A)])
                  : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: themeProvider.isDark ? 26 : 2,
                  top: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).onTap(() => themeProvider.toggle());
  }

  Widget _buildLogoutButton(ui.Color accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade400,
            Colors.red.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onLogout,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: this,
    );
  }
}