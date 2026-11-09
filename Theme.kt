package com.infuse.player.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val InfuseDarkBackground = Color(0xFF0B0C0F)
val InfuseCardBackground = Color(0xFF13151B)
val InfuseSurfaceGlass = Color(0xCC181B23)
val InfuseOrange = Color(0xFFF97316)
val InfuseAmber = Color(0xFFF59E0B)
val InfuseTextPrimary = Color(0xFFF3F4F6)
val InfuseTextSecondary = Color(0xFF9CA3AF)

private val DarkColorScheme = darkColorScheme(
    primary = InfuseOrange,
    secondary = InfuseAmber,
    background = InfuseDarkBackground,
    surface = InfuseCardBackground,
    onPrimary = Color.White,
    onBackground = InfuseTextPrimary,
    onSurface = InfuseTextPrimary
)

@Composable
fun InfuseTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
