
package com.writershaven.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            WritersHavenApp()
        }
    }
}

data class HavenTheme(
    val name: String,
    val primary: Color,
    val background: Color,
    val surface: Color
)

data class HavenTab(
    val title: String,
    val icon: ImageVector
)

private val havenThemes = listOf(
    HavenTheme(
        "Royal Purple",
        Color(0xFF7046A5),
        Color(0xFFF8F5FC),
        Color(0xFFFFFFFF)
    ),
    HavenTheme(
        "Emerald Garden",
        Color(0xFF187A58),
        Color(0xFFF1F8F4),
        Color(0xFFFFFFFF)
    ),
    HavenTheme(
        "Midnight Blue",
        Color(0xFF3159A5),
        Color(0xFFF2F5FC),
        Color(0xFFFFFFFF)
    ),
    HavenTheme(
        "Rose Blush",
        Color(0xFFB94F78),
        Color(0xFFFFF4F7),
        Color(0xFFFFFFFF)
    ),
    HavenTheme(
        "Autumn Pages",
        Color(0xFF9B5A2B),
        Color(0xFFFBF5ED),
        Color(0xFFFFFFFF)
    ),
    HavenTheme(
        "Pure Black",
        Color(0xFFB69AFF),
        Color(0xFF121212),
        Color(0xFF222222)
    ),
    HavenTheme(
        "Clean White",
        Color(0xFF45415C),
        Color(0xFFFFFFFF),
        Color(0xFFF7F7FA)
    )
)

@Composable
fun WritersHavenApp() {

    var selectedTab by remember {
        mutableStateOf("Home")
    }

    var selectedThemeName by remember {
        mutableStateOf("Royal Purple")
    }

    val currentTheme = havenThemes.first {
        it.name == selectedThemeName
    }

    val tabs = listOf(
        HavenTab("Home", Icons.Filled.Home),
        HavenTab("My Books", Icons.Filled.MenuBook),
        HavenTab("Calendar", Icons.Filled.CalendarMonth),
        HavenTab("Ideas", Icons.Filled.Lightbulb),
        HavenTab("Profile", Icons.Filled.Person)
    )

    val colorScheme = lightColorScheme(
        primary = currentTheme.primary,
        secondary = currentTheme.primary,
        background = currentTheme.background,
        surface = currentTheme.surface,
        onBackground = if (selectedThemeName == "Pure Black") {
            Color.White
        } else {
            Color(0xFF24212B)
        },
        onSurface = if (selectedThemeName == "Pure Black") {
            Color.White
        } else {
            Color(0xFF24212B)
        }
    )

    MaterialTheme(colorScheme = colorScheme) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            Scaffold(
                containerColor = MaterialTheme.colorScheme.background,
                bottomBar = {
                    NavigationBar(
                        containerColor = MaterialTheme.colorScheme.surface
                    ) {
                        tabs.forEach { tab ->
                            NavigationBarItem(
                                selected = selectedTab == tab.title,
                                onClick = {
                                    selectedTab = tab.title
                                },
                                icon = {
                                    androidx.compose.material3.Icon(
                                        imageVector = tab.icon,
                                        contentDescription = tab.title
                                    )
                                },
                                label = {
                                    Text(
                                        text = tab.title,
                                        fontSize = 10.sp
                                    )
                                }
                            )
                        }
                    }
                }
            ) { innerPadding ->

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding)
                        .verticalScroll(rememberScrollState())
                        .padding(20.dp)
                ) {
                    Text(
                        text = "WRITERS HAVEN",
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 2.sp
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = selectedTab,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold
                    )

                    Spacer(modifier = Modifier.height(20.dp))

                    when (selectedTab) {
                        "Home" -> HomeScreen()
                        "My Books" -> BooksScreen()
                        "Calendar" -> CalendarScreen()
                        "Ideas" -> IdeasScreen()
                        "Profile" -> ProfileScreen(
                            selectedThemeName = selectedThemeName,
                            onThemeSelected = {
                                selectedThemeName = it
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun HomeScreen() {
    Text(
        text = "Your stories deserve a home.",
        fontSize = 18.sp,
        fontWeight = FontWeight.Medium
    )

    Spacer(modifier = Modifier.height(8.dp))

    Text(
        text = "A quiet space to plan, write and bring your ideas to life."
    )

    Spacer(modifier = Modifier.height(24.dp))

    HavenCard(title = "Today's Writing Goal") {
        Text("Your daily writing progress will appear here.")
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "0 / 500 words",
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.Bold
        )
    }

    HavenCard(title = "Your Library") {
        Text("Your books and writing projects will appear here.")
    }

    HavenCard(title = "Continue Writing") {
        Text("Choose a book from My Books to begin.")
    }
}

@Composable
fun BooksScreen() {
    HavenCard(title = "Your Books") {
        Text(
            text = "Your personal library will live here."
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Next, we'll add book creation, chapters, drafts and editing."
        )
    }
}

@Composable
fun CalendarScreen() {
    HavenCard(title = "Your Writing Calendar") {
        Text(
            text = "Plan writing sessions, chapter deadlines and important dates."
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "We'll add a working calendar and event management next."
        )
    }
}

@Composable
fun IdeasScreen() {
    HavenCard(title = "A Little Inspiration") {
        Text(
            text = "What secret is your main character afraid someone will discover?"
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "Your idea notebook and writing prompts will go here."
        )
    }
}

@Composable
fun ProfileScreen(
    selectedThemeName: String,
    onThemeSelected: (String) -> Unit
) {
    HavenCard(title = "Your Profile") {
        Text("Your account and writing preferences will appear here.")
    }

    HavenCard(title = "Choose Your Theme") {
        Text(
            text = "Selected: $selectedThemeName",
            fontWeight = FontWeight.SemiBold
        )

        Spacer(modifier = Modifier.height(12.dp))

        havenThemes.forEach { theme ->
            Button(
                onClick = {
                    onThemeSelected(theme.name)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 3.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    androidx.compose.foundation.background(
                        color = theme.primary,
                        shape = RoundedCornerShape(50)
                    ).let {
                        Spacer(
                            modifier = Modifier
                                .size(14.dp)
                                .background(
                                    theme.primary,
                                    RoundedCornerShape(50)
                                )
                        )
                    }

                    Text(theme.name)
                }
            }
        }
    }
}

@Composable
fun HavenCard(
    title: String,
    content: @Composable () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 16.dp),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 2.dp
        )
    ) {
        Column(
            modifier = Modifier.padding(18.dp)
        ) {
            Text(
                text = title,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.height(12.dp))

            content()
        }
    }
}
