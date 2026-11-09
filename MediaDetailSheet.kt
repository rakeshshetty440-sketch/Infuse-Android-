package com.infuse.player.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.infuse.player.data.model.MediaItem

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MediaDetailSheet(
    media: MediaItem,
    onDismiss: () -> Unit,
    onPlay: () -> Unit,
    onToggleWatched: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF13151B)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                AsyncImage(
                    model = media.posterUrl,
                    contentDescription = null,
                    modifier = Modifier
                        .width(90.dp)
                        .aspectRatio(2f / 3f)
                        .clip(RoundedCornerShape(10.dp)),
                    contentScale = ContentScale.Crop
                )
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(media.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text("${media.year} • ${media.durationText} • ★ ${media.rating}", color = Color.LightGray, fontSize = 12.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Badge(containerColor = Color(0x33F97316), contentColor = Color(0xFFF97316)) {
                            Text(media.qualityTag, fontSize = 9.sp)
                        }
                        Badge(containerColor = Color(0x33A855F7), contentColor = Color(0xFFD8B4FE)) {
                            Text(media.audioSpec, fontSize = 9.sp)
                        }
                    }
                }
            }

            Text(media.synopsis, color = Color(0xFFD1D5DB), fontSize = 13.sp, lineHeight = 18.sp)

            // Technical Specs Card (Infuse signature feature)
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1D26)),
                shape = RoundedCornerShape(12.dp)
            ) {
                Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("STREAM & FILE SPECIFICATIONS", color = Color.Gray, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    Text("Video Track: ${media.videoCodec}", color = Color.White, fontSize = 12.sp)
                    Text("Audio Track: ${media.audioSpec}", color = Color.White, fontSize = 12.sp)
                    Text("Container: ${media.container} • Bitrate: ${media.bitrate}", color = Color.White, fontSize = 12.sp)
                }
            }

            // Action Buttons
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = onPlay,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF97316)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Play Video")
                }
                OutlinedButton(
                    onClick = onToggleWatched,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = if (media.isWatched) Color(0xFF34D399) else Color.Gray)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(if (media.isWatched) "Watched" else "Mark Watched", color = Color.White)
                }
            }
        }
    }
}
