import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String storageKey = 'writers_haven_saved_data';

void main() {
  runApp(const WritersHavenApp());
}

// Each available theme has a name and a color.
class HavenTheme {
  final String name;
  final Color color;
  final Brightness brightness;

  const HavenTheme(this.name, this.color, this.brightness);
}

const List<HavenTheme> havenThemes = [
  HavenTheme('Royal Purple', Color(0xFF7045A5), Brightness.light),
  HavenTheme('Emerald Garden', Color(0xFF16866A), Brightness.light),
  HavenTheme('Midnight Blue', Color(0xFF243B64), Brightness.light),
  HavenTheme('Rose Blush', Color(0xFFCE718D), Brightness.light),
  HavenTheme('Autumn Pages', Color(0xFFAD6334), Brightness.light),
  HavenTheme('Pure Black', Color(0xFF151515), Brightness.dark),
  HavenTheme('Clean White', Color(0xFF777777), Brightness.light),
];

// A chapter stores its title and written content.
class Chapter {
  final int id;
  String title;
  String content;

  Chapter({
    required this.id,
    required this.title,
    this.content = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
    };
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Chapter',
      content: json['content'] as String? ?? '',
    );
  }
}

// A book stores its details and all its chapters.
class Book {
  final int id;
  String title;
  String description;
  List<Chapter> chapters;

  Book({
    required this.id,
    required this.title,
    this.description = '',
    List<Chapter>? chapters,
  }) : chapters = chapters ?? [];

  int get totalWords {
    return chapters.fold(
      0,
      (total, chapter) => total + countWords(chapter.content),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    final savedChapters = json['chapters'] as List<dynamic>? ?? [];

    return Book(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Book',
      description: json['description'] as String? ?? '',
      chapters: savedChapters
          .map(
            (chapter) => Chapter.fromJson(
              Map<String, dynamic>.from(chapter as Map),
            ),
          )
          .toList(),
    );
  }
}

// Counts words in a piece of text.
int countWords(String text) {
  final trimmed = text.trim();

  if (trimmed.isEmpty) {
    return 0;
  }

  return trimmed.split(RegExp(r'\s+')).length;
}

class WritersHavenApp extends StatefulWidget {
  const WritersHavenApp({super.key});

  @override
  State<WritersHavenApp> createState() => _WritersHavenAppState();
}

class _WritersHavenAppState extends State<WritersHavenApp> {
  int selectedTab = 0;
  int selectedTheme = 0;
  int nextBookId = 1;
  int nextChapterId = 1;

  List<Book> books = [];
  bool isLoading = true;
  bool saveFailed = false;

  Timer? saveTimer;

  @override
  void initState() {
    super.initState();
    loadSavedData();
  }

  // Loads saved books and settings when the app starts.
  Future<void> loadSavedData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedText = preferences.getString(storageKey);

      if (savedText != null) {
        final data = jsonDecode(savedText) as Map<String, dynamic>;

        final savedBooks = data['books'] as List<dynamic>? ?? [];

        books = savedBooks
            .map(
              (book) => Book.fromJson(
                Map<String, dynamic>.from(book as Map),
              ),
            )
            .toList();

        selectedTheme = (data['selectedTheme'] as int?) ?? 0;

        nextBookId = (data['nextBookId'] as int?) ?? 1;
        nextChapterId = (data['nextChapterId'] as int?) ?? 1;

        if (selectedTheme < 0 || selectedTheme >= havenThemes.length) {
          selectedTheme = 0;
        }

        for (final book in books) {
          if (book.id >= nextBookId) {
            nextBookId = book.id + 1;
          }

          for (final chapter in book.chapters) {
            if (chapter.id >= nextChapterId) {
              nextChapterId = chapter.id + 1;
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Could not load saved data: $error');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Waits briefly after a change before saving.
  // This prevents a save operation for every single keystroke.
  void scheduleSave() {
    saveTimer?.cancel();

    saveTimer = Timer(
      const Duration(milliseconds: 500),
      saveData,
    );
  }

  // Saves books, chapters, and the selected theme on the phone.
  Future<void> saveData() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      final data = {
        'books': books.map((book) => book.toJson()).toList(),
        'selectedTheme': selectedTheme,
        'nextBookId': nextBookId,
        'nextChapterId': nextChapterId,
      };

      final success = await preferences.setString(
        storageKey,
        jsonEncode(data),
      );

      if (mounted) {
        setState(() {
          saveFailed = !success;
        });
      }
    } catch (error) {
      debugPrint('Could not save data: $error');

      if (mounted) {
        setState(() {
          saveFailed = true;
        });
      }
    }
  }

  void createBook(String title, String description) {
    if (title.trim().isEmpty) return;

    final firstChapter = Chapter(
      id: nextChapterId++,
      title: 'Chapter 1',
    );

    setState(() {
      books.add(
        Book(
          id: nextBookId++,
          title: title.trim(),
          description: description.trim(),
          chapters: [firstChapter],
        ),
      );
    });

    scheduleSave();
  }

  void deleteBook(Book book) {
    setState(() {
      books.removeWhere((item) => item.id == book.id);
    });

    scheduleSave();
  }

  void addChapter(Book book) {
    setState(() {
      book.chapters.add(
        Chapter(
          id: nextChapterId++,
          title: 'Chapter ${book.chapters.length + 1}',
        ),
      );
    });

    scheduleSave();
  }

  void deleteChapter(Book book, Chapter chapter) {
    if (book.chapters.length <= 1) return;

    setState(() {
      book.chapters.removeWhere((item) => item.id == chapter.id);
    });

    scheduleSave();
  }

  void updateChapterTitle(
    Book book,
    Chapter chapter,
    String title,
  ) {
    chapter.title = title;
    scheduleSave();
  }

  void updateChapterContent(
    Book book,
    Chapter chapter,
    String content,
  ) {
    chapter.content = content;
    scheduleSave();
  }

  void changeTheme(int index) {
    setState(() {
      selectedTheme = index;
    });

    scheduleSave();
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = havenThemes[selectedTheme];

    final pages = [
      HomeScreen(
        books: books,
        onOpenBooks: () {
          setState(() {
            selectedTab = 1;
          });
        },
      ),
      BooksScreen(
        books: books,
        onCreateBook: createBook,
        onDeleteBook: deleteBook,
        onAddChapter: addChapter,
        onDeleteChapter: deleteChapter,
        onUpdateChapterTitle: updateChapterTitle,
        onUpdateChapterContent: updateChapterContent,
      ),
      const SimpleScreen(
        title: 'Calendar',
        subtitle: 'Your writing schedule will live here.',
        icon: Icons.calendar_month,
      ),
      const SimpleScreen(
        title: 'Ideas',
        subtitle: 'Keep your story ideas organised.',
        icon: Icons.lightbulb_outline,
      ),
      ProfileScreen(
        selectedTheme: selectedTheme,
        onThemeChanged: changeTheme,
        saveFailed: saveFailed,
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Writers Haven',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.color,
          brightness: theme.brightness,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
        ),
      ),
      home: isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : Scaffold(
              body: SafeArea(
                child: IndexedStack(
                  index: selectedTab,
                  children: pages,
                ),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: selectedTab,
                onDestinationSelected: (index) {
                  setState(() {
                    selectedTab = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'My Books',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: 'Calendar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.lightbulb_outline),
                    label: 'Ideas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final List<Book> books;
  final VoidCallback onOpenBooks;

  const HomeScreen({
    super.key,
    required this.books,
    required this.onOpenBooks,
  });

  @override
  Widget build(BuildContext context) {
    final totalWords = books.fold<int>(
      0,
      (total, book) => total + book.totalWords,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Writers Haven'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Welcome back, writer.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Your stories deserve a place to grow.'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'My Books',
                  value: '${books.length}',
                  icon: Icons.menu_book,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Words Written',
                  value: '$totalWords',
                  icon: Icons.edit_note,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your writing space',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a book, organise its chapters, '
                    'and keep writing. Your changes are '
                    'automatically saved on this phone.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onOpenBooks,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Open My Books'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent books',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (books.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_stories),
                title: Text('No books yet'),
                subtitle: Text('Create your first story in My Books.'),
              ),
            )
          else
            ...books.reversed.take(3).map(
                  (book) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: Text(book.title),
                      subtitle: Text(
                        '${book.chapters.length} chapters · '
                        '${book.totalWords} words',
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class BooksScreen extends StatelessWidget {
  final List<Book> books;
  final void Function(String, String) onCreateBook;
  final void Function(Book) onDeleteBook;
  final void Function(Book) onAddChapter;
  final void Function(Book, Chapter) onDeleteChapter;
  final void Function(Book, Chapter, String) onUpdateChapterTitle;
  final void Function(Book, Chapter, String) onUpdateChapterContent;

  const BooksScreen({
    super.key,
    required this.books,
    required this.onCreateBook,
    required this.onDeleteBook,
    required this.onAddChapter,
    required this.onDeleteChapter,
    required this.onUpdateChapterTitle,
    required this.onUpdateChapterContent,
  });

  Future<void> showCreateBookDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a book'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Book title',
                  hintText: 'Enter your story title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;

              onCreateBook(
                titleController.text,
                descriptionController.text,
              );

              Navigator.pop(dialogContext);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> confirmDeleteBook(
    BuildContext context,
    Book book,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this book?'),
        content: Text(
          '“${book.title}” and all its chapters will be deleted '
          'from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDeleteBook(book);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        actions: [
          IconButton(
            onPressed: () => showCreateBookDialog(context),
            tooltip: 'Create book',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: books.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Your bookshelf is waiting.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Create your first book to get started.'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showCreateBookDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create a book'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.menu_book),
                    ),
                    title: Text(book.title),
                    subtitle: Text(
                      '${book.chapters.length} chapters · '
                      '${book.totalWords} words',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => BookWorkspace(
                            book: book,
                            onAddChapter: () => onAddChapter(book),
                            onDeleteChapter: (chapter) =>
                                onDeleteChapter(book, chapter),
                            
