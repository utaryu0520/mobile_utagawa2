import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_factory.dart';
import 'services/auth_service.dart';
import 'screens/profile_screen.dart';

const String _kDbName = 'todos.db';

final StoreRef<int, Map<String, dynamic>> _todoStore = intMapStoreFactory.store(
  'todos',
);

class TodoItem {
  final int key;
  final String text;
  final DateTime? dueDate;
  final String category;

  TodoItem({
    required this.key,
    required this.text,
    this.dueDate,
    required this.category,
  });
}

enum SortType { newest, oldest, alphabetical, dueDate }

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final TextEditingController _controller = TextEditingController();
  final _authService = AuthService();

  late Database _db;

  List<TodoItem> _todos = [];

  bool _isLoading = true;

  SortType _sortType = SortType.newest;

  DateTime? _selectedDateTime;

  final List<String> _categories = ['未設定', '仕事', '家事', 'プライベート', 'その他'];

  String _selectedCategory = '未設定';
  String _filterCategory = 'すべて';

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    _db = await getDatabaseFactory().openDatabase(
      _kDbName,
      version: 1,
      onVersionChanged: (db, oldVersion, newVersion) async {
        print('DB version changed from $oldVersion to $newVersion');
      },
    );

    await _loadTodos();

    if (_todos.isEmpty) {
      final restored = await _restoreFromSharedPreferences();

      if (!restored) {
        await _addSampleData();
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _sortTodos() {
    setState(() {
      switch (_sortType) {
        case SortType.newest:
          _todos.sort((a, b) => b.key.compareTo(a.key));
          break;

        case SortType.oldest:
          _todos.sort((a, b) => a.key.compareTo(b.key));
          break;

        case SortType.alphabetical:
          _todos.sort((a, b) => a.text.compareTo(b.text));
          break;

        case SortType.dueDate:
          _todos.sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) {
              return 0;
            }

            if (a.dueDate == null) {
              return 1;
            }

            if (b.dueDate == null) {
              return -1;
            }

            return a.dueDate!.compareTo(b.dueDate!);
          });
          break;
      }
    });
  }

  Future<void> _backupToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final data = _todos
        .map(
          (todo) => {
            'key': todo.key,
            'text': todo.text,
            'dueDate': todo.dueDate?.toIso8601String(),
            'category': todo.category,
          },
        )
        .toList();

    await prefs.setString('todos_backup', jsonEncode(data));

    print('Backed up ${data.length} todos to SharedPreferences');
  }

  Future<void> _loadTodos() async {
    final records = await _todoStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder(Field.key)]),
    );

    print('Loaded ${records.length} todos from DB');

    _todos = records
        .map(
          (snapshot) => TodoItem(
            key: snapshot.key,
            text: snapshot.value['text'] as String,
            dueDate: snapshot.value['dueDate'] != null
                ? DateTime.parse(snapshot.value['dueDate'] as String)
                : null,
            category: snapshot.value['category'] as String? ?? '未設定',
          ),
        )
        .toList();

    _sortTodos();
  }

  Future<bool> _restoreFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final backup = prefs.getString('todos_backup');

    if (backup != null && backup.isNotEmpty) {
      final data = jsonDecode(backup) as List;

      for (final item in data) {
        final key = await _todoStore.add(_db, {
          'text': item['text'],
          'dueDate': item['dueDate'],
          'category': item['category'] ?? '未設定',
        });

        _todos.add(
          TodoItem(
            key: key,
            text: item['text'],
            dueDate: item['dueDate'] != null
                ? DateTime.parse(item['dueDate'])
                : null,
            category: item['category'] ?? '未設定',
          ),
        );
      }

      print('Restored ${data.length} todos from SharedPreferences');

      _sortTodos();

      return data.isNotEmpty;
    }

    return false;
  }

  Future<void> _addSampleData() async {
    final sampleTodos = ['サンプルToDo 1', 'サンプルToDo 2', 'サンプルToDo 3'];

    for (final text in sampleTodos) {
      final key = await _todoStore.add(_db, {
        'text': text,
        'dueDate': null,
        'category': '未設定',
      });

      _todos.add(
        TodoItem(key: key, text: text, dueDate: null, category: '未設定'),
      );
    }

    _sortTodos();

    print('Added ${sampleTodos.length} sample todos');

    await _backupToSharedPreferences();
  }

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) {
      return;
    }

    final dateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _selectedDateTime = dateTime;
    });
  }

  Future<void> _addTodo() async {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    final key = await _todoStore.add(_db, {
      'text': text,
      'dueDate': _selectedDateTime?.toIso8601String(),
      'category': _selectedCategory,
    });

    print('Added todo with key $key: $text');

    setState(() {
      _todos.add(
        TodoItem(
          key: key,
          text: text,
          dueDate: _selectedDateTime,
          category: _selectedCategory,
        ),
      );

      _controller.clear();

      _selectedDateTime = null;

      _selectedCategory = '未設定';
    });

    _sortTodos();

    await _backupToSharedPreferences();
  }

  Future<void> _removeTodo(int index) async {
    final todo = _todos[index];

    await _todoStore.record(todo.key).delete(_db);

    print('Removed todo with key ${todo.key}: ${todo.text}');

    setState(() {
      _todos.removeAt(index);
    });

    await _backupToSharedPreferences();
  }

  String _getSortLabel() {
    switch (_sortType) {
      case SortType.newest:
        return '新しい順';

      case SortType.oldest:
        return '古い順';

      case SortType.alphabetical:
        return '名前順';

      case SortType.dueDate:
        return '期限順';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '期限なし';
    }

    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$year/$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final filteredTodos = _filterCategory == 'すべて'
        ? _todos
        : _todos.where((todo) => todo.category == _filterCategory).toList();
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'こんにちは、${_authService.currentUser?.displayName ?? 'ゲスト'}さん',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          Row(
            children: [
              Text(
                _getSortLabel(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              PopupMenuButton<SortType>(
                icon: const Icon(Icons.sort),
                onSelected: (value) {
                  setState(() {
                    _sortType = value;
                  });
                  _sortTodos();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: SortType.newest, child: Text('新しい順')),
                  PopupMenuItem(value: SortType.oldest, child: Text('古い順')),
                  PopupMenuItem(
                    value: SortType.alphabetical,
                    child: Text('名前順'),
                  ),
                  PopupMenuItem(value: SortType.dueDate, child: Text('期限順')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),

            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,

                        decoration: const InputDecoration(
                          hintText: '新しいToDoを入力',
                        ),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addTodo,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,

                        decoration: const InputDecoration(
                          labelText: 'カテゴリ設定',
                          border: OutlineInputBorder(),
                        ),

                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),

                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    Transform.translate(
                      offset: const Offset(0, -4),
                      child: SizedBox(
                        width: 160,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _selectDateTime,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            _selectedDateTime == null
                                ? '日時設定'
                                : _formatDate(_selectedDateTime),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                const SizedBox(height: 20),

                Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: _filterCategory,

                        decoration: const InputDecoration(
                          labelText: 'カテゴリでフィルタ',
                          border: OutlineInputBorder(),
                        ),

                        items: [
                          const DropdownMenuItem(
                            value: 'すべて',
                            child: Text('すべて'),
                          ),

                          ..._categories.map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],

                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _filterCategory = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),

          Expanded(
            child: _todos.isEmpty
                ? const Center(child: Text('データがありません'))
                : ListView.separated(
                    itemCount: filteredTodos.length,

                    separatorBuilder: (context, index) {
                      return const Divider(
                        color: Colors.black12,
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      );
                    },

                    itemBuilder: (context, index) {
                      final todo = filteredTodos[index];

                      return ListTile(
                        title: Text(todo.text),

                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('カテゴリ: ${todo.category}'),

                            Text('期限: ${_formatDate(todo.dueDate)}'),
                          ],
                        ),

                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final originalIndex = _todos.indexWhere(
                              (item) => item.key == todo.key,
                            );

                            if (originalIndex != -1) {
                              await _removeTodo(originalIndex);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
