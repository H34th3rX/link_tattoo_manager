import 'package:flutter/material.dart';
import 'appointment_reminder_generator.dart';

//[-------------DIÁLOGO DE GENERACIÓN DE RECORDATORIOS--------------]
class ReminderGeneratorDialog extends StatefulWidget {
  final String clientName;
  final DateTime appointmentTime;
  final String serviceName;
  final double price;
  final double depositPaid;
  final String status; // ← NUEVO: 'confirmada' o 'aplazada'
  final String? notes;
  final bool isDark;

  const ReminderGeneratorDialog({
    super.key,
    required this.clientName,
    required this.appointmentTime,
    required this.serviceName,
    required this.price,
    required this.depositPaid,
    required this.status,
    this.notes,
    required this.isDark,
  });

  @override
  State<ReminderGeneratorDialog> createState() => _ReminderGeneratorDialogState();
}

class _ReminderGeneratorDialogState extends State<ReminderGeneratorDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  GenerationState _state = GenerationState.generating;

  String? _error;
  
  // Colores de la app
  static const Color primaryColor = Color(0xFFBDA206);
  static const Color textColor = Colors.white;
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFCF6679);
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    
    _generateReminder();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _generateReminder() async {
    try {
      setState(() {
        _state = GenerationState.generating;
      });
      
      // Simular un pequeño delay para la animación
      await Future.delayed(const Duration(milliseconds: 500));
      
      final file = await AppointmentReminderGenerator.generateReminder(
        clientName: widget.clientName,
        appointmentTime: widget.appointmentTime,
        serviceName: widget.serviceName,
        price: widget.price,
        depositPaid: widget.depositPaid,
        status: widget.status, // ← NUEVO: pasar el status
        notes: widget.notes,
      );
      
      if (mounted) {
        _controller.stop();
        setState(() {
          _state = GenerationState.success;
        });
        
        // Auto-cerrar y compartir después de 800ms
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pop();
          await AppointmentReminderGenerator.shareReminder(file);
        }
      }
    } catch (e) {
      if (mounted) {
        _controller.stop();
        setState(() {
          _state = GenerationState.error;
          _error = e.toString();
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimatedIcon(),
            const SizedBox(height: 24),
            _buildMessage(),
            if (_state == GenerationState.error) ...[
              const SizedBox(height: 16),
              _buildRetryButton(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnimatedIcon() {
    switch (_state) {
      case GenerationState.generating:
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.6),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
              ),
            );
          },
        );
      
      case GenerationState.success:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [successColor, Color(0xFF66BB6A)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            );
          },
        );
      
      case GenerationState.error:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [errorColor, Color(0xFFE57373)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            );
          },
        );
    }
  }
  
  Widget _buildMessage() {
    String title;
    String subtitle;
    
    switch (_state) {
      case GenerationState.generating:
        title = 'Generando Recordatorio';
        subtitle = 'Creando tu imagen personalizada...';
        break;
      case GenerationState.success:
        title = '¡Listo!';
        subtitle = 'Recordatorio generado exitosamente';
        break;
      case GenerationState.error:
        title = 'Error';
        subtitle = _error ?? 'No se pudo generar el recordatorio';
        break;
    }
    
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? textColor : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: widget.isDark ? textColor.withValues(alpha: 0.7) : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildRetryButton() {
    return ElevatedButton.icon(
      onPressed: () {
        _controller.repeat();
        _generateReminder();
      },
      icon: const Icon(Icons.refresh, color: Colors.black),
      label: const Text(
        'Reintentar',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

enum GenerationState {
  generating,
  success,
  error,
}