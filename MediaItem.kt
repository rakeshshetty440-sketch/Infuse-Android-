package com.infuse.player.data.model

data class MediaItem(
    val id: String,
    val title: String,
    val year: Int,
    val type: MediaType = MediaType.MOVIE,
    val durationText: String,
    val durationSeconds: Long,
    val rating: String,
    val qualityTag: String,
    val audioSpec: String,
    val videoCodec: String,
    val container: String,
    val bitrate: String,
    val fileSize: String,
    val streamUri: String,
    val posterUrl: String,
    val backdropUrl: String,
    val synopsis: String,
    val progressPercent: Int = 0,
    val isWatched: Boolean = false,
    val audioTracks: List<String> = emptyList(),
    val subtitles: List<String> = emptyList()
)

enum class MediaType {
    MOVIE, TV_SHOW
}

data class NetworkShare(
    val id: Long,
    val name: String,
    val host: String,
    val protocol: String,
    val isOnline: Boolean = true,
    val itemCount: Int = 0
)
