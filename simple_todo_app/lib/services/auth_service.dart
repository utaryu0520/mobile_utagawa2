import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../database_factory.dart';

const String _kUsersDbName = 'users.db';
const String _kCurrentUserKey = 'current_user';

final StoreRef<int, Map<String, dynamic>> _userStore = intMapStoreFactory.store(
  'users',
);

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  late Database _db;
  User? _currentUser;

  Future<void> initialize() async {
    _db = await getDatabaseFactory().openDatabase(_kUsersDbName, version: 1);

    // SharedPreferencesから前回ログインしたユーザーを復元
    await _restoreCurrentUser();
  }

  Future<void> _restoreCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_kCurrentUserKey);

    if (userData != null) {
      try {
        final map = jsonDecode(userData) as Map<String, dynamic>;
        _currentUser = User.fromMap(map);
      } catch (e) {
        print('Failed to restore current user: $e');
      }
    }
  }

  Future<void> _saveCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUserKey, jsonEncode(user.toMap()));
  }

  Future<void> _clearCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUserKey);
  }

  // ユーザーが登録済みかチェック
  Future<bool> usernameExists(String username) async {
    final records = await _userStore.find(
      _db,
      finder: Finder(
        filter: Filter.custom((record) {
          return record['username'] == username;
        }),
      ),
    );
    return records.isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final records = await _userStore.find(
      _db,
      finder: Finder(
        filter: Filter.custom((record) {
          return record['email'] == email;
        }),
      ),
    );
    return records.isNotEmpty;
  }

  // パスワードハッシュ化
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ユーザー登録
  Future<({bool success, String message, User? user})> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String? displayName,
  }) async {
    // バリデーション
    if (username.isEmpty || username.length < 3) {
      return (success: false, message: 'ユーザー名は3文字以上である必要があります', user: null);
    }

    if (!_isValidEmail(email)) {
      return (success: false, message: 'メールアドレスが無効です', user: null);
    }

    if (password.isEmpty || password.length < 6) {
      return (success: false, message: 'パスワードは6文字以上である必要があります', user: null);
    }

    if (password != confirmPassword) {
      return (success: false, message: 'パスワードが一致しません', user: null);
    }

    // ユーザー名とメール重複チェック
    if (await usernameExists(username)) {
      return (success: false, message: 'このユーザー名は既に使用されています', user: null);
    }

    if (await emailExists(email)) {
      return (success: false, message: 'このメールアドレスは既に使用されています', user: null);
    }

    try {
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: username,
        email: email,
        passwordHash: _hashPassword(password),
        createdAt: DateTime.now(),
        displayName: displayName ?? username,
      );

      await _userStore.add(_db, user.toMap());
      await _saveCurrentUser(user);
      _currentUser = user;

      return (success: true, message: '登録成功', user: user);
    } catch (e) {
      return (success: false, message: 'エラーが発生しました: $e', user: null);
    }
  }

  // ログイン
  Future<({bool success, String message, User? user})> login({
    required String email,
    required String password,
  }) async {
    try {
      final passwordHash = _hashPassword(password);
      final records = await _userStore.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            return record['email'] == email &&
                record['passwordHash'] == passwordHash;
          }),
        ),
      );

      if (records.isEmpty) {
        return (
          success: false,
          message: 'メールアドレスまたはパスワードが正しくありません',
          user: null,
        );
      }

      final user = User.fromMap(records.first.value);
      await _saveCurrentUser(user);
      _currentUser = user;

      return (success: true, message: 'ログイン成功', user: user);
    } catch (e) {
      return (success: false, message: 'エラーが発生しました: $e', user: null);
    }
  }

  // ログアウト
  Future<void> logout() async {
    await _clearCurrentUser();
    _currentUser = null;
  }

  // 現在ログイン中のユーザーを取得
  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // プロフィール更新
  Future<({bool success, String message, User? user})> updateProfile({
    required String displayName,
    String? avatar,
  }) async {
    if (_currentUser == null) {
      return (success: false, message: 'ログインしていません', user: null);
    }

    try {
      final updatedUser = _currentUser!.copyWith(
        displayName: displayName,
        avatar: avatar,
      );

      final records = await _userStore.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            return record['id'] == _currentUser!.id;
          }),
        ),
      );

      if (records.isNotEmpty) {
        await _userStore
            .record(records.first.key)
            .update(_db, updatedUser.toMap());
      }

      await _saveCurrentUser(updatedUser);
      _currentUser = updatedUser;

      return (success: true, message: 'プロフィール更新成功', user: updatedUser);
    } catch (e) {
      return (success: false, message: 'エラーが発生しました: $e', user: null);
    }
  }

  // パスワード変更
  Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (_currentUser == null) {
      return (success: false, message: 'ログインしていません');
    }

    if (_hashPassword(currentPassword) != _currentUser!.passwordHash) {
      return (success: false, message: '現在のパスワードが正しくありません');
    }

    if (newPassword.isEmpty || newPassword.length < 6) {
      return (success: false, message: 'パスワードは6文字以上である必要があります');
    }

    if (newPassword != confirmPassword) {
      return (success: false, message: 'パスワードが一致しません');
    }

    try {
      final updatedUser = _currentUser!.copyWith(
        passwordHash: _hashPassword(newPassword),
      );

      final records = await _userStore.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            return record['id'] == _currentUser!.id;
          }),
        ),
      );

      if (records.isNotEmpty) {
        await _userStore
            .record(records.first.key)
            .update(_db, updatedUser.toMap());
      }

      await _saveCurrentUser(updatedUser);
      _currentUser = updatedUser;

      return (success: true, message: 'パスワード変更成功');
    } catch (e) {
      return (success: false, message: 'エラーが発生しました: $e');
    }
  }

  // メールアドレスのバリデーション
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}
