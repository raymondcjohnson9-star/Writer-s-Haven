
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String storageKey = 'writers_haven_saved_data';

void main() {
  runApp(const WritersHavenApp());
}

// -------------------- THEMES --------------------

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

int countWords(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
}

// -------------------- DATA MODELS --------------------

class Chapter {
  final int id;
  String title;
  String content;

  Chapter({
    required this.id,
    required this.title,
    this.content = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
      };

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Untitled Chapter',
      content: json['content'] as String? ?? '',
    );
  }
}

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

  int get totalWords => chapters.fold<int>(
        0,
        (total, chapter) => total + countWords(chapter.content),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    final savedChapters = json['chapters'] as List<dynamic>? ?? [];

    return Book(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Untitled Book',
      description: json['description'] as String? ?? '',
      chapters: savedChapters
          .map(
            (item) => Chapter.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

// -------------------- MAIN APP --------------------

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

  Future<void> loadSavedData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedText = preferences.getString(storageKey);

      if (savedText != null) {
        final data = jsonDecode(savedText) as Map<String, dynamic>;

        books = (data['books'] as List<dynamic>? ?? [])
            .map(
              (item) => Book.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();

        selectedTheme =
            (data['selectedTheme'] as num?)?.toInt() ?? 0;
        nextBookId = (data['nextBookId'] as num?)?.toInt() ?? 1;
        nextChapterId =
            (data['nextChapterId'] as num?)?.toInt() ?? 1;

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
      setState(() => isLoading = false);
    }
  }

  void scheduleSave() {
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(milliseconds: 500),
      () => saveData(),
    );
  }

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
        setState(() => saveFailed = !success);
      }
    } catch (error) {
      debugPrint('Could not save data: $error');
      if (mounted) {
        setState(() => saveFailed = true);
      }
    }
  }

  void createBook(String title, String description) {
    if (title.trim().isEmpty) return;

    setState(() {
      books.add(
        Book(
          id: nextBookId++,
          title: title.trim(),
          description: description.trim(),
          chapters: [
            Chapter(
              id: nextChapterId++,
              title: 'Chapter 1',
            ),
          ],
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

  void updateBookTitle(Book book, String title) {
    if (title.trim().isEmpty) return;

    setState(() {
      book.title = title.trim();
    });
    scheduleSave();
  }

  void updateBookDescription(Book book, String description) {
    setState(() {
      book.description = description.trim();
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

  void updateChapterTitle(Book book, Chapter chapter, String title) {
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
    setState(() => selectedTheme = index);
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

    final pages = <Widget>[
      HomeScreen(
        books: books,
        onOpenBooks: () => setState(() => selectedTab = 1),
      ),
      BooksScreen(
        books: books,
        onCreateBook: createBook,
        onDeleteBook: deleteBook,
        onUpdateBookTitle: updateBookTitle,
        onUpdateBookDescription: updateBookDescription,
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
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
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
                  setState(() => selectedTab = index);
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
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Calendar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.lightbulb_outline),
                    selectedIcon: Icon(Icons.lightbulb),
                    label: 'Ideas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
    );
  }
}

// -------------------- HOME SCREEN --------------------

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
                    'Create books, organise chapters, and keep writing. '
                    'Your changes are saved on this phone.',
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

// -------------------- BOOKSHELF --------------------

class BooksScreen extends StatelessWidget {
  final List<Book> books;
  final void Function(String, String) onCreateBook;
  final void Function(Book) onDeleteBook;
  final void Function(Book, String) onUpdateBookTitle;
  final void Function(Book, String) onUpdateBookDescription;
  final void Function(Book) onAddChapter;
  final void Function(Book, Chapter) onDeleteChapter;
  final void Function(Book, Chapter, String) onUpdateChapterTitle;
  final void Function(Book, Chapter, String) onUpdateChapterContent;

  const BooksScreen({
    super.key,
    required this.books,
    required this.onCreateBook,
    required this.onDeleteBook,
    required this.onUpdateBookTitle,
    required this.onUpdateBookDescription,
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
          '"${book.title}" and all its chapters will be deleted '
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

    if (confirmed == true) onDeleteBook(book);
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
                    trailing: IconButton(
                      tooltip: 'Delete book',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => confirmDeleteBook(context, book),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => BookWorkspace(
                            book: book,
                            onUpdateBookTitle: (title) =>
                                onUpdateBookTitle(book, title),
                            onUpdateBookDescription: (description) =>
                                onUpdateBookDescription(book, description),
                            onAddChapter: () => onAddChapter(book),
                            onDeleteChapter: (chapter) =>
                                onDeleteChapter(book, chapter),
                            onUpdateChapterTitle: (chapter, title) =>
                                onUpdateChapterTitle(book, chapter, title),
                            onUpdateChapterContent: (chapter, content) =>
                                onUpdateChapterContent(
                                  book,
                                  chapter,
                                  content,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// -------------------- BOOK WORKSPACE --------------------

class BookWorkspace extends StatefulWidget {
  final Book book;
  final ValueChanged<String> onUpdateBookTitle;
  final ValueChanged<String> onUpdateBookDescription;
  final VoidCallback onAddChapter;
  final ValueChanged<Chapter> onDeleteChapter;
  final void Function(Chapter, String) onUpdateChapterTitle;
  final void Function(Chapter, String) onUpdateChapterContent;

  const BookWorkspace({
    super.key,
    required this.book,
    required this.onUpdateBookTitle,
    required this.onUpdateBookDescription,
    required this.onAddChapter,
    required this.onDeleteChapter,
    required this.onUpdateChapterTitle,
    required this.onUpdateChapterContent,
  });

  @override
  State<BookWorkspace> createState() => _BookWorkspaceState();
}

class _BookWorkspaceState extends State<BookWorkspace> {
  int selectedChapterId = -1;
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController chapterTitleController;
  late final TextEditingController contentController;

  Chapter? get selectedChapter {
    for (final chapter in widget.book.chapters) {
      if (chapter.id == selectedChapterId) return chapter;
    }
    return widget.book.chapters.isEmpty ? null : widget.book.chapters.first;
  }

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.book.title);
    descriptionController =
        TextEditingController(text: widget.book.description);
    chapterTitleController = TextEditingController();
    contentController = TextEditingController();

    if (widget.book.chapters.isNotEmpty) {
      selectedChapterId = widget.book.chapters.first.id;
      _loadChapter(widget.book.chapters.first);
    }
  }

  void _loadChapter(Chapter chapter) {
    selectedChapterId = chapter.id;
    chapterTitleController.text = chapter.title;
    contentController.text = chapter.content;
  }

  void _selectChapter(Chapter chapter) {
    FocusScope.of(context).unfocus();

    setState(() {
      _loadChapter(chapter);
    });
  }

  void _addChapter() {
    widget.onAddChapter();

    if (widget.book.chapters.isNotEmpty) {
      setState(() {
        _loadChapter(widget.book.chapters.last);
      });
    }
  }

  Future<void> _deleteSelectedChapter() async {
    final chapter = selectedChapter;
    if (chapter == null) return;

    if (widget.book.chapters.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A book must have at least one chapter.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chapter?'),
        content: Text('Delete "${chapter.title}" permanently?'),
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

    if (confirmed != true || !mounted) return;

    final oldIndex = widget.book.chapters.indexOf(chapter);
    widget.onDeleteChapter(chapter);

    final remaining = widget.book.chapters;
    if (remaining.isNotEmpty) {
      final newIndex = oldIndex >= remaining.length
          ? remaining.length - 1
          : oldIndex;

      setState(() {
        _loadChapter(remaining[newIndex]);
      });
    }
  }

  Future<void> _editBookDetails() async {
    final title = TextEditingController(text: widget.book.title);
    final description =
        TextEditingController(text: widget.book.description);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Book details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Book title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Description'),
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
              if (title.text.trim().isEmpty) return;

              widget.onUpdateBookTitle(title.text);
              widget.onUpdateBookDescription(description.text);

              titleController.text = title.text.trim();
              descriptionController.text = description.text.trim();

              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    title.dispose();
    description.dispose();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    chapterTitleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = selectedChapter;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            tooltip: 'Edit book details',
            onPressed: _editBookDetails,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Add chapter',
            onPressed: _addChapter,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.description.isEmpty
                      ? 'Your story workspace'
                      : widget.book.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.book.chapters.length} chapters · '
                  '${widget.book.totalWords} words',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              children: [
                ...widget.book.chapters.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.title),
                      selected: item.id == (chapter?.id ?? -1),
                      onSelected: (_) => _selectChapter(item),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('New chapter'),
                  onPressed: _addChapter,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (chapter == null)
            const Expanded(
              child: Center(child: Text('Create a chapter to begin.')),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: chapterTitleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Chapter title',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      widget.onUpdateChapterTitle(chapter, value);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${countWords(contentController.text)} words',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Delete chapter',
                        onPressed: _deleteSelectedChapter,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  TextField(
                    controller: contentController,
                    minLines: 12,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Start writing your story here...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) {
                      widget.onUpdateChapterContent(chapter, value);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your changes are saved automatically on this phone.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------- SIMPLE SCREENS --------------------

class SimpleScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const SimpleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This section is not fully implemented yet.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- PROFILE AND SETTINGS --------------------

class ProfileScreen extends StatelessWidget {
  final int selectedTheme;
  final ValueChanged<int> onThemeChanged;
  final bool saveFailed;

  const ProfileScreen({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
    required this.saveFailed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 38,
            child: Icon(Icons.person, size: 42),
          ),
          const SizedBox(height: 12),
          Text(
            'Writer',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Make yourself at home. Your stories start here.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Choose the colour theme for your writing space.'),
          const SizedBox(height: 12),
          ...List.generate(havenThemes.length, (index) {
            final theme = havenThemes[index];

            return Card(
              child: RadioListTile<int>(
                value: index,
                groupValue: selectedTheme,
                onChanged: (value) {
                  if (value != null) onThemeChanged(value);
                },
                secondary: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.color,
                ),
                title: Text(theme.name),
              ),
            );
          }),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: Icon(
                saveFailed ? Icons.warning_amber : Icons.save_outlined,
              ),
              title: const Text('Writing storage'),
              subtitle: Text(
                saveFailed
                    ? 'A save failed. Please check the app and try again.'
                    : 'Your books and chapters are saved locally on this phone.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Writers Haven',
            textAlign: TextAlign.center,
          ),
          const Text(
            'A home for your stories.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
