package com.infuse.player.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.repository.MediaRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    repository: MediaRepository,
    onMediaSelected: (MediaItem) -> Unit
) {
    val mediaList by repository.mediaList.collectAsState()
    var selectedItemForDetail by remember { mutableStateOf<MediaItem?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Infuse", fontWeight = FontWeight.Bold, color = Color.White)
                        Badge(containerColor = Color(0x33F97316), contentColor = Color(0xFFF97316)) {
                            Text("ANDROID", fontSize = 9.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                },
                actions = {
                    IconButton(onClick = {}) {
                        Icon(Icons.Default.Storage, contentDescription = "Shares", tint = Color.LightGray)
                    }
                    IconButton(onClick = {}) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings", tint = Color.LightGray)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0B0C0F))
            )
        },
        containerColor = Color(0xFF0B0C0F)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp)
        ) {
            // Hero Featured Banner
            if (mediaList.isNotEmpty()) {
                val featured = mediaList.first()
                HeroBanner(
                    media = featured,
                    onPlayClick = { onMediaSelected(featured) },
                    onDetailsClick = { selectedItemForDetail = featured }
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Section Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Library Collection", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                TextButton(onClick = {}) {
                    Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(14.dp), tint = Color(0xFFF97316))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Scan NAS", color = Color(0xFFF97316), fontSize = 12.sp)
                }
            }

            // Poster Grid
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = 130.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                contentPadding = PaddingValues(bottom = 24.dp)
            ) {
                items(mediaList) { item ->
                    PosterCard(
                        media = item,
                        onClick = { selectedItemForDetail = item }
                    )
                }
            }
        }
    }

    // Detail Bottom Sheet
    selectedItemForDetail?.let { item ->
        MediaDetailSheet(
            media = item,
            onDismiss = { selectedItemForDetail = null },
            onPlay = {
                selectedItemForDetail = null
                onMediaSelected(item)
            },
            onToggleWatched = { repository.toggleWatched(item.id) }
        )
    }
}

@Composable
fun HeroBanner(
    media: MediaItem,
    onPlayClick: () -> Unit,
    onDetailsClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .clip(RoundedCornerShape(16.dp)),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF13151B))
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            AsyncImage(
                model = media.backdropUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color(0xFF0B0C0F).copy(alpha = 0.95f))
                        )
                    )
            )
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(16.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Badge(containerColor = Color(0xFFF59E0B), contentColor = Color.Black) {
                        Text(media.qualityTag, fontSize = 9.sp, fontWeight = FontWeight.Black)
                    }
                    Badge(containerColor = Color(0x33A855F7), contentColor = Color(0xFFD8B4FE)) {
                        Text(media.audioSpec, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(media.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = onPlayClick,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF97316)),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Play Direct", fontSize = 12.sp)
                    }
                    OutlinedButton(
                        onClick = onDetailsClick,
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text("Details", fontSize = 12.sp, color = Color.White)
                    }
                }
            }
        }
    }
}

@Composable
fun PosterCard(media: MediaItem, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Card(
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(2f / 3f)
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                AsyncImage(
                    model = media.posterUrl,
                    contentDescription = media.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
                // Quality tag overlay
                Badge(
                    containerColor = Color.Black.copy(alpha = 0.75f),
                    contentColor = Color(0xFFF97316),
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(6.dp)
                ) {
                    Text(media.qualityTag, fontSize = 8.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(media.title, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text("${media.year} • ${media.durationText}", color = Color.Gray, fontSize = 11.sp)
    }
}
