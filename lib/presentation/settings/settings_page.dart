import 'package:flutter/material.dart';
import '../../core/theme/theme_mode_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: AnimatedBuilder(
        animation: ThemeModeController.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _buildSectionHeader('Giao diện', theme),
              Card(
                child: Column(
                  children: [
                    _buildThemeOptionTile('Sáng', ThemeMode.light, context),
                    _buildThemeOptionTile('Tối', ThemeMode.dark, context),
                    _buildThemeOptionTile(
                      'Hệ thống',
                      ThemeMode.system,
                      context,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionHeader('Tài khoản', theme),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Chỉnh sửa hồ sơ'),
                      subtitle: const Text(
                        'Thay đổi tên, ảnh đại diện của bạn',
                      ),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Đổi mật khẩu'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionHeader('Thông tin', theme),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Trợ giúp & Phản hồi'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Về Kanion Chat'),
                      subtitle: const Text('Phiên bản 1.0.0'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildThemeOptionTile(
    String title,
    ThemeMode value,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final currentMode = ThemeModeController.instance.themeMode;
    final isSelected = currentMode == value;

    return ListTile(
      title: Text(title),
      onTap: () => ThemeModeController.instance.setThemeMode(value),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
    );
  }
}
