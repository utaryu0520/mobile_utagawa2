import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _displayNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoadingProfile = false;
  bool _isLoadingPassword = false;
  String _profileMessage = '';
  String _passwordMessage = '';
  bool _isEditingProfile = false;
  bool _isEditingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName ?? user.username;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileMessage = '';
    });

    final result = await _authService.updateProfile(
      displayName: _displayNameController.text.trim(),
    );

    setState(() {
      _isLoadingProfile = false;
      _profileMessage = result.message;
      if (result.success) {
        _isEditingProfile = false;
      }
    });
  }

  Future<void> _changePassword() async {
    setState(() {
      _isLoadingPassword = true;
      _passwordMessage = '';
    });

    final result = await _authService.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    setState(() {
      _isLoadingPassword = false;
      _passwordMessage = result.message;
      if (result.success) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _isEditingPassword = false;
      }
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしてもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('プロフィール')),
        body: const Center(child: Text('ログインしていません')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ユーザー情報セクション
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ユーザー情報',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('ユーザー名: ${user.username}'),
                    const SizedBox(height: 8),
                    Text('メール: ${user.email}'),
                    const SizedBox(height: 8),
                    Text('登録日: ${user.createdAt.toString().split('.')[0]}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // プロフィール編集セクション
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '表示名',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_isEditingProfile)
                          TextButton(
                            onPressed: () =>
                                setState(() => _isEditingProfile = true),
                            child: const Text('編集'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_isEditingProfile)
                      Text(
                        user.displayName ?? user.username,
                        style: const TextStyle(fontSize: 16),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: '表示名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_profileMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _profileMessage.contains('成功')
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  border: Border.all(
                                    color: _profileMessage.contains('成功')
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _profileMessage,
                                  style: TextStyle(
                                    color: _profileMessage.contains('成功')
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoadingProfile
                                      ? null
                                      : _updateProfile,
                                  child: _isLoadingProfile
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('保存'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoadingProfile
                                      ? null
                                      : () {
                                          setState(
                                            () => _isEditingProfile = false,
                                          );
                                          _profileMessage = '';
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                  ),
                                  child: const Text('キャンセル'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // パスワード変更セクション
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'セキュリティ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_isEditingPassword)
                          TextButton(
                            onPressed: () =>
                                setState(() => _isEditingPassword = true),
                            child: const Text('パスワード変更'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isEditingPassword)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _currentPasswordController,
                            decoration: const InputDecoration(
                              labelText: '現在のパスワード',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPasswordController,
                            decoration: const InputDecoration(
                              labelText: '新しいパスワード',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'パスワード確認',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          if (_passwordMessage.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _passwordMessage.contains('成功')
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                border: Border.all(
                                  color: _passwordMessage.contains('成功')
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _passwordMessage,
                                style: TextStyle(
                                  color: _passwordMessage.contains('成功')
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoadingPassword
                                      ? null
                                      : _changePassword,
                                  child: _isLoadingPassword
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('変更'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoadingPassword
                                      ? null
                                      : () {
                                          setState(
                                            () => _isEditingPassword = false,
                                          );
                                          _currentPasswordController.clear();
                                          _newPasswordController.clear();
                                          _confirmPasswordController.clear();
                                          _passwordMessage = '';
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                  ),
                                  child: const Text('キャンセル'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ログアウトボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'ログアウト',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
