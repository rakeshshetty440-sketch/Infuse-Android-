package com.infuse.player.ui.player

import android.app.Activity
import android.content.Context
import android.media.AudioManager
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem as ExoMediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.infuse.player.data.model.MediaItem
import kotlinx.coroutines.delay

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(
    media: MediaItem,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val audioManager = remember { context.getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    val configuration = LocalConfiguration.current
    val screenWidth = configuration.screenWidthDp.dp

    // Brightness & Volume State
    var brightness by remember {
        val window = activity?.window
        val cur = window?.attributes?.screenBrightness ?: 0.7f
        mutableFloatStateOf(if (cur < 0) 0.7f else cur)
    }
    val maxVolume = remember { audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC) }
    var currentVolume by remember {
        mutableFloatStateOf(audioManager.getStreamVolume(AudioManager.STREAM_MUSIC).toFloat() / maxVolume)
    }

    var showBrightnessHud by remember { mutableStateOf(false) }
    var showVolumeHud by remember { mutableStateOf(false) }
    var showControls by remember { mutableStateOf(true) }
    var isPlaying by remember { mutableStateOf(true) }
    var currentPosition by remember { mutableLongStateOf(0L) }
    var totalDuration by remember { mutableLongStateOf(media.durationSeconds * 1000) }

    // Auto-hide controls
    LaunchedEffect(showControls, isPlaying) {
        if (showControls && isPlaying) {
            delay(4000)
            showControls = false
        }
    }

    // Initialize ExoPlayer
    val exoPlayer = remember {
        ExoPlayer.Builder(context).build().apply {
            val item = ExoMediaItem.fromUri(media.streamUri)
            setMediaItem(item)
            prepare()
            playWhenReady = true
            addListener(object : Player.Listener {
                override fun onIsPlayingChanged(playing: Boolean) {
                    isPlaying = playing
                }
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_READY) {
                        totalDuration = duration
                    }
                }
            })
        }
    }

    // Track position updates
    LaunchedEffect(exoPlayer) {
        while (true) {
            currentPosition = exoPlayer.currentPosition
            delay(500)
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            exoPlayer.release()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = { showControls = !showControls },
                    onDoubleTap = { offset ->
                        val isLeft = offset.x < size.width / 2
                        val seekOffset = if (isLeft) -10_000L else 10_000L
                        exoPlayer.seekTo((exoPlayer.currentPosition + seekOffset).coerceAtLeast(0L))
                    }
                )
            }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = {},
                    onDragEnd = {
                        showBrightnessHud = false
                        showVolumeHud = false
                    },
                    onDragCancel = {
                        showBrightnessHud = false
                        showVolumeHud = false
                    },
                    onDrag = { change, dragAmount ->
                        change.consume()
                        val isLeftSide = change.position.x < size.width / 2
                        val delta = -dragAmount.y / 400f

                        if (isLeftSide) {
                            // Brightness swipe (Left side)
                            showBrightnessHud = true
                            brightness = (brightness + delta).coerceIn(0.05f, 1f)
                            activity?.window?.let { win ->
                                val lp = win.attributes
                                lp.screenBrightness = brightness
                                win.attributes = lp
                            }
                        } else {
                            // Volume swipe (Right side)
                            showVolumeHud = true
                            currentVolume = (currentVolume + delta).coerceIn(0f, 1f)
                            val targetVol = (currentVolume * maxVolume).toInt()
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)
                        }
                    }
                )
            }
    ) {
        // Video Surface
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = exoPlayer
                    useController = false
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Brightness HUD
        AnimatedVisibility(
            visible = showBrightnessHud,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier
                .align(Alignment.CenterStart)
                .padding(start = 24.dp)
        ) {
            HudSlider(
                icon = Icons.Default.BrightnessMedium,
                value = brightness,
                label = "${(brightness * 100).toInt()}%",
                color = Color(0xFFF59E0B)
            )
        }

        // Volume HUD
        AnimatedVisibility(
            visible = showVolumeHud,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 24.dp)
        ) {
            HudSlider(
                icon = Icons.Default.VolumeUp,
                value = currentVolume,
                label = "${(currentVolume * 100).toInt()}%",
                color = Color(0xFF38BDF8)
            )
        }

        // Controls Overlay
        AnimatedVisibility(
            visible = showControls,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Black.copy(alpha = 0.7f), Color.Transparent, Color.Black.copy(alpha = 0.85f))
                        )
                    )
                    .padding(20.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                // Top Action Bar
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(media.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text("${media.qualityTag} • ${media.audioSpec}", color = Color(0xFFF97316), fontSize = 12.sp)
                    }

                    Row {
                        IconButton(onClick = { /* Audio selection dialog */ }) {
                            Icon(Icons.Default.Audiotrack, contentDescription = "Audio", tint = Color.White)
                        }
                        IconButton(onClick = { /* Subtitle selection dialog */ }) {
                            Icon(Icons.Default.Subtitles, contentDescription = "Subtitles", tint = Color.White)
                        }
                    }
                }

                // Center Play/Pause button
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    IconButton(
                        onClick = {
                            if (exoPlayer.isPlaying) exoPlayer.pause() else exoPlayer.play()
                        },
                        modifier = Modifier
                            .size(72.dp)
                            .background(Color(0xFFF97316), CircleShape)
                    ) {
                        Icon(
                            if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = "Play/Pause",
                            tint = Color.White,
                            modifier = Modifier.size(36.dp)
                        )
                    }
                }

                // Bottom Timeline Scrubber
                Column(modifier = Modifier.fillMaxWidth()) {
                    Slider(
                        value = if (totalDuration > 0) currentPosition.toFloat() / totalDuration else 0f,
                        onValueChange = { frac ->
                            exoPlayer.seekTo((frac * totalDuration).toLong())
                        },
                        colors = SliderDefaults.colors(
                            thumbColor = Color.White,
                            activeTrackColor = Color(0xFFF97316)
                        )
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(formatMs(currentPosition), color = Color.LightGray, fontSize = 12.sp)
                        Text(formatMs(totalDuration), color = Color.LightGray, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun HudSlider(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: Float,
    label: String,
    color: Color
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Black.copy(alpha = 0.8f))
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
            Box(
                modifier = Modifier
                    .width(6.dp)
                    .height(110.dp)
                    .background(Color.White.copy(alpha = 0.2f), RoundedCornerShape(3.dp)),
                contentAlignment = Alignment.BottomCenter
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .fillMaxHeight(value)
                        .background(color, RoundedCornerShape(3.dp))
                )
            }
            Text(label, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
        }
    }
}

fun formatMs(ms: Long): String {
    val totalSeconds = (ms / 1000).coerceAtLeast(0)
    val h = totalSeconds / 3600
    val m = (totalSeconds % 3600) / 60
    val s = totalSeconds % 60
    return if (h > 0) String.format("%02d:%02d:%02d", h, m, s) else String.format("%02d:%02d", m, s)
}
