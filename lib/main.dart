
import 'package:flutter/material.dart';

void main() {
  runApp(const WritersHavenApp());
}

class HavenTheme {
  final String name;
  final Color primary;
  final Color background;
  final Color surface;
  final bool isDark;

  const HavenTheme({
    required this.name,
    required this.primary,
    required this.background,
    required this.surface,
    this.isDark = false,
  });
}

const List<HavenTheme> havenThemes = [
  HavenTheme(
    name: 'Royal Purple',
    primary: Color(0xFF7046A5),
    background: Color(0xFFF8F5FC),
    surface: Colors.white,
  ),
  HavenTheme(
    name: 'Emerald Garden',
    primary: Color(0xFF187A58),
    background: Color(0xFFF1F8F4),
    surface: Colors.white,
  ),
  HavenTheme(
    name: 'Midnight Blue',
    primary: Color(0xFF3159A5),
    background: Color(0xFFF2F5FC),
    surface: Colors.white,
  ),
  HavenTheme(
    name: 'Rose Blush',
    primary: Color(0xFFB94F78),
    background: Color(0xFFFFF4F7),
    surface: Colors.white,
  ),
  HavenTheme(
    name: 'Autumn Pages',
    primary: Color(0xFF9B5A2B),
    background: Color(0xFFFBF5ED),
    surface: Colors.white,
  ),
  HavenTheme(
    name: 'Pure Black',
    primary: Color(0xFFB69AFF),
    background: Color(0xFF121212),
    surface: Color(0xFF222222),
    isDark: true,
  ),
  HavenTheme(
    name: 'Clean White',
    primary: Color(0xFF45415C),
    background: Colors.white,
    surface: Color(0xFFF7F7FA),
  ),
];

class WritersHavenApp extends StatefulWidget {
  const WritersHavenApp({super.key});

  @override
  State<WritersHavenApp> createState() => _WritersHavenAppState();
}

class _WritersHavenAppState extends State<WritersHavenApp> {
  int selectedIndex = 0;
  int selectedThemeIndex = 0;

  final List<NavigationDestination> destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book_rounded),
      label: 'My Books',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Calendar',
    ),
    NavigationDestination(
      icon: Icon(Icons.lightbulb_outline_rounded),
      selectedIcon: Icon(Icons.lightbulb_rounded),
      label: 'Ideas',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentTheme = havenThemes[selectedThemeIndex];

    final colors = ColorScheme.fromSeed(
      seedColor: currentTheme.primary,
      brightness:
          currentTheme.isDark ? Brightness.dark : Brightness.light,
      surface: currentTheme.surface,
    );

    final pages = [
      const HomeScreen(),
      const BooksScreen(),
      const CalendarScreen(),
      const IdeasScreen(),
      ProfileScreen(
        selectedThemeIndex: selectedThemeIndex,
        onThemeSelected: (index) {
          setState(() {
            selectedThemeIndex = index;
          });
        },
      ),
    ];

    return MaterialApp(
      title: 'Writers Haven',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: currentTheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: currentTheme.background,
          foregroundColor: currentTheme.isDark
              ? Colors.white
              : const Color(0xFF24212B),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: currentTheme.surface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(
            destinations[selectedIndex].label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: currentTheme.primary,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: selectedIndex,
            children: pages,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          destinations: destinations,
        ),
      ),
    );
  }
}

class HavenPage extends StatelessWidget {
  final List<Widget> children;

  const HavenPage({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class HavenCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;

  const HavenCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colors.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return HavenPage(
      children: [
        const SizedBox(height: 8),
        Text(
          'WRITERS HAVEN',
          style: TextStyle(
            color: colors.primary,
            letterSpacing: 2.5,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Your stories deserve a home.',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A quiet space to plan, write and bring your ideas to life.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        HavenCard(
          title: "Today's Writing Goal",
          icon: Icons.edit_note_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your daily writing progress will appear here.'),
              const SizedBox(height: 14),
              Text(
                '0 / 500 words',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              const LinearProgressIndicator(value: 0),
            ],
          ),
        ),
        const HavenCard(
          title: 'Your Library',
          icon: Icons.library_books_rounded,
          child: Text('Your books and writing projects will appear here.'),
        ),
        const HavenCard(
          title: 'Continue Writing',
          icon: Icons.auto_stories_rounded,
          child: Text('Your latest writing projects will appear here.'),
        ),
      ],
    );
  }
}

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return HavenPage(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Every great story starts somewhere.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        HavenCard(
          title: 'Your Books',
          icon: Icons.menu_book_rounded,
          child: Column(
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 48,
                color: colors.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your personal library will live here.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Next, we will add book creation, chapters, '
                'drafts and editing.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HavenPage(
      children: const [
        SizedBox(height: 8),
        Text(
          'Make room for your next chapter.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 20),
        HavenCard(
          title: 'Writing Calendar',
          icon: Icons.calendar_month_rounded,
          child: Text(
            'Your writing sessions, chapter deadlines and important '
            'dates will appear here.',
          ),
        ),
      ],
    );
  }
}

class IdeasScreen extends StatelessWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return HavenPage(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Catch the ideas before they disappear.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        HavenCard(
          title: 'A Little Inspiration',
          icon: Icons.lightbulb_rounded,
          child: Text(
            'What secret is your main character afraid someone will discover?',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: colors.onSurface,
            ),
          ),
        ),
        const HavenCard(
          title: 'Your Idea Notebook',
          icon: Icons.note_alt_rounded,
          child: Text(
            'Your saved story ideas and writing prompts will live here.',
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final int selectedThemeIndex;
  final ValueChanged<int> onThemeSelected;

  const ProfileScreen({
    super.key,
    required this.selectedThemeIndex,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return HavenPage(
      children: [
        const SizedBox(height: 8),
        const HavenCard(
          title: 'Your Profile',
          icon: Icons.person_rounded,
          child: Text(
            'Your account, writing preferences and settings will appear here.',
          ),
        ),
        HavenCard(
          title: 'Choose Your Theme',
          icon: Icons.palette_rounded,
          child: Column(
            children: [
              for (var index = 0; index < havenThemes.length; index++)
                RadioListTile<int>(
                  value: index,
                  groupValue: selectedThemeIndex,
                  onChanged: (value) {
                    if (value != null) {
                      onThemeSelected(value);
                    }
                  },
                  activeColor: colors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: Text(havenThemes[index].name),
                  secondary: CircleAvatar(
                    radius: 12,
                    backgroundColor: havenThemes[index].primary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
