import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../core/di/service_locator.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/profile/data/repositories/profile_repository.dart';
import '../../features/profile/data/models/user_profile.dart';
import '../auth/login_page.dart';
import '../home/home_page.dart';

class ProfilePage extends StatefulWidget {
  final bool isFirstTime;

  const ProfilePage({super.key, this.isFirstTime = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final AuthRepository _authRepo;
  late final ProfileRepository _profileRepo;
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  UserProfile? _profile;
  DateTime? _selectedBirthDay;
  bool _isLoading = true;
  bool _isEditing = false;
  Uint8List? _selectedAvatarBytes;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepositoryImpl(sl.supabase);
    _profileRepo = ProfileRepositoryImpl(sl.supabase);
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userId = _authRepo.currentUserId;
    if (userId != null) {
      final profile = await _profileRepo.getProfile(userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _displayNameController.text =
              profile?.displayName ??
              _authRepo.currentUser?.userMetadata?['display_name'] ??
              '';
          _phoneController.text = profile?.phone ?? '';
          _bioController.text = profile?.bio ?? '';
          _selectedBirthDay = profile?.birthDay;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _selectedAvatarBytes = bytes);
    }
  }

  Future<void> _saveChanges() async {
    if (!_isEditing) {
      if (widget.isFirstTime) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
      return;
    }

    if (_displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên hiển thị không được để trống')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authRepo.currentUserId!;
      String? avatarUrl = _profile?.avatarUrl;

      if (_selectedAvatarBytes != null) {
        avatarUrl = await _profileRepo.uploadAvatar(
          userId,
          'avatar.png',
          fileBytes: _selectedAvatarBytes,
        );
      }

      await _authRepo.updateDisplayName(_displayNameController.text.trim());

      final updatedProfile =
          (_profile ??
                  UserProfile(
                    id: userId,
                    userId: userId,
                    displayName: _displayNameController.text.trim(),
                    createdAt: DateTime.now(),
                  ))
              .copyWith(
                displayName: _displayNameController.text.trim(),
                birthDay: _selectedBirthDay,
                phone: _phoneController.text.trim().isEmpty
                    ? null
                    : _phoneController.text.trim(),
                bio: _bioController.text.trim().isEmpty
                    ? null
                    : _bioController.text.trim(),
                avatarUrl: avatarUrl,
              );

      await _profileRepo.updateProfile(updatedProfile);

      if (mounted) {
        setState(() {
          _profile = updatedProfile;
          _isEditing = false;
          _selectedAvatarBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hồ sơ được cập nhật thành công!')),
        );
        if (widget.isFirstTime) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authRepo.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstTime ? 'Hoàn thành hồ sơ' : 'Hồ sơ'),
        actions: widget.isFirstTime
            ? null
            : [IconButton(onPressed: _signOut, icon: const Icon(Icons.logout))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildAvatarSection(theme),
                const SizedBox(height: 24),
                _isEditing
                    ? _buildProfileForm(theme)
                    : _buildReadOnlyInfo(theme),
                const SizedBox(height: 28),
                _buildSaveButton(theme),
              ],
            ),
    );
  }

  Widget _buildAvatarSection(ThemeData theme) {
    final displayName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : (_authRepo.currentUser?.email?.split('@')[0] ?? '?');
    final avatarUrl = _profile?.avatarUrl;

    return Column(
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _isEditing = true), // Allow editing on tap
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 58,
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                backgroundImage: _selectedAvatarBytes != null
                    ? MemoryImage(_selectedAvatarBytes!)
                    : (avatarUrl != null ? NetworkImage(avatarUrl) : null)
                          as ImageProvider?,
                child: _selectedAvatarBytes == null && avatarUrl == null
                    ? Text(
                        displayName[0].toUpperCase(),
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      )
                    : null,
              ),
              if (_isEditing)
                GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!_isEditing)
          Text(
            displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        Text(
          _authRepo.currentUser?.email ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tên hiển thị', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _displayNameController,
              readOnly: !_isEditing,
              decoration: InputDecoration(
                hintText: 'Nhập tên hiển thị của bạn',
                suffixIcon: IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Ngày sinh', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isEditing ? _pickBirthDay : null,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: 'Chọn ngày sinh',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: _selectedBirthDay != null
                      ? IconButton(
                          onPressed: !_isEditing
                              ? null
                              : () => setState(() => _selectedBirthDay = null),
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                ),
                child: Text(
                  _selectedBirthDay == null
                      ? 'Chọn ngày sinh'
                      : _formatDate(_selectedBirthDay!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _selectedBirthDay == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Số điện thoại', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              readOnly: !_isEditing,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Nhập số điện thoại',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tiểu sử', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              readOnly: !_isEditing,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Giới thiệu ngắn về bạn',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyInfo(ThemeData theme) {
    final birthDayText = _selectedBirthDay != null
        ? _formatDate(_selectedBirthDay!)
        : 'Chưa cập nhật';
    final phoneText = _phoneController.text.trim().isEmpty
        ? 'Chưa cập nhật'
        : _phoneController.text.trim();
    final bioText = _bioController.text.trim().isEmpty
        ? 'Chưa cập nhật'
        : _bioController.text.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _readOnlyRow(
              theme,
              icon: Icons.cake_outlined,
              label: 'Ngày sinh',
              value: birthDayText,
            ),
            const SizedBox(height: 12),
            _readOnlyRow(
              theme,
              icon: Icons.phone_outlined,
              label: 'Số điện thoại',
              value: phoneText,
            ),
            const SizedBox(height: 12),
            _readOnlyRow(
              theme,
              icon: Icons.info_outline,
              label: 'Tiểu sử',
              value: bioText,
              multiline: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    bool multiline = false,
  }) {
    return Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
                maxLines: multiline ? 3 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickBirthDay() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthDay ?? DateTime(now.year - 18, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );

    if (picked != null && mounted) {
      setState(() => _selectedBirthDay = picked);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Widget _buildSaveButton(ThemeData theme) {
    final isViewMode = !_isEditing && !widget.isFirstTime;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : isViewMode
            ? () => setState(() => _isEditing = true)
            : _saveChanges,
        child: Text(
          isViewMode
              ? 'Chỉnh sửa thông tin'
              : (widget.isFirstTime ? 'Tiếp tục' : 'Lưu thay đổi'),
        ),
      ),
    );
  }
}
