
import 'dart:async';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'calendar_screen.dart';

const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
bool supabaseReady = false;

String get storageKey {
  final userId = supabaseReady
      ? Supabase.instance.client.auth.currentUser?.id ?? 'guest'
      : 'guest';
  return 'writers_haven_saved_data_$userId';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
    supabaseReady = true;
  }
  // Open the writing workspace directly while authentication is being deferred.
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
  HavenTheme('Midnight Purple', Color(0xFF7560FF), Brightness.dark),
  HavenTheme('Emerald Night', Color(0xFF16866A), Brightness.dark),
  HavenTheme('Deep Ocean', Color(0xFF315DAD), Brightness.dark),
  HavenTheme('Rose Night', Color(0xFFCE718D), Brightness.dark),
  HavenTheme('Autumn Night', Color(0xFFAD6334), Brightness.dark),
  HavenTheme('Pure Black', Color(0xFF151515), Brightness.dark),
  HavenTheme('Soft Midnight', Color(0xFF777777), Brightness.dark),
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
  bool isFavorite;

  Book({
    required this.id,
    required this.title,
    this.description = '',
    List<Chapter>? chapters,
    this.isFavorite = false,
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
        'isFavorite': isFavorite,
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    final savedChapters = json['chapters'] as List<dynamic>? ?? [];

    return Book(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Untitled Book',
      description: json['description'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
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

  void _applySavedData(Map<String, dynamic> data) {
    books = (data['books'] as List<dynamic>? ?? [])
        .map((item) => Book.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    selectedTheme = (data['selectedTheme'] as num?)?.toInt() ?? 0;
    nextBookId = (data['nextBookId'] as num?)?.toInt() ?? 1;
    nextChapterId = (data['nextChapterId'] as num?)?.toInt() ?? 1;
    if (selectedTheme < 0 || selectedTheme >= havenThemes.length) selectedTheme = 0;
    for (final book in books) {
      if (book.id >= nextBookId) nextBookId = book.id + 1;
      for (final chapter in book.chapters) {
        if (chapter.id >= nextChapterId) nextChapterId = chapter.id + 1;
      }
    }
  }

  Map<String, dynamic> _workspaceData() => {
        'books': books.map((book) => book.toJson()).toList(),
        'selectedTheme': selectedTheme,
        'nextBookId': nextBookId,
        'nextChapterId': nextChapterId,
      };

  Future<void> loadSavedData() async {
    try {
      final user = supabaseReady ? Supabase.instance.client.auth.currentUser : null;
      final preferences = await SharedPreferences.getInstance();
      final localText = preferences.getString(storageKey);
      final remoteRow = user == null
          ? null
          : await Supabase.instance.client
              .from('writer_workspaces')
              .select('data')
              .eq('user_id', user.id)
              .maybeSingle();

      if (remoteRow != null && remoteRow['data'] is Map) {
        _applySavedData(Map<String, dynamic>.from(remoteRow['data'] as Map));
      } else if (localText != null) {
        final localData = jsonDecode(localText) as Map<String, dynamic>;
        _applySavedData(localData);
        if (user != null) {
          await Supabase.instance.client.from('writer_workspaces').upsert({
            'user_id': user.id,
            'data': localData,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (error) {
      debugPrint('Could not load cloud workspace: $error');
      try {
        final preferences = await SharedPreferences.getInstance();
        final localText = preferences.getString(storageKey);
        if (localText != null) _applySavedData(jsonDecode(localText) as Map<String, dynamic>);
        if (mounted) setState(() => saveFailed = true);
      } catch (localError) {
        debugPrint('Could not load local workspace: $localError');
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  void scheduleSave() {
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 700), () => saveData());
  }

  Future<void> saveData() async {
    try {
      final user = supabaseReady ? Supabase.instance.client.auth.currentUser : null;
      final data = _workspaceData();
      final preferences = await SharedPreferences.getInstance();
      final localSuccess = await preferences.setString(storageKey, jsonEncode(data));
      if (user != null) {
        await Supabase.instance.client.from('writer_workspaces').upsert({
          'user_id': user.id,
          'data': data,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) setState(() => saveFailed = !localSuccess);
    } catch (error) {
      debugPrint('Could not save workspace: $error');
      if (mounted) setState(() => saveFailed = true);
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
    setState(() => book.title = title.trim());
    scheduleSave();
  }

  void updateBookDescription(Book book, String description) {
    setState(() => book.description = description.trim());
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

  void updateChapterContent(Book book, Chapter chapter, String content) {
    chapter.content = content;
    scheduleSave();
  }

  void changeTheme(int index) {
    setState(() => selectedTheme = index);
    scheduleSave();
  }

  void toggleFavorite(Book book) {
    setState(() => book.isFavorite = !book.isFavorite);
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
        onOpenCalendar: () => setState(() => selectedTab = 2),
        onOpenLibrary: () => setState(() => selectedTab = 3),
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
        onToggleFavorite: toggleFavorite,
      ),
      const CalendarScreen(userId: 'guest'),
      const LibraryScreen(),
      ProfileScreen(
        selectedTheme: selectedTheme,
        onThemeChanged: changeTheme,
        saveFailed: saveFailed,
      ),
      WritingInsightsScreen(books: books),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Writers Haven',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.color,
          brightness: Brightness.dark,
          surface: const Color(0xFF101A30),
        ).copyWith(
          primary: const Color(0xFF7660FF),
          secondary: const Color(0xFFB49AFF),
          surface: const Color(0xFF101A30),
          onSurface: const Color(0xFFF1F0FF),
        ),
        scaffoldBackgroundColor: const Color(0xFF070F20),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFF070F20),
          foregroundColor: Color(0xFFF5F2FF),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF101B32),
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF293B64)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0B1428),
          indicatorColor: const Color(0xFF30276B),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFB9A6FF)
                : const Color(0xFF8994B2),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFB9A6FF)
                : const Color(0xFF8994B2),
          )),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1428),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF293B64)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF293B64)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8A75FF), width: 1.5),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF7560FF),
          foregroundColor: Colors.white,
        ),
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
                    label: 'Stories',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Calendar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.local_library_outlined),
                    selectedIcon: Icon(Icons.local_library),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: 'Insights',
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

class _NightLandscapePainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final rect=Offset.zero&size;
    canvas.drawRect(rect,Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF080F2C),Color(0xFF29285B),Color(0xFFB46C91),Color(0xFF17264D)],stops:[0,.43,.72,1]).createShader(rect));
    final star=Paint()..color=const Color(0xFFE7DFFF);
    for(var i=0;i<46;i++){final x=((i*73+19)%997)/997*size.width;final y=((i*47+11)%389)/389*size.height*.57;canvas.drawCircle(Offset(x,y),i%7==0?1.5:.75,star);}
    canvas.drawCircle(Offset(size.width*.76,size.height*.59),size.width*.38,Paint()..shader=RadialGradient(colors:[const Color(0xFFFFC1A2).withOpacity(.55),Colors.transparent]).createShader(Rect.fromCircle(center:Offset(size.width*.76,size.height*.59),radius:size.width*.38)));
    Path ridge(double y,double a,double b,double c)=>Path()..moveTo(0,size.height*y)..lineTo(size.width*.18,size.height*a)..lineTo(size.width*.34,size.height*(a-.12))..lineTo(size.width*.52,size.height*b)..lineTo(size.width*.72,size.height*(b-.08))..lineTo(size.width*.88,size.height*c)..lineTo(size.width,size.height*(c+.04))..lineTo(size.width,size.height)..lineTo(0,size.height)..close();
    canvas.drawPath(ridge(.72,.49,.62,.53),Paint()..color=const Color(0xFF28375F));
    canvas.drawPath(ridge(.82,.61,.72,.64),Paint()..color=const Color(0xFF111D3D));
    canvas.drawRect(Rect.fromLTWH(0,size.height*.72,size.width,size.height*.28),Paint()..shader=const LinearGradient(colors:[Color(0xFF27365E),Color(0xFF111B38)]).createShader(Rect.fromLTWH(0,size.height*.72,size.width,size.height*.28)));
    final reflection=Paint()..color=const Color(0xFFFFB58E).withOpacity(.26)..strokeWidth=2;
    for(var i=0;i<15;i++){final y=size.height*(.76+i*.014),w=size.width*(.08+(i%4)*.045);canvas.drawLine(Offset(size.width*.65-w,y),Offset(size.width*.65+w,y),reflection);}
    final x=size.width*.77,y=size.height*.66;
    canvas.drawPath(Path()..moveTo(x-size.width*.09,y)..lineTo(x,y-size.height*.105)..lineTo(x+size.width*.1,y)..close(),Paint()..color=const Color(0xFF10172D));
    canvas.drawRect(Rect.fromLTWH(x-size.width*.073,y,size.width*.146,size.height*.105),Paint()..color=const Color(0xFF18213B));
    final lit=Paint()..color=const Color(0xFFFFC47C)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5);
    canvas.drawRect(Rect.fromLTWH(x-size.width*.045,y+size.height*.035,size.width*.027,size.height*.035),lit);
    canvas.drawRect(Rect.fromLTWH(x+size.width*.018,y+size.height*.035,size.width*.027,size.height*.035),lit);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class HomeScreen extends StatelessWidget {
 final List<Book> books; final VoidCallback onOpenBooks,onOpenCalendar,onOpenLibrary;
 const HomeScreen({super.key,required this.books,required this.onOpenBooks,required this.onOpenCalendar,required this.onOpenLibrary});
 @override Widget build(BuildContext context){
  final words=books.fold<int>(0,(n,b)=>n+b.totalWords);final recent=books.reversed.take(3).toList();
  return Scaffold(body:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,28),children:[
   ClipRRect(borderRadius:BorderRadius.circular(22),child:SizedBox(height:210,child:Stack(fit:StackFit.expand,children:[CustomPaint(painter:_NightLandscapePainter()),DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withOpacity(.08),const Color(0xFF090F25).withOpacity(.78)]))),Positioned(top:8,right:8,child:Row(children:[IconButton(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('You are all caught up.'))),icon:const Icon(Icons.notifications_none_rounded,color:Colors.white)),IconButton(onPressed:onOpenLibrary,icon:const Icon(Icons.settings_outlined,color:Colors.white))])),const Positioned(left:18,bottom:17,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.auto_stories_rounded,size:35,color:Color(0xFFFFD0B1)),SizedBox(height:5),Text('Writers Haven',style:TextStyle(fontSize:25,fontWeight:FontWeight.w700,color:Colors.white)),Text('Your story matters',style:TextStyle(color:Color(0xFFE3DDFB),letterSpacing:1.2))]))]))),
   const SizedBox(height:18),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Good morning,',style:TextStyle(color:Colors.white70)),Text('Writer 👑',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const Text('Small steps. Big stories.',style:TextStyle(color:Color(0xFFADB8D2)))]))]),
   const SizedBox(height:14),Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF25205C),Color(0xFF172B50)]),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF51468F))),child:Row(children:[const CircleAvatar(radius:24,backgroundColor:Color(0xFF7560FF),child:Icon(Icons.auto_stories,color:Colors.white)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Your writing progress',style:TextStyle(color:Color(0xFFC9C0FF))),const SizedBox(height:4),Text('$words words written',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))])),const Icon(Icons.trending_up,color:Color(0xFFB9A6FF),size:28)])),
   const SizedBox(height:16),GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.22,children:[_HomeAction(icon:Icons.menu_book_rounded,title:'My Stories',subtitle:'Manage your stories',onTap:onOpenBooks),_HomeAction(icon:Icons.calendar_month_rounded,title:'Calendar',subtitle:'Plan your writing',onTap:onOpenCalendar),_HomeAction(icon:Icons.edit_note_rounded,title:'Drafts',subtitle:'Continue where you left off',onTap:onOpenBooks),_HomeAction(icon:Icons.local_library_rounded,title:'Library',subtitle:'Your saved resources',onTap:onOpenLibrary)]),
   const SizedBox(height:20),Row(children:[Expanded(child:Text('Recent Stories',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),TextButton(onPressed:onOpenBooks,child:const Text('See all  ›'))]),
   if(recent.isEmpty)const Card(child:ListTile(leading:Icon(Icons.auto_stories),title:Text('Your first story starts here'),subtitle:Text('Tap My Stories to create a book.')))else ...recent.map((b)=>_StoryTile(book:b,onTap:onOpenBooks)),
  ]));
 }
}
class _HomeAction extends StatelessWidget{final IconData icon;final String title,subtitle;final VoidCallback onTap;const _HomeAction({required this.icon,required this.title,required this.subtitle,required this.onTap});@override Widget build(BuildContext context)=>Material(color:const Color(0xFF101B32),borderRadius:BorderRadius.circular(18),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF293B64))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:29,color:const Color(0xFFB49AFF)),const Spacer(),Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(fontSize:11,color:Color(0xFF9AA7C4)))]))));
}
class _StoryTile extends StatelessWidget{final Book book;final VoidCallback onTap;const _StoryTile({required this.book,required this.onTap});@override Widget build(BuildContext context)=>Card(clipBehavior:Clip.antiAlias,child:ListTile(onTap:onTap,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:7),leading:ClipRRect(borderRadius:BorderRadius.circular(9),child:SizedBox(width:55,height:66,child:CustomPaint(painter:_NightLandscapePainter(),child:const Icon(Icons.auto_stories_rounded,color:Colors.white)))),title:Text(book.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text('${book.chapters.length} chapters · ${book.totalWords} words'),trailing:const Icon(Icons.more_vert,color:Color(0xFF9AA7C4))));}

// -------------------- BOOKSHELF --------------------

// -------------------- BOOKSHELF --------------------

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
  final ValueChanged<Book> onToggleFavorite;

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
    required this.onToggleFavorite,
  });

  Future<void> showCreateBookDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreateBookDialog(
        onCreateBook: onCreateBook,
      ),
    );
  }

  Future<void> confirmDeleteBook(BuildContext context, Book book) async {
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
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => BookWorkspace(
                            book: book,
                            onUpdateBookTitle: (title) => onUpdateBookTitle(book, title),
                            onUpdateBookDescription: (description) => onUpdateBookDescription(book, description),
                            onAddChapter: () => onAddChapter(book),
                            onDeleteChapter: (chapter) => onDeleteChapter(book, chapter),
                            onUpdateChapterTitle: (chapter, title) => onUpdateChapterTitle(book, chapter, title),
                            onUpdateChapterContent: (chapter, content) => onUpdateChapterContent(book, chapter, content),
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 68,
                            height: 82,
                            child: Stack(fit: StackFit.expand, children: [
                              CustomPaint(painter: _NightLandscapePainter()),
                              const Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 7),
                                  child: Icon(Icons.auto_stories, color: Colors.white, size: 23),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 5),
                          Text('${book.chapters.length} chapters · ${book.totalWords} words', style: const TextStyle(color: Color(0xFF9AA7C4), fontSize: 12)),
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF174C50), borderRadius: BorderRadius.circular(20)),
                            child: const Text('In Progress', style: TextStyle(color: Color(0xFF9CE6D8), fontSize: 10)),
                          ),
                        ])),
                        IconButton(
                          tooltip: book.isFavorite ? 'Remove favourite' : 'Add favourite',
                          icon: Icon(book.isFavorite ? Icons.favorite : Icons.favorite_border, color: book.isFavorite ? const Color(0xFFFF8BA7) : null),
                          onPressed: () => onToggleFavorite(book),
                        ),
                        IconButton(
                          tooltip: 'Delete book',
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => confirmDeleteBook(context, book),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// -------------------- CREATE BOOK DIALOG --------------------

class _CreateBookDialog extends StatefulWidget {
  final void Function(String, String) onCreateBook;

  const _CreateBookDialog({required this.onCreateBook});

  @override
  State<_CreateBookDialog> createState() => _CreateBookDialogState();
}

class _CreateBookDialogState extends State<_CreateBookDialog> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a book'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Book title',
                hintText: 'Enter your story title',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = titleController.text.trim();

            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a book title.'),
                ),
              );
              return;
            }

            widget.onCreateBook(
              title,
              descriptionController.text.trim(),
            );

            Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
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
    setState(() => _loadChapter(chapter));
  }

  Future<void> _exportBookAsText() async {
    final output = StringBuffer()..writeln(widget.book.title)..writeln(widget.book.description)..writeln();
    for (final item in widget.book.chapters) { output.writeln(item.title); output.writeln(item.content); output.writeln(); }
    await SharePlus.instance.share(ShareParams(title: 'Export ' + widget.book.title, text: output.toString()));
  }

  void _addChapter() {
    widget.onAddChapter();

    if (widget.book.chapters.isNotEmpty) {
      setState(() => _loadChapter(widget.book.chapters.last));
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
      final newIndex =
          oldIndex >= remaining.length ? remaining.length - 1 : oldIndex;

      setState(() => _loadChapter(remaining[newIndex]));
    }
  }

  Future<void> _editBookDetails() async {
    final result = await showDialog<_BookDetailsResult>(
      context: context,
      builder: (dialogContext) => _EditBookDialog(
        initialTitle: widget.book.title,
        initialDescription: widget.book.description,
      ),
    );

    if (result == null || !mounted) return;

    widget.onUpdateBookTitle(result.title);
    widget.onUpdateBookDescription(result.description);

    titleController.text = result.title;
    descriptionController.text = result.description;

    setState(() {});
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
            tooltip: 'Export story as text',
            onPressed: _exportBookAsText,
            icon: const Icon(Icons.ios_share_outlined),
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

// -------------------- EDIT BOOK DIALOG --------------------

class _BookDetailsResult {
  final String title;
  final String description;

  const _BookDetailsResult(this.title, this.description);
}

class _EditBookDialog extends StatefulWidget {
  final String initialTitle;
  final String initialDescription;

  const _EditBookDialog({
    required this.initialTitle,
    required this.initialDescription,
  });

  @override
  State<_EditBookDialog> createState() => _EditBookDialogState();
}

class _EditBookDialogState extends State<_EditBookDialog> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle);
    descriptionController =
        TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Book details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Book title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = titleController.text.trim();

            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a book title.'),
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              _BookDetailsResult(
                title,
                descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class WritingInsightsScreen extends StatelessWidget {
  final List<Book> books;
  const WritingInsightsScreen({super.key, required this.books});
  @override
  Widget build(BuildContext context) {
    final words = books.fold<int>(0, (sum, book) => sum + book.totalWords);
    final chapters = books.fold<int>(0, (sum, book) => sum + book.chapters.length);
    final favourites = books.where((book) => book.isFavorite).length;
    final ranked = [...books]..sort((a, b) => b.totalWords.compareTo(a.totalWords));
    Widget metric(String label, String value, IconData icon) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xFFB9A6FF)), const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Color(0xFF9AA7C4), fontSize: 12))]))));
    return Scaffold(appBar: AppBar(title: const Text('Writing Insights')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Your creative progress', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), const Text('A snapshot of the stories you have built in Writer’s Haven.', style: TextStyle(color: Color(0xFFADB8D2))),
      const SizedBox(height: 16), Row(children: [metric('Total words', words.toString(), Icons.edit_note), metric('Stories', books.length.toString(), Icons.menu_book)]),
      Row(children: [metric('Chapters', chapters.toString(), Icons.library_books), metric('Favourites', favourites.toString(), Icons.favorite)]),
      const SizedBox(height: 14), Text('Most written stories', style: Theme.of(context).textTheme.titleLarge),
      if (ranked.isEmpty) const Card(child: ListTile(title: Text('Your writing stats will appear here'), subtitle: Text('Create a story and start writing to see your progress.')))
      else ...ranked.take(5).map((book) => Card(child: ListTile(leading: const Icon(Icons.auto_stories, color: Color(0xFFB9A6FF)), title: Text(book.title), subtitle: Text(book.chapters.length.toString() + ' chapters'), trailing: Text(book.totalWords.toString() + ' words')))),
    ]));
  }
}

// -------------------- SIMPLE SCREENS --------------------

class LibraryScreen extends StatelessWidget { const LibraryScreen({super.key});
  @override Widget build(BuildContext context) {
    final resources=[(Icons.tips_and_updates,'Writing Tips','Improve your writing skills','Build a daily writing habit. Start scenes with a clear moment, keep dialogue natural, and revise after the first draft.'),(Icons.person_search,'Character Builder','Create memorable characters','Give every character a goal, a strength, a weakness, and something they are afraid to lose.'),(Icons.auto_awesome,'Plot Ideas','Never run out of ideas','A stranger leaves a letter at the wrong door. The person who receives it discovers a secret that changes their town.'),(Icons.public,'World Building','Build rich story worlds','Decide how the world works: its places, history, rules, culture, and what happens when someone breaks those rules.'),(Icons.edit_note,'Writing Prompts','Get inspired','Write about a promise made years ago that must finally be kept today.'),(Icons.favorite_border,'Favourites','Saved for later','Your favourite writing resources will appear here as you save them.')];
    return Scaffold(appBar:AppBar(title:const Text('Library')),body:ListView(padding:const EdgeInsets.all(16),children:[Text('Grow your craft',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:5),const Text('Tools and inspiration for your next great story.',style:TextStyle(color:Color(0xFFADB8D2))),const SizedBox(height:18),...resources.map((item)=>Card(child:ExpansionTile(leading:CircleAvatar(backgroundColor:const Color(0xFF30276B),child:Icon(item.$1,color:const Color(0xFFB9A6FF))),title:Text(item.$2,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text(item.$3),children:[Padding(padding:const EdgeInsets.fromLTRB(72,0,16,18),child:Text(item.$4))])))]));
  }
}

// -------------------- PROFILE AND SETTINGS --------------------

// -------------------- PROFILE AND SETTINGS --------------------

class ProfileScreen extends StatelessWidget {
 final int selectedTheme;final ValueChanged<int> onThemeChanged;final bool saveFailed;
 const ProfileScreen({super.key,required this.selectedTheme,required this.onThemeChanged,required this.saveFailed});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Profile')),body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
  ClipRRect(borderRadius:BorderRadius.circular(24),child:SizedBox(height:185,child:Stack(fit:StackFit.expand,children:[CustomPaint(painter:_NightLandscapePainter()),DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,const Color(0xFF080F20).withOpacity(.9)]))),const Positioned(left:0,right:0,bottom:14,child:Column(children:[CircleAvatar(radius:39,backgroundColor:Color(0xFF161E42),child:CircleAvatar(radius:35,backgroundColor:Color(0xFF7560FF),child:Text('W',style:TextStyle(fontSize:34,fontWeight:FontWeight.bold,color:Colors.white)))),SizedBox(height:8),Text('Writer 👑',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:Colors.white)),Text('Writer · Dreamer · Creator',style:TextStyle(color:Color(0xFFD3C9F3),fontSize:12))]))]))),
  const SizedBox(height:14),Row(children:[const _ProfileStat(value:'0',label:'Stories'),const _ProfileStat(value:'0',label:'Followers'),const _ProfileStat(value:'0',label:'Following')]),
  const SizedBox(height:18),const Text('Turning ideas into stories. Building a better tomorrow, one chapter at a time.',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFB9C2D8))),const SizedBox(height:18),
  Card(child:ListTile(leading:const Icon(Icons.person_outline),title:const Text('Account'),subtitle:const Text('Guest workspace · no sign-in required'),trailing:const Icon(Icons.chevron_right),onTap:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Guest workspace'),content:const Text('Write without creating an account. Your stories stay on this device.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('OK'))])))),
  Card(child:ListTile(leading:const Icon(Icons.notifications_none),title:const Text('Notifications'),subtitle:const Text('Writing reminders and calendar alerts'),trailing:const Icon(Icons.chevron_right),onTap:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Manage writing reminders in Calendar.'))))),
  const SizedBox(height:12),Text('Appearance',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),...List.generate(havenThemes.length,(i){final t=havenThemes[i];return Card(child:RadioListTile<int>(value:i,groupValue:selectedTheme,onChanged:(v){if(v!=null)onThemeChanged(v);},secondary:CircleAvatar(radius:14,backgroundColor:t.color),title:Text(t.name)));}),
  Card(child:ListTile(leading:Icon(saveFailed?Icons.warning_amber:Icons.save_outlined),title:const Text('Data & Storage'),subtitle:Text(saveFailed?'Local save needs attention.':'Your stories are saved on this device.'))),
  const Card(child:ListTile(leading:Icon(Icons.help_outline),title:Text('Help & Support'),subtitle:Text('Your creative space, always within reach.'))),
  const SizedBox(height:14),const Center(child:Text('WRITERS HAVEN  ·  YOUR STORY MATTERS',style:TextStyle(fontSize:10,letterSpacing:2,color:Color(0xFF8994B2)))),
 ]));
}
class _ProfileStat extends StatelessWidget{final String value,label;const _ProfileStat({required this.value,required this.label});@override Widget build(BuildContext context)=>Expanded(child:Container(margin:const EdgeInsets.symmetric(horizontal:4),padding:const EdgeInsets.symmetric(vertical:13),decoration:BoxDecoration(color:const Color(0xFF101B32),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFF293B64))),child:Column(children:[Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:3),Text(label,style:const TextStyle(fontSize:11,color:Color(0xFF9AA7C4)))])));}
