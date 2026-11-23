import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../domain/app_notification.dart';
import 'notifications_scope.dart';
import 'notifications_view_model.dart';

/// Centro de notificaciones en estilo Liquid Glass.
///
/// Usa [NotificationsScope] por defecto y permite inyectar [viewModel] en
/// pruebas sin tocar el contrato de estado ni el router.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.viewModel});

  /// Inyectable en pruebas; por defecto se toma del scope global.
  final NotificationsViewModel? viewModel;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationsViewModel? _viewModel;
  bool _ownsViewModel = false;
  bool _didTriggerInitialLoad = false;
  bool _showingMutationError = false;
  final Set<String> _pendingDismissIds = <String>{};

  @override
  void initState() {
    super.initState();
    final injected = widget.viewModel;
    if (injected != null) {
      _attachViewModel(injected);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel == null) {
      final scope = NotificationsScope.maybeOf(context);
      if (scope != null) {
        _attachViewModel(scope);
      } else {
        _ownsViewModel = true;
        _attachViewModel(NotificationsViewModel());
      }
    }
    final viewModel = _viewModel;
    if (viewModel != null &&
        !_didTriggerInitialLoad &&
        (!viewModel.hasLoaded || viewModel.sessionExpired)) {
      _didTriggerInitialLoad = true;
      scheduleMicrotask(() {
        if (!mounted) return;
        if (viewModel.sessionExpired) {
          viewModel.clearOnLogout();
        }
        unawaited(viewModel.load());
      });
    }
    _handleViewModelChanged();
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_handleViewModelChanged);
    if (_ownsViewModel) _viewModel?.dispose();
    super.dispose();
  }

  void _attachViewModel(NotificationsViewModel viewModel) {
    if (identical(_viewModel, viewModel)) return;
    _viewModel?.removeListener(_handleViewModelChanged);
    _viewModel = viewModel;
    viewModel.addListener(_handleViewModelChanged);
  }

  void _handleViewModelChanged() {
    final viewModel = _viewModel;
    if (viewModel == null || !mounted) return;
    final error = viewModel.mutationError;
    if (error == null || _showingMutationError) return;
    _showingMutationError = true;
    scheduleMicrotask(() {
      if (!mounted) return;
      viewModel.clearMutationError();
      _showingMutationError = false;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.bgMid,
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  /// Permite desmontar el [Dismissible] en el frame actual aunque el API falle
  /// de inmediato y restaure la notificación en el mismo microtask.
  void _onDismissNotification(String id) {
    final viewModel = _viewModel;
    if (viewModel == null) return;
    setState(() => _pendingDismissIds.add(id));
    unawaited(viewModel.deleteNotification(id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pendingDismissIds.remove(id)) {
        setState(() {});
      }
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return const SizedBox.shrink();
    }
    return AppScaffoldTemplate(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onBack: _goBack),
                  _FilterControls(viewModel: viewModel),
                  Expanded(
                    child: _NotificationList(
                      viewModel: viewModel,
                      pendingDismissIds: _pendingDismissIds,
                      onDismissNotification: _onDismissNotification,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.glassFillSoft,
              side: const BorderSide(color: AppColors.glassBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.option),
              ),
            ),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Notificaciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.pageTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterControls extends StatelessWidget {
  const _FilterControls({required this.viewModel});

  final NotificationsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: GlassSurface(
        padding: const EdgeInsets.all(14),
        radius: AppRadii.inner,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final filter in NotificationsReadFilter.values) ...[
                  Expanded(
                    child: _ReadFilterPill(
                      label: _readFilterLabel(filter),
                      selected: viewModel.readFilter == filter,
                      badgeCount: filter == NotificationsReadFilter.unread
                          ? viewModel.unreadCount
                          : 0,
                      onTap: () => viewModel.setReadFilter(filter),
                    ),
                  ),
                  if (filter != NotificationsReadFilter.values.last)
                    const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ActionPillButton(
                  icon: Icons.done_all_rounded,
                  label: 'Marcar todas como leídas',
                  onPressed: viewModel.hasUnread
                      ? viewModel.markAllAsRead
                      : null,
                ),
                _ActionPillButton(
                  key: const Key('notifications-delete-all'),
                  icon: Icons.delete_sweep_outlined,
                  label: 'Eliminar todas',
                  destructive: true,
                  onPressed: viewModel.isEmpty ? null : viewModel.deleteAll,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _readFilterLabel(NotificationsReadFilter filter) {
    return switch (filter) {
      NotificationsReadFilter.all => 'Todas',
      NotificationsReadFilter.unread => 'No leídas',
      NotificationsReadFilter.read => 'Leídas',
    };
  }
}

class _ReadFilterPill extends StatelessWidget {
  const _ReadFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.option),
              color: selected ? AppColors.accentWhite : AppColors.glassFillSoft,
              border: Border.all(
                color: selected ? AppColors.accentWhite : AppColors.glassBorder,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textOnAccent
                          : AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        color: selected
                            ? AppColors.textOnAccent.withValues(alpha: 0.14)
                            : AppColors.glassFillStrong,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          color: selected
                              ? AppColors.textOnAccent
                              : AppColors.accentWhite,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = destructive
        ? AppColors.dangerText
        : AppColors.textPrimary;
    final background = destructive
        ? AppColors.dangerFill
        : AppColors.glassFillSoft;
    final border = destructive ? AppColors.dangerBorder : AppColors.glassBorder;

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              color: background,
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.viewModel,
    required this.pendingDismissIds,
    required this.onDismissNotification,
  });

  final NotificationsViewModel viewModel;
  final Set<String> pendingDismissIds;
  final ValueChanged<String> onDismissNotification;

  @override
  Widget build(BuildContext context) {
    if (viewModel.notifications.isEmpty &&
        (viewModel.state is AsyncLoading<List<AppNotification>> ||
            !viewModel.hasLoaded)) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentWhite),
      );
    }

    if (viewModel.state is AsyncError<List<AppNotification>> &&
        viewModel.notifications.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar tus notificaciones',
        message: 'Verifica tu conexión e intenta nuevamente.',
        actionLabel: 'Reintentar',
        onAction: viewModel.load,
      );
    }

    if (viewModel.isEmpty) {
      return const _EmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'Sin notificaciones',
        message:
            'Aquí aparecerán tus avisos de inicio de sesión, cambios de '
            'contraseña y recordatorios.',
      );
    }

    final notifications = viewModel.filteredNotifications;
    if (notifications.isEmpty) {
      return _EmptyState(
        icon: Icons.filter_list_off_rounded,
        title: 'Sin resultados con este filtro',
        message: 'Prueba con otro estado de lectura o limpia los filtros.',
        actionLabel: 'Limpiar filtros',
        onAction: viewModel.clearFilters,
      );
    }

    final visibleNotifications = pendingDismissIds.isEmpty
        ? notifications
        : notifications
              .where(
                (notification) => !pendingDismissIds.contains(notification.id),
              )
              .toList(growable: false);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: visibleNotifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final notification = visibleNotifications[index];
        return Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.dangerFill, AppColors.dangerSolidMid],
              ),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.dangerBorder),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Eliminar',
                  style: TextStyle(
                    color: AppColors.accentWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.accentWhite,
                  size: 22,
                ),
              ],
            ),
          ),
          onDismissed: (_) => onDismissNotification(notification.id),
          child: _NotificationCard(
            notification: notification,
            onToggleRead: () => viewModel.toggleRead(notification.id),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onToggleRead,
  });

  final AppNotification notification;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final iconColor = unread
        ? (notification.type == AppNotificationType.newLogin
              ? AppColors.warningText
              : AppColors.accentWhite)
        : AppColors.textMuted;
    final iconBg = unread
        ? (notification.type == AppNotificationType.newLogin
              ? AppColors.warningFill
              : AppColors.glassFillStrong)
        : AppColors.controlFillIdle;
    final iconBorder = unread
        ? (notification.type == AppNotificationType.newLogin
              ? AppColors.warningBorder
              : AppColors.glassBorderStrong)
        : AppColors.glassBorder;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: unread ? 1.0 : 0.78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: unread ? AppColors.glassBorderStrong : Colors.transparent,
          ),
        ),
        child: GlassSurface(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onToggleRead,
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(AppRadii.option),
                        border: Border.all(color: iconBorder),
                      ),
                      child: Icon(
                        _iconForType(notification.type),
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (unread) ...[
                                Container(
                                  key: Key(
                                    'notification-unread-dot-${notification.id}',
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentWhite,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xCCFFFFFF),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    color: unread
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: notification.isRead
                                    ? 'Marcar como no leída'
                                    : 'Marcar como leída',
                                onPressed: onToggleRead,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  notification.isRead
                                      ? Icons.mark_email_unread_outlined
                                      : Icons.mark_email_read_outlined,
                                  size: 18,
                                  color: unread
                                      ? AppColors.accentWhite
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: TextStyle(
                              color: unread
                                  ? AppColors.zinc200
                                  : AppColors.textSecondary,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _MetaPill(
                                label: notification.type.label,
                                highlighted: false,
                              ),
                              _MetaPill(
                                label: unread ? 'Sin leer' : 'Leída',
                                highlighted: unread,
                              ),
                              Text(
                                _relativeTime(notification.createdAt),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.badge),
        color: highlighted
            ? AppColors.glassFillStrong
            : AppColors.controlFillIdle,
        border: Border.all(
          color: highlighted
              ? AppColors.glassBorderStrong
              : AppColors.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? AppColors.accentWhite : AppColors.textMuted,
          fontSize: 11,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: GlassSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassFillSoft,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(icon, color: AppColors.textSecondary, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                _ActionPillButton(
                  icon: Icons.refresh_rounded,
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForType(AppNotificationType type) {
  return switch (type) {
    AppNotificationType.newLogin => Icons.login_rounded,
    AppNotificationType.passwordChanged => Icons.lock_reset_rounded,
    AppNotificationType.reminder => Icons.notifications_active_outlined,
  };
}

String _relativeTime(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Ahora';
  if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
  if (difference.inDays < 7) return 'Hace ${difference.inDays} d';
  return '${date.day}/${date.month}/${date.year}';
}
