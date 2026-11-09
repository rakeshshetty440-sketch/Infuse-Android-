package com.infuse.player.data.repository

import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.model.MediaType
import com.infuse.player.data.model.NetworkShare
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class MediaRepository {

    private val _mediaList = MutableStateFlow<List<MediaItem>>(sampleData())
    val mediaList: StateFlow<List<MediaItem>> = _mediaList.asStateFlow()

    private val _shares = MutableStateFlow<List<NetworkShare>>(sampleShares())
    val shares: StateFlow<List<NetworkShare>> = _shares.asStateFlow()

    fun toggleWatched(id: String) {
        val current = _mediaList.value.toMutableList()
        val index = current.indexOfFirst { it.id == id }
        if (index != -1) {
            val item = current[index]
            val newWatched = !item.isWatched
            current[index] = item.copy(
                isWatched = newWatched,
                progressPercent = if (newWatched) 100 else 0
            )
            _mediaList.value = current
        }
    }

    fun addShare(name: String, host: String, protocol: String) {
        val newShare = NetworkShare(
            id = System.currentTimeMillis(),
            name = name,
            host = host,
            protocol = protocol,
            isOnline = true,
            itemCount = 32
        )
        _shares.value = _shares.value + newShare
    }

    private fun sampleShares(): List<NetworkShare> = listOf(
        NetworkShare(1, "Synology NAS", "192.168.1.100/movies", "SMB v3", true, 420),
        NetworkShare(2, "Jellyfin Server", "192.168.1.150:8096", "Jellyfin Direct", true, 184)
    )

    private fun sampleData(): List<MediaItem> = listOf(
        MediaItem(
            id = "m1",
            title = "Odyssey: Beyond Starlight",
            year = 2026,
            type = MediaType.MOVIE,
            durationText = "2h 24m",
            durationSeconds = 8640,
            rating = "8.8",
            qualityTag = "4K HDR",
            audioSpec = "TrueHD Atmos 7.1",
            videoCodec = "HEVC 2160p @ 23.976 fps",
            container = "MKV Remux",
            bitrate = "54.2 Mbps",
            fileSize = "58.4 GB",
            streamUri = "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            posterUrl = "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&q=80",
            backdropUrl = "https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=1200&q=80",
            synopsis = "A deep space exploration vessel investigates an anomaly at the edge of known space and discovers remnants of a civilization capable of folding gravitational matter.",
            progressPercent = 25,
            isWatched = false,
            audioTracks = listOf("English (TrueHD Atmos 7.1)", "English (AC3 5.1)", "Japanese (DTS-HD 5.1)"),
            subtitles = listOf("English [SDH]", "Spanish", "French", "None")
        ),
        MediaItem(
            id = "m2",
            title = "Cyberpunk: Neo Nocturne",
            year = 2026,
            type = MediaType.MOVIE,
            durationText = "2h 44m",
            durationSeconds = 9840,
            rating = "8.5",
            qualityTag = "Dolby Vision",
            audioSpec = "DTS-HD MA 7.1",
            videoCodec = "HEVC 2160p (Profile 8.1)",
            container = "MKV",
            bitrate = "46.8 Mbps",
            fileSize = "49.1 GB",
            streamUri = "https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            posterUrl = "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80",
            backdropUrl = "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&q=80",
            synopsis = "Amidst towering neon spires and rain-slicked corridors, a rogue cybernetic tracker uncovers an encoded signal buried inside the power grid.",
            progressPercent = 100,
            isWatched = true,
            audioTracks = listOf("English (DTS-HD MA 7.1)", "German (DTS 5.1)"),
            subtitles = listOf("English", "German", "Spanish", "None")
        )
    )
}
