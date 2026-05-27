import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_factory.dart';

const String _kDbName = 'todos.db';

final StoreRef<int, Map<String, dynamic>> _todoStore =
    intMapStoreFactory.store('todos');

class TodoItem {
  final int key;
  final String text;

  TodoItem({
    required this.key,
    required this.text,
  });
}

enum SortType {
  newest,
  oldest,
  alphabetical,
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final TextEditingController _controller = TextEditingController();

  late Database _db;

  List<TodoItem> _todos = [];

  bool _isLoading = true;

  SortType _sortType = SortType.newest;

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
          },
        )
        .toList();

    await prefs.setString(
      'todos_backup',
      jsonEncode(data),
    );

    print('Backed up ${data.length} todos to SharedPreferences');
  }

  Future<void> _loadTodos() async {
    final records = await _todoStore.find(
      _db,
      finder: Finder(
        sortOrders: [SortOrder(Field.key)],
      ),
    );

    print('Loaded ${records.length} todos from DB');

    _todos = records
        .map(
          (snapshot) => TodoItem(
            key: snapshot.key,
            text: snapshot.value['text'] as String,
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
        final key = await _todoStore.add(
          _db,
          {'text': item['text']},
        );

        _todos.add(
          TodoItem(
            key: key,
            text: item['text'],
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
    final sampleTodos = [
      'サンプルToDo 1',
      'サンプルToDo 2',
      'サンプルToDo 3',
    ];

    for (final text in sampleTodos) {
      final key = await _todoStore.add(
        _db,
        {'text': text},
      );

      _todos.add(
        TodoItem(
          key: key,
          text: text,
        ),
      );
    }

    _sortTodos();

    print('Added ${sampleTodos.length} sample todos');

    await _backupToSharedPreferences();
  }

  Future<void> _addTodo() async {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    final key = await _todoStore.add(
      _db,
      {'text': text},
    );

    print('Added todo with key $key: $text');

    setState(() {
      _todos.add(
        TodoItem(
          key: key,
          text: text,
        ),
      );

      _controller.clear();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ToDo List'),
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
                  PopupMenuItem(
                    value: SortType.newest,
                    child: Text('新しい順'),
                  ),

                  PopupMenuItem(
                    value: SortType.oldest,
                    child: Text('古い順'),
                  ),

                  PopupMenuItem(
                    value: SortType.alphabetical,
                    child: Text('名前順'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),

            child: Row(
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
          ),

          Expanded(
            child: _todos.isEmpty
                ? const Center(
                    child: Text('データがありません'),
                  )
                : ListView.separated(
                    itemCount: _todos.length,

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
                      return ListTile(
                        title: Text(_todos[index].text),

                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeTodo(index),
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