package com.infuse.player

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.repository.MediaRepository
import com.infuse.player.ui.library.LibraryScreen
import com.infuse.player.ui.player.PlayerScreen
import com.infuse.player.ui.theme.InfuseTheme

class MainActivity : ComponentActivity() {

    private val repository = MediaRepository()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            InfuseTheme {
                var activePlayingMedia by remember { mutableStateOf<MediaItem?>(null) }

                if (activePlayingMedia != null) {
                    PlayerScreen(
                        media = activePlayingMedia!!,
                        onBack = { activePlayingMedia = null }
                    )
                } else {
                    LibraryScreen(
                        repository = repository,
                        onMediaSelected = { media ->
                            activePlayingMedia = media
                        }
                    )
                }
            }
        }
    }
}
