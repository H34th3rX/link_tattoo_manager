import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

//[-------------CONSTANTES GLOBALES--------------]
const Color primaryColor = Color(0xFFBDA206);
const Color textColor = Colors.white;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

//[-------------APPBAR PERSONALIZADO--------------]
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
final String title;
final VoidCallback onNotificationPressed;
final bool isWide;
final bool showBackButton; // Nuevo parámetro

const CustomAppBar({
  super.key,
  required this.title,
  required this.onNotificationPressed,
  required this.isWide,
  this.showBackButton = false, // Valor por defecto
});

@override
Widget build(BuildContext context) {
  return Consumer<ThemeProvider>(
    builder: (context, themeProvider, child) {
      final bool isDark = themeProvider.isDark;

      return AnimatedContainer(
        duration: themeAnimationDuration,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : primaryColor,
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: AnimatedDefaultTextStyle(
            duration: themeAnimationDuration,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            child: Text(title),
          ),
          actions: [
            AnimatedContainer(
              duration: themeAnimationDuration,
              child: IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: onNotificationPressed,
                tooltip: 'Notificaciones',
                color: isDark ? textColor : Colors.black87,
              ),
            ),
            AnimatedContainer(
              duration: themeAnimationDuration,
              child: IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () => Navigator.of(context).pushNamed('/profile'),
                tooltip: 'Perfil',
                color: isDark ? textColor : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
          ],
          leading: showBackButton // Condición para mostrar el botón de retroceso
              ? AnimatedContainer(
                  duration: themeAnimationDuration,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    color: isDark ? textColor : Colors.black87,
                  ),
                )
              : (isWide
                  ? null
                  : Builder(
                      builder: (ctx) => AnimatedContainer(
                        duration: themeAnimationDuration,
                        child: IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                          color: isDark ? textColor : Colors.black87,
                        ),
                      ),
                    )),
        ),
      );
    },
  );
}

@override
Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

//[-------------HOJA INFERIOR DE NOTIFICACIONES--------------]
class NotificationsBottomSheet extends StatelessWidget {
const NotificationsBottomSheet({super.key});

@override
Widget build(BuildContext context) {
  return Consumer<ThemeProvider>(
    builder: (context, themeProvider, child) {
      final bool isDark = themeProvider.isDark;
      const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
      const double borderRadius = 12.0;

      return AnimatedContainer(
        duration: themeAnimationDuration,
        decoration: BoxDecoration(
          color: isDark ? cardColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(borderRadius)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedDefaultTextStyle(
              duration: themeAnimationDuration,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? textColor : Colors.black87,
              ),
              child: const Text('Notificaciones'),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return NotificationTile(
                  icon: index == 0
                      ? Icons.event_available
                      : index == 1
                          ? Icons.person_add
                          : Icons.schedule,
                  title: index == 0
                      ? 'Próxima cita en 30 minutos'
                      : index == 1
                          ? 'Nuevo cliente registrado'
                          : 'Recordatorio',
                  subtitle: index == 0
                      ? 'Ana López - 2:30 PM'
                      : index == 1
                          ? 'Carlos Mendoza'
                          : 'Revisar citas de mañana',
                  time: index == 0
                      ? '2:00 PM'
                      : index == 1
                          ? '1:45 PM'
                          : '12:00 PM',
                  isDark: isDark,
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
}

//[-------------ELEMENTO DE NOTIFICACIÓN--------------]
class NotificationTile extends StatelessWidget {
final IconData icon;
final String title;
final String subtitle;
final String time;
final bool isDark;

const NotificationTile({
  super.key,
  required this.icon,
  required this.title,
  required this.subtitle,
  required this.time,
  required this.isDark,
});

@override
Widget build(BuildContext context) {
  const Color hintColor = Colors.white70;

  return AnimatedContainer(
    duration: themeAnimationDuration,
    child: ListTile(
      leading: AnimatedContainer(
        duration: themeAnimationDuration,
        child: CircleAvatar(
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          child: Icon(icon, color: primaryColor),
        ),
      ),
      title: AnimatedDefaultTextStyle(
        duration: themeAnimationDuration,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? textColor : Colors.black87,
        ),
        child: Text(title),
      ),
      subtitle: AnimatedDefaultTextStyle(
        duration: themeAnimationDuration,
        style: TextStyle(
          color: isDark ? hintColor : Colors.grey[600],
        ),
        child: Text(subtitle),
      ),
      trailing: AnimatedDefaultTextStyle(
        duration: themeAnimationDuration,
        style: TextStyle(
          color: isDark ? hintColor : Colors.grey[600],
          fontSize: 12,
        ),
        child: Text(time),
      ),
    ),
  );
}
}