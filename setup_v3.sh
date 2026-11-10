#!/usr/bin/env bash
set -e

rm -rf app/src/main/java *.kt
mkdir -p app/src/main/java/com/infuse/player/data/model
mkdir -p app/src/main/java/com/infuse/player/data/repository
mkdir -p app/src/main/java/com/infuse/player/data/scraper
mkdir -p app/src/main/java/com/infuse/player/ui/library
mkdir -p app/src/main/java/com/infuse/player/ui/player
mkdir -p app/src/main/java/com/infuse/player/ui/theme
mkdir -p app/src/main/res/values

cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <application
        android:allowBackup="true"
        android:icon="@android:drawable/sym_def_app_icon"
        android:label="Infuse"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.Material.NoActionBar"
        android:hardwareAccelerated="true"
        android:largeHeap="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:supportsPictureInPicture="true"
            android:configChanges="orientation|screenSize|screenLayout|smallestScreenSize|uiMode">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:mimeType="video/*" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat << 'EOF' > app/src/main/res/values/strings.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Infuse</string>
</resources>
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/data/model/MediaItem.kt
package com.infuse.player.data.model

data class MediaItem(
    val id: String,
    val title: String,
    val rawFilename: String = "",
    val folderName: String = "Internal Storage",
    val filePath: String = "",
    val year: Int = 2026,
    val isTvShow: Boolean = false,
    val seasonNumber: Int? = null,
    val episodeNumber: Int? = null,
    val durationText: String = "--",
    val durationSeconds: Long = 0L,
    val rating: String = "8.4",
    val qualityTag: String = "1080p FHD",
    val resolution: String = "1920x1080",
    val frameRate: String = "24 fps",
    val hdrFormat: String = "SDR (8-bit)",
    val audioSpec: String = "Multi-Track Audio",
    val audioDetails: String = "48.0 kHz • Stereo / Surround",
    val videoCodec: String = "HEVC / H.264",
    val container: String = "Matroska (MKV)",
    val bitrate: String = "--",
    val fileSize: String = "--",
    val sizeBytes: Long = 0L,
    val subtitleSummary: String = "Embedded & External (.SRT/.ASS)",
    val streamUri: String,
    val posterUrl: String = "",
    val backdropUrl: String = "",
    val synopsis: String = "Tap poster to inspect full track details or start playback.",
    val savedPositionMs: Long = 0L,
    val isWatched: Boolean = false,
    val hasDeepSpecs: Boolean = false
) {
    val progressFraction: Float
        get() = if (durationSeconds > 0) (savedPositionMs.toFloat() / (durationSeconds * 1000f)).coerceIn(0f, 1f) else 0f
}

data class TmdbSearchCandidate(
    val tmdbId: Long,
    val title: String,
    val year: Int,
    val isTv: Boolean,
    val rating: String,
    val posterUrl: String,
    val backdropUrl: String,
    val synopsis: String
)
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/data/scraper/FilenameParser.kt
package com.infuse.player.data.scraper

object FilenameParser {
    private val TV_REGEX = Regex("(?i)[._ -]S(\\d{1,2})[._ -]?E(\\d{1,3})")
    private val ALT_TV_REGEX = Regex("(?i)\\b(\\d{1,2})x(\\d{1,3})\\b")
    private val YEAR_REGEX = Regex("[._ \\[(]((?:19|20)\\d{2})[._ \\])]?")
    private val BRACKET_PREFIX = Regex("^\\[[^\\]]+\\]\\s*|^\\([^)]+\\)\\s*")
    private val WEBSITE_PREFIX = Regex("(?i)^(www\\.[^ ]+\\s*-\\s*|@[a-z0-9_]+\\s*[-_]?\\s*)")

    private val JUNK_TOKENS = listOf(
        "2160p", "1080p", "720p", "480p", "576p", "4k", "uhd", "hdr", "hdr10", "hdr10plus", "dv", "dovi",
        "dolby", "vision", "remux", "bluray", "bdrip", "brrip", "web-dl", "webdl", "webrip", "hdrip", "hdtv",
        "dvdrip", "camrip", "x264", "x265", "h264", "h265", "hevc", "avc", "av1", "10bit", "8bit",
        "truehd", "atmos", "dts-hd", "dtshd", "dts", "ddp5", "dd5", "ac3", "eac3", "aac", "flac", "mp3",
        "dual", "audio", "multi", "subs", "esub", "esubs", "proper", "repack", "extended", "unrated",
        "directors", "cut", "theatrical", "imax", "amzn", "nf", "dsnp", "hmax", "atvp", "hulu",
        "yify", "yts", "rarbg", "psa", "galaxy", "pahe", "tigole", "qxr", "hindi", "tamil", "telugu",
        "malayalam", "kannada", "eng", "english", "jap", "japanese", "kor", "korean", "dubbed", "org"
    )

    data class ParsedInfo(
        val cleanTitle: String,
        val year: Int?,
        val isTv: Boolean,
        val season: Int? = null,
        val episode: Int? = null
    )

    fun parse(rawFilename: String): ParsedInfo {
        var name = rawFilename.substringBeforeLast(".")
        name = BRACKET_PREFIX.replace(name, "")
        name = WEBSITE_PREFIX.replace(name, "")

        val tvMatch = TV_REGEX.find(name) ?: ALT_TV_REGEX.find(name)
        if (tvMatch != null) {
            val s = tvMatch.groupValues[1].toIntOrNull()
            val e = tvMatch.groupValues[2].toIntOrNull()
            val beforeTv = name.substring(0, tvMatch.range.first)
            val cleaned = cleanWords(beforeTv)
            return ParsedInfo(cleaned.ifEmpty { name }, null, true, s, e)
        }

        val yearMatch = YEAR_REGEX.find(name)
        if (yearMatch != null) {
            val yr = yearMatch.groupValues[1].toIntOrNull()
            val beforeYear = name.substring(0, yearMatch.range.first)
            val cleaned = cleanWords(beforeYear)
            if (cleaned.isNotBlank()) {
                return ParsedInfo(cleaned, yr, false)
            }
        }

        val cleaned = cleanWords(name)
        return ParsedInfo(cleaned.ifEmpty { name.replace(Regex("[._-]"), " ").trim() }, null, false)
    }

    private fun cleanWords(raw: String): String {
        val str = raw.replace(Regex("[._\\[\\]()\\-]"), " ").trim()
        val words = str.split(Regex("\\s+"))
        val kept = mutableListOf<String>()
        for (w in words) {
            val lower = w.lowercase()
            if (lower in JUNK_TOKENS) {
                if (kept.isNotEmpty()) break else continue
            }
            if (lower.matches(Regex("^\\d+mb$|^\\d+gb$|^x\\d+$"))) {
                if (kept.isNotEmpty()) break else continue
            }
            kept.add(w)
        }
        return kept.joinToString(" ").trim()
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/data/scraper/TmdbScraperService.kt
package com.infuse.player.data.scraper

import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.model.TmdbSearchCandidate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

class TmdbScraperService(
    private val apiKey: String = "f52f0d6c1b1784ece4eed64ff99052ac",
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .build()
) {
    suspend fun enrichWithMetadata(item: MediaItem): MediaItem = withContext(Dispatchers.IO) {
        val parsed = FilenameParser.parse(item.rawFilename.ifEmpty { item.title })
        val candidates = searchCandidates(parsed.cleanTitle, parsed.year)
        val best = candidates.firstOrNull()

        if (best != null) {
            return@withContext item.copy(
                title = best.title,
                year = best.year,
                isTvShow = best.isTv || parsed.isTv,
                seasonNumber = parsed.season,
                episodeNumber = parsed.episode,
                rating = best.rating,
                posterUrl = best.posterUrl.ifEmpty { item.posterUrl },
                backdropUrl = best.backdropUrl.ifEmpty { item.backdropUrl },
                synopsis = best.synopsis.ifEmpty { item.synopsis }
            )
        }

        item.copy(
            title = parsed.cleanTitle,
            year = parsed.year ?: item.year,
            isTvShow = parsed.isTv,
            seasonNumber = parsed.season,
            episodeNumber = parsed.episode,
            synopsis = "Local video (${item.rawFilename}) in ${item.folderName} • ${item.resolution} • ${item.fileSize}"
        )
    }

    suspend fun searchCandidates(queryText: String, year: Int? = null): List<TmdbSearchCandidate> = withContext(Dispatchers.IO) {
        val list = mutableListOf<TmdbSearchCandidate>()
        if (queryText.isBlank()) return@withContext list

        val encoded = URLEncoder.encode(queryText.trim(), "UTF-8")
        val url = "https://api.themoviedb.org/3/search/multi?api_key=$apiKey&query=$encoded&include_adult=false"

        try {
            val req = Request.Builder().url(url).build()
            client.newCall(req).execute().use { res ->
                if (res.isSuccessful) {
                    val json = JSONObject(res.body?.string() ?: "{}")
                    val results = json.optJSONArray("results")
                    if (results != null) {
                        for (i in 0 until minOf(results.length(), 10)) {
                            val obj = results.getJSONObject(i)
                            val mediaType = obj.optString("media_type", "movie")
                            if (mediaType != "movie" && mediaType != "tv") continue

                            val isTv = mediaType == "tv"
                            val title = if (isTv) obj.optString("name") else obj.optString("title")
                            if (title.isBlank()) continue

                            val posterPath = obj.optString("poster_path", "")
                            val backdropPath = obj.optString("backdrop_path", "")
                            val overview = obj.optString("overview", "")
                            val vote = obj.optDouble("vote_average", 8.0)
                            val date = if (isTv) obj.optString("first_air_date") else obj.optString("release_date")
                            val yr = date.take(4).toIntOrNull() ?: year ?: 2026

                            list.add(
                                TmdbSearchCandidate(
                                    tmdbId = obj.optLong("id"),
                                    title = title,
                                    year = yr,
                                    isTv = isTv,
                                    rating = String.format("%.1f", vote),
                                    posterUrl = if (posterPath.isNotEmpty() && posterPath != "null") "https://image.tmdb.org/t/p/w500$posterPath" else "",
                                    backdropUrl = if (backdropPath.isNotEmpty() && backdropPath != "null") "https://image.tmdb.org/t/p/w1280$backdropPath" else "",
                                    synopsis = overview
                                )
                            )
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        list
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/data/repository/MediaRepository.kt
package com.infuse.player.data.repository

import android.content.ContentUris
import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.model.TmdbSearchCandidate
import com.infuse.player.data.scraper.FilenameParser
import com.infuse.player.data.scraper.TmdbScraperService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

class MediaRepository(private val context: Context) {
    val scraper = TmdbScraperService()
    private val scope = CoroutineScope(Dispatchers.IO)
    private val prefs = context.getSharedPreferences("infuse_v5_store", Context.MODE_PRIVATE)

    private val _mediaList = MutableStateFlow<List<MediaItem>>(emptyList())
    val mediaList: StateFlow<List<MediaItem>> = _mediaList.asStateFlow()

    private val _isScanning = MutableStateFlow(false)
    val isScanning: StateFlow<Boolean> = _isScanning.asStateFlow()

    // Normalize resume key by filename so MediaStore URI and DocumentPicker URI share the exact same resume state!
    private fun resumeKey(rawFilename: String, streamUri: String): String {
        val cleanKey = rawFilename.trim().lowercase(Locale.ROOT)
        return if (cleanKey.isNotEmpty()) "pos_file_$cleanKey" else "pos_uri_$streamUri"
    }

    private fun watchedKey(rawFilename: String, streamUri: String): String {
        val cleanKey = rawFilename.trim().lowercase(Locale.ROOT)
        return if (cleanKey.isNotEmpty()) "watched_file_$cleanKey" else "watched_uri_$streamUri"
    }

    // Use synchronous commit() so closing or swiping away the app NEVER loses the timestamp!
    fun savePlaybackPosition(item: MediaItem, positionMs: Long, durationMs: Long) {
        if (positionMs <= 1000L) return
        val rKey = resumeKey(item.rawFilename, item.streamUri)
        val wKey = watchedKey(item.rawFilename, item.streamUri)
        val watched = durationMs > 0 && positionMs >= (durationMs * 0.93)

        val editor = prefs.edit().putLong(rKey, positionMs)
        if (durationMs > 0) {
            editor.putLong("dur_${item.rawFilename}", durationMs / 1000L)
        }
        if (watched) {
            editor.putBoolean(wKey, true)
        }
        editor.commit() // Synchronous write to disk

        _mediaList.value = _mediaList.value.map { current ->
            if (current.id == item.id || current.rawFilename.equals(item.rawFilename, ignoreCase = true) || current.streamUri == item.streamUri) {
                current.copy(
                    savedPositionMs = positionMs,
                    durationSeconds = if (durationMs > 0) durationMs / 1000L else current.durationSeconds,
                    isWatched = watched || current.isWatched
                )
            } else current
        }
    }

    fun getSavedPosition(item: MediaItem): Long {
        return prefs.getLong(resumeKey(item.rawFilename, item.streamUri), 0L)
    }

    private fun savePickedUriToHistory(uri: String, name: String, sizeBytes: Long) {
        try {
            val rawJson = prefs.getString("picked_history_v5", "[]") ?: "[]"
            val arr = JSONArray(rawJson)
            val updated = JSONArray()
            val entry = JSONObject().apply {
                put("uri", uri)
                put("name", name)
                put("size", sizeBytes)
            }
            updated.put(entry)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("uri") != uri && obj.optString("name") != name) {
                    updated.put(obj)
                }
            }
            prefs.edit().putString("picked_history_v5", updated.toString()).commit()
        } catch (_: Exception) {}
    }

    private fun loadPickedHistory(): List<MediaItem> {
        val list = mutableListOf<MediaItem>()
        try {
            val rawJson = prefs.getString("picked_history_v5", "[]") ?: "[]"
            val arr = JSONArray(rawJson)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val uriStr = obj.optString("uri")
                val name = obj.optString("name", "Video.mkv")
                val size = obj.optLong("size", 0L)
                if (uriStr.isNotEmpty()) {
                    list.add(
                        createFastMediaItem(
                            id = "picked_${name.hashCode()}",
                            name = name,
                            folderName = "Opened Videos",
                            filePath = "",
                            uri = Uri.parse(uriStr),
                            durationMs = prefs.getLong("dur_$name", 0L) * 1000L,
                            sizeBytes = size,
                            width = 1920,
                            height = 1080
                        )
                    )
                }
            }
        } catch (_: Exception) {}
        return list
    }

    // Instant <0.2s Device Scan: Queries MediaStore columns ONLY (never blocks on heavy file I/O)
    fun scanDeviceVideos() {
        scope.launch {
            _isScanning.value = true
            val discovered = mutableListOf<MediaItem>()
            val seenNames = mutableSetOf<String>()

            // 1. Restore any manually opened videos first so they are always remembered
            for (picked in loadPickedHistory()) {
                discovered.add(picked)
                seenNames.add(picked.rawFilename.lowercase(Locale.ROOT))
            }

            // 2. Fast MediaStore cursor query
            val projection = arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
                MediaStore.Video.Media.DATA,
                MediaStore.Video.Media.DURATION,
                MediaStore.Video.Media.SIZE,
                MediaStore.Video.Media.WIDTH,
                MediaStore.Video.Media.HEIGHT
            )
            val sortOrder = "${MediaStore.Video.Media.DATE_ADDED} DESC"

            try {
                context.contentResolver.query(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    null,
                    null,
                    sortOrder
                )?.use { cursor ->
                    val idCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                    val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
                    val bucketCol = cursor.getColumnIndex(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)
                    val dataCol = cursor.getColumnIndex(MediaStore.Video.Media.DATA)
                    val durCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
                    val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                    val widthCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
                    val heightCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)

                    while (cursor.moveToNext()) {
                        val id = cursor.getLong(idCol)
                        val name = cursor.getString(nameCol) ?: "Video_$id.mp4"
                        if (name.lowercase(Locale.ROOT) in seenNames) continue
                        seenNames.add(name.lowercase(Locale.ROOT))

                        val folder = if (bucketCol != -1) cursor.getString(bucketCol) ?: "Videos" else "Videos"
                        val path = if (dataCol != -1) cursor.getString(dataCol) ?: "" else ""
                        val durationMs = cursor.getLong(durCol)
                        val sizeBytes = cursor.getLong(sizeCol)
                        val w = cursor.getInt(widthCol)
                        val h = cursor.getInt(heightCol)
                        val contentUri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)

                        val fastItem = createFastMediaItem(
                            id = "local_$id",
                            name = name,
                            folderName = folder,
                            filePath = path,
                            uri = contentUri,
                            durationMs = durationMs,
                            sizeBytes = sizeBytes,
                            width = w,
                            height = h
                        )
                        discovered.add(fastItem)
                    }
                }
            } catch (_: Exception) {}

            if (discovered.isEmpty()) {
                discovered.addAll(defaultDemoSamples())
            }

            // Immediately publish the list so the UI is NEVER stuck at 0!
            _mediaList.value = discovered
            _isScanning.value = false

            // 3. Enrich posters/metadata asynchronously in the background
            val working = discovered.toMutableList()
            for (i in working.indices) {
                val item = working[i]
                val customTitle = prefs.getString("custom_title_${item.rawFilename}", null)
                if (customTitle != null) {
                    working[i] = item.copy(
                        title = customTitle,
                        year = prefs.getInt("custom_year_${item.rawFilename}", item.year),
                        posterUrl = prefs.getString("custom_poster_${item.rawFilename}", item.posterUrl) ?: item.posterUrl,
                        backdropUrl = prefs.getString("custom_backdrop_${item.rawFilename}", item.backdropUrl) ?: item.backdropUrl,
                        synopsis = prefs.getString("custom_synopsis_${item.rawFilename}", item.synopsis) ?: item.synopsis,
                        rating = prefs.getString("custom_rating_${item.rawFilename}", item.rating) ?: item.rating
                    )
                } else {
                    working[i] = scraper.enrichWithMetadata(item)
                }
                _mediaList.value = working.toList()
            }
        }
    }

    // On-Demand Deep Track Inspector: Runs ONLY for the single clicked video (<80ms)
    suspend fun inspectSingleVideoDeepSpecs(item: MediaItem): MediaItem = withContext(Dispatchers.IO) {
        if (item.hasDeepSpecs) return@withContext item

        val uri = Uri.parse(item.streamUri)
        var durationMs = item.durationSeconds * 1000L
        var width = item.resolution.substringBefore("x").toIntOrNull() ?: 1920
        var height = item.resolution.substringAfter("x").toIntOrNull() ?: 1080
        var bitrateBps = 0L

        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)
            if (durationMs <= 0L) {
                durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            }
            val rw = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val rh = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            if (rw != null && rw > 0) width = rw
            if (rh != null && rh > 0) height = rh
            bitrateBps = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull() ?: 0L
        } catch (_: Exception) {
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }

        var vCodecName = item.videoCodec
        var frameRateStr = item.frameRate
        var hdrStr = item.hdrFormat
        var aCodecName = item.audioSpec
        var aDetailStr = item.audioDetails
        val audioTracksFound = mutableListOf<String>()
        val subTracksFound = mutableListOf<String>()

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(context, uri, null)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                val lang = if (format.containsKey(MediaFormat.KEY_LANGUAGE)) format.getString(MediaFormat.KEY_LANGUAGE) ?: "und" else "und"

                if (mime.startsWith("video/")) {
                    vCodecName = formatFriendlyCodec(mime)
                    if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                        try {
                            frameRateStr = "${format.getInteger(MediaFormat.KEY_FRAME_RATE)} fps"
                        } catch (_: Exception) {}
                    }
                    if (format.containsKey(MediaFormat.KEY_COLOR_TRANSFER)) {
                        hdrStr = when (format.getInteger(MediaFormat.KEY_COLOR_TRANSFER)) {
                            6 -> "HDR10 (PQ 10-bit)"
                            7 -> "HLG HDR"
                            else -> "SDR (Rec.709)"
                        }
                    }
                } else if (mime.startsWith("audio/")) {
                    val friendlyAudio = formatFriendlyCodec(mime)
                    val ch = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 2
                    val sr = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 48000
                    val chLayout = when (ch) {
                        1 -> "Mono 1.0"
                        2 -> "Stereo 2.0"
                        6 -> "Surround 5.1"
                        8 -> "Surround 7.1"
                        else -> "$ch Channels"
                    }
                    if (audioTracksFound.isEmpty()) {
                        aCodecName = "$friendlyAudio ($chLayout)"
                        aDetailStr = "${String.format(Locale.US, "%.1f", sr / 1000.0)} kHz • $chLayout • ${lang.uppercase()}"
                    }
                    audioTracksFound.add("$friendlyAudio $chLayout (${lang.uppercase()})")
                } else if (mime.startsWith("text/") || mime.contains("sub") || mime.contains("ssa") || mime.contains("vtt") || mime.contains("pgs")) {
                    subTracksFound.add("${lang.uppercase()} (${formatFriendlyCodec(mime)})")
                }
            }
        } catch (_: Exception) {
        } finally {
            try { extractor.release() } catch (_: Exception) {}
        }

        val calcBitrate = if (bitrateBps > 0) {
            String.format(Locale.US, "%.1f Mbps", bitrateBps / 1_000_000.0)
        } else if (durationMs > 0 && item.sizeBytes > 0) {
            val bps = (item.sizeBytes * 8.0) / (durationMs / 1000.0)
            String.format(Locale.US, "%.1f Mbps", bps / 1_000_000.0)
        } else item.bitrate

        val totalSecs = if (durationMs > 0) durationMs / 1000 else item.durationSeconds
        val hrs = totalSecs / 3600
        val mins = (totalSecs % 3600) / 60
        val durText = if (totalSecs > 0) {
            if (hrs > 0) "${hrs}h ${mins}m" else "${mins}m ${(totalSecs % 60)}s"
        } else item.durationText

        val updated = item.copy(
            durationSeconds = totalSecs,
            durationText = durText,
            resolution = "${width}x${height}",
            frameRate = frameRateStr,
            hdrFormat = hdrStr,
            videoCodec = vCodecName,
            audioSpec = aCodecName,
            audioDetails = if (audioTracksFound.size > 1) "$aDetailStr (+${audioTracksFound.size - 1} tracks)" else aDetailStr,
            bitrate = calcBitrate,
            subtitleSummary = if (subTracksFound.isNotEmpty()) subTracksFound.joinToString(", ") else item.subtitleSummary,
            hasDeepSpecs = true
        )

        _mediaList.value = _mediaList.value.map { if (it.id == updated.id) updated else it }
        updated
    }

    fun addPickedVideoUri(uri: Uri, onReady: (MediaItem) -> Unit) {
        scope.launch {
            var displayName = "Local_Video.mkv"
            var sizeBytes = 0L
            try {
                context.contentResolver.query(uri, null, null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val nameIdx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val sizeIdx = c.getColumnIndex(OpenableColumns.SIZE)
                        if (nameIdx != -1) displayName = c.getString(nameIdx) ?: displayName
                        if (sizeIdx != -1) sizeBytes = c.getLong(sizeIdx)
                    }
                }
            } catch (_: Exception) {}

            savePickedUriToHistory(uri.toString(), displayName, sizeBytes)

            val fastItem = createFastMediaItem(
                id = "picked_${displayName.hashCode()}",
                name = displayName,
                folderName = "Opened Videos",
                filePath = "",
                uri = uri,
                durationMs = prefs.getLong("dur_$displayName", 0L) * 1000L,
                sizeBytes = sizeBytes,
                width = 1920,
                height = 1080
            )
            val deepItem = inspectSingleVideoDeepSpecs(fastItem)
            val enriched = scraper.enrichWithMetadata(deepItem)

            _mediaList.value = listOf(enriched) + _mediaList.value.filter {
                !it.rawFilename.equals(enriched.rawFilename, ignoreCase = true) && it.streamUri != enriched.streamUri
            }
            withContext(Dispatchers.Main) {
                onReady(enriched)
            }
        }
    }

    fun applyManualMetadataMatch(itemId: String, candidate: TmdbSearchCandidate) {
        _mediaList.value = _mediaList.value.map { item ->
            if (item.id == itemId) {
                prefs.edit()
                    .putString("custom_title_${item.rawFilename}", candidate.title)
                    .putInt("custom_year_${item.rawFilename}", candidate.year)
                    .putString("custom_poster_${item.rawFilename}", candidate.posterUrl)
                    .putString("custom_backdrop_${item.rawFilename}", candidate.backdropUrl)
                    .putString("custom_synopsis_${item.rawFilename}", candidate.synopsis)
                    .putString("custom_rating_${item.rawFilename}", candidate.rating)
                    .commit()

                item.copy(
                    title = candidate.title,
                    year = candidate.year,
                    isTvShow = candidate.isTv,
                    rating = candidate.rating,
                    posterUrl = candidate.posterUrl.ifEmpty { item.posterUrl },
                    backdropUrl = candidate.backdropUrl.ifEmpty { item.backdropUrl },
                    synopsis = candidate.synopsis.ifEmpty { item.synopsis }
                )
            } else item
        }
    }

    fun toggleWatched(id: String) {
        _mediaList.value = _mediaList.value.map {
            if (it.id == id) {
                val nextWatched = !it.isWatched
                val wKey = watchedKey(it.rawFilename, it.streamUri)
                val rKey = resumeKey(it.rawFilename, it.streamUri)
                val ed = prefs.edit().putBoolean(wKey, nextWatched)
                if (!nextWatched) ed.putLong(rKey, 0L)
                ed.commit()
                it.copy(isWatched = nextWatched, savedPositionMs = if (!nextWatched) 0L else it.savedPositionMs)
            } else it
        }
    }

    private fun createFastMediaItem(
        id: String,
        name: String,
        folderName: String,
        filePath: String,
        uri: Uri,
        durationMs: Long,
        sizeBytes: Long,
        width: Int,
        height: Int
    ): MediaItem {
        val parsed = FilenameParser.parse(name)
        val lowerName = name.lowercase(Locale.ROOT)
        val ext = name.substringAfterLast(".", "MKV").uppercase(Locale.ROOT)
        val containerName = when (ext) {
            "MKV" -> "Matroska (MKV)"
            "MP4", "M4V" -> "MPEG-4 (MP4)"
            "AVI" -> "AVI Container"
            "TS", "M2TS" -> "MPEG-TS Stream"
            "WEBM" -> "WebM Media"
            "MOV" -> "QuickTime (MOV)"
            else -> ext
        }

        val vCodecGuess = when {
            lowerName.contains("x265") || lowerName.contains("hevc") || lowerName.contains("h265") -> "HEVC / H.265"
            lowerName.contains("av1") -> "AV1"
            else -> "AVC / H.264"
        }

        val aCodecGuess = when {
            lowerName.contains("atmos") || lowerName.contains("eac3") || lowerName.contains("ddp") -> "Dolby Digital+ / Atmos"
            lowerName.contains("truehd") -> "Dolby TrueHD"
            lowerName.contains("dts") -> "DTS-HD / DTS Audio"
            lowerName.contains("ac3") || lowerName.contains("dd5") -> "Dolby Digital (AC3)"
            lowerName.contains("flac") -> "FLAC Lossless"
            else -> "AAC / Multi-Track Audio"
        }

        val hdrGuess = when {
            lowerName.contains("dv") || lowerName.contains("dovi") -> "Dolby Vision"
            lowerName.contains("hdr10") || lowerName.contains("hdr") -> "HDR10 (10-bit)"
            else -> "SDR (8-bit)"
        }

        val w = if (width > 0) width else if (lowerName.contains("2160p") || lowerName.contains("4k")) 3840 else 1920
        val h = if (height > 0) height else if (lowerName.contains("2160p") || lowerName.contains("4k")) 2160 else 1080

        val quality = when {
            w >= 3800 || h >= 2100 -> "4K UHD"
            w >= 2500 || h >= 1400 -> "1440p QHD"
            w >= 1900 || h >= 1000 -> "1080p FHD"
            w >= 1200 || h >= 700 -> "720p HD"
            else -> "SD Direct"
        }

        val sizeText = if (sizeBytes >= 1024L * 1024L * 1024L) {
            String.format(Locale.US, "%.2f GB", sizeBytes / (1024.0 * 1024.0 * 1024.0))
        } else if (sizeBytes > 0) {
            String.format(Locale.US, "%.1f MB", sizeBytes / (1024.0 * 1024.0))
        } else "Local File"

        val calcBitrate = if (durationMs > 0 && sizeBytes > 0) {
            val bps = (sizeBytes * 8.0) / (durationMs / 1000.0)
            String.format(Locale.US, "%.1f Mbps", bps / 1_000_000.0)
        } else "Direct Stream"

        val savedDurSecs = prefs.getLong("dur_$name", durationMs / 1000L)
        val totalSecs = if (durationMs > 0) durationMs / 1000L else savedDurSecs
        val hrs = totalSecs / 3600
        val mins = (totalSecs % 3600) / 60
        val durText = if (totalSecs > 0) {
            if (hrs > 0) "${hrs}h ${mins}m" else "${mins}m ${(totalSecs % 60)}s"
        } else "Direct Play"

        val savedPos = prefs.getLong(resumeKey(name, uri.toString()), 0L)
        val savedWatched = prefs.getBoolean(watchedKey(name, uri.toString()), false)

        return MediaItem(
            id = id,
            title = parsed.cleanTitle,
            rawFilename = name,
            folderName = folderName,
            filePath = filePath,
            year = parsed.year ?: 2026,
            isTvShow = parsed.isTv,
            seasonNumber = parsed.season,
            episodeNumber = parsed.episode,
            durationText = durText,
            durationSeconds = totalSecs,
            rating = "Local",
            qualityTag = quality,
            resolution = "${w}x${h}",
            frameRate = "24 fps",
            hdrFormat = hdrGuess,
            audioSpec = aCodecGuess,
            audioDetails = "48.0 kHz • Hardware & FFmpeg Direct",
            videoCodec = vCodecGuess,
            container = containerName,
            bitrate = calcBitrate,
            fileSize = sizeText,
            sizeBytes = sizeBytes,
            subtitleSummary = "Embedded + External .SRT/.ASS",
            streamUri = uri.toString(),
            posterUrl = "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&q=80",
            backdropUrl = "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&q=80",
            synopsis = "Local video file: $name",
            savedPositionMs = savedPos,
            isWatched = savedWatched
        )
    }

    private fun formatFriendlyCodec(mime: String): String = when (mime.lowercase(Locale.ROOT)) {
        "video/hevc", "video/dolby-vision" -> "HEVC / H.265"
        "video/avc" -> "AVC / H.264"
        "video/x-vnd.on2.vp9" -> "VP9"
        "video/av01" -> "AV1"
        "audio/ac3" -> "Dolby Digital (AC3)"
        "audio/eac3", "audio/eac3-joc" -> "Dolby Digital+ / Atmos (E-AC3)"
        "audio/true-hd" -> "Dolby TrueHD"
        "audio/vnd.dts" -> "DTS Audio"
        "audio/vnd.dts.hd" -> "DTS-HD Master Audio"
        "audio/mp4a-latm" -> "AAC Audio"
        "audio/flac" -> "FLAC Lossless"
        "audio/opus" -> "Opus Audio"
        "audio/vorbis" -> "Vorbis Audio"
        "audio/mpeg" -> "MP3 Audio"
        "application/x-subrip" -> "SubRip (SRT)"
        "text/x-ssa" -> "SubStation Alpha (ASS)"
        "text/vtt" -> "WebVTT"
        else -> mime.substringAfter("/").uppercase(Locale.ROOT)
    }

    private fun defaultDemoSamples(): List<MediaItem> = listOf(
        MediaItem(
            id = "demo_1",
            title = "Big Buck Bunny",
            rawFilename = "Big.Buck.Bunny.2008.1080p.BluRay.x264.DTS-HD.mp4",
            folderName = "Sample Stream",
            year = 2008,
            durationText = "9m 56s",
            durationSeconds = 596,
            rating = "8.1",
            qualityTag = "1080p FHD",
            resolution = "1920x1080",
            frameRate = "24 fps",
            hdrFormat = "SDR (8-bit)",
            audioSpec = "AAC 5.1 Surround",
            audioDetails = "48.0 kHz • 6 Channels • ENG",
            videoCodec = "AVC / H.264",
            container = "MPEG-4 (MP4)",
            bitrate = "5.2 Mbps",
            fileSize = "158 MB",
            subtitleSummary = "Embedded + External .SRT/.ASS",
            streamUri = "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            posterUrl = "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&q=80",
            backdropUrl = "https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=1200&q=80",
            synopsis = "Instant scanner & persistent resume active! Tap Open Video or grant permission to browse and play all local videos with Next/Previous skipping."
        )
    )
}
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/ui/theme/Theme.kt
package com.infuse.player.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFF97316),
    secondary = Color(0xFFF59E0B),
    background = Color(0xFF090A0D),
    surface = Color(0xFF12141C),
    onPrimary = Color.White,
    onBackground = Color(0xFFF3F4F6),
    onSurface = Color(0xFFF3F4F6)
)

@Composable
fun InfuseTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkColorScheme, content = content)
}
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/ui/library/MediaDetailSheet.kt
package com.infuse.player.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.model.TmdbSearchCandidate
import com.infuse.player.data.repository.MediaRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MediaDetailSheet(
    media: MediaItem,
    repository: MediaRepository,
    onDismiss: () -> Unit,
    onPlayFromStart: () -> Unit,
    onResume: (Long) -> Unit,
    onToggleWatched: () -> Unit,
    onMetadataUpdated: (MediaItem) -> Unit
) {
    val scope = rememberCoroutineScope()
    var currentMedia by remember(media) { mutableStateOf(media) }
    var isInspectingTracks by remember { mutableStateOf(!media.hasDeepSpecs) }
    var showEditMatchDialog by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf(media.title) }
    var searchResults by remember { mutableStateOf<List<TmdbSearchCandidate>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }

    // Inspect exact video/audio/subtitle tracks on-demand in <80ms when sheet opens
    LaunchedEffect(media.id) {
        val latestSavedPos = repository.getSavedPosition(media)
        currentMedia = media.copy(savedPositionMs = latestSavedPos)
        if (!media.hasDeepSpecs) {
            isInspectingTracks = true
            val deep = repository.inspectSingleVideoDeepSpecs(currentMedia)
            currentMedia = deep.copy(savedPositionMs = repository.getSavedPosition(deep))
            isInspectingTracks = false
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF101218)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 24.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(190.dp)
            ) {
                AsyncImage(
                    model = currentMedia.backdropUrl.ifEmpty { currentMedia.posterUrl },
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                listOf(Color.Transparent, Color(0xFF101218))
                            )
                        )
                )
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(horizontal = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.Bottom
                ) {
                    AsyncImage(
                        model = currentMedia.posterUrl,
                        contentDescription = null,
                        modifier = Modifier
                            .width(95.dp)
                            .aspectRatio(2f / 3f)
                            .clip(RoundedCornerShape(12.dp)),
                        contentScale = ContentScale.Crop
                    )
                    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(currentMedia.title, color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, maxLines = 2)
                        Text(
                            buildString {
                                append("${currentMedia.year} • ${currentMedia.durationText} • ★ ${currentMedia.rating}")
                                if (currentMedia.seasonNumber != null && currentMedia.episodeNumber != null) {
                                    append(" • S${currentMedia.seasonNumber}:E${currentMedia.episodeNumber}")
                                }
                            },
                            color = Color.LightGray,
                            fontSize = 12.sp
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Badge(containerColor = Color(0xFFF59E0B), contentColor = Color.Black) {
                                Text(currentMedia.qualityTag, fontSize = 10.sp, fontWeight = FontWeight.Black)
                            }
                            Badge(containerColor = Color(0x33A855F7), contentColor = Color(0xFFD8B4FE)) {
                                Text(currentMedia.videoCodec, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                            }
                            Badge(containerColor = Color(0x3338BDF8), contentColor = Color(0xFF38BDF8)) {
                                Text(currentMedia.container.substringBefore(" "), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            Column(
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                if (currentMedia.savedPositionMs > 2000L) {
                    Button(
                        onClick = { onResume(currentMedia.savedPositionMs) },
                        modifier = Modifier.fillMaxWidth().height(50.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF97316)),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Resume from ${formatSheetTime(currentMedia.savedPositionMs)}", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedButton(
                            onClick = onPlayFromStart,
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Replay, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color.White)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Start Over", color = Color.White, fontSize = 12.sp)
                        }
                        OutlinedButton(
                            onClick = onToggleWatched,
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(16.dp), tint = if (currentMedia.isWatched) Color(0xFF34D399) else Color.Gray)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(if (currentMedia.isWatched) "Watched" else "Mark Watched", color = Color.White, fontSize = 12.sp)
                        }
                    }
                } else {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = onPlayFromStart,
                            modifier = Modifier.weight(1.3f).height(50.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF97316)),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.PlayArrow, contentDescription = null)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Play Direct", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        }
                        OutlinedButton(
                            onClick = onToggleWatched,
                            modifier = Modifier.weight(1f).height(50.dp),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = if (currentMedia.isWatched) Color(0xFF34D399) else Color.Gray)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(if (currentMedia.isWatched) "Watched" else "Mark Watched", color = Color.White, fontSize = 12.sp)
                        }
                    }
                }

                OutlinedButton(
                    onClick = {
                        searchQuery = currentMedia.title
                        showEditMatchDialog = true
                        scope.launch {
                            isSearching = true
                            searchResults = repository.scraper.searchCandidates(searchQuery)
                            isSearching = false
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFFF97316))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Edit Metadata / Fix Poster Match", color = Color(0xFFF97316), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }

                Text(currentMedia.synopsis, color = Color(0xFFD1D5DB), fontSize = 13.sp, lineHeight = 19.sp)

                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF181B24)),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("COMPLETE STREAM & FORMAT SPECIFICATIONS", color = Color(0xFFF97316), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            if (isInspectingTracks) {
                                CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp, color = Color(0xFFF97316))
                            }
                        }
                        SpecRow("File Name", currentMedia.rawFilename.ifEmpty { currentMedia.title })
                        SpecRow("Folder Location", currentMedia.folderName)
                        SpecRow("Container Format", currentMedia.container)
                        SpecRow("Video Track", "${currentMedia.videoCodec} • ${currentMedia.hdrFormat}")
                        SpecRow("Resolution & FPS", "${currentMedia.resolution} (${currentMedia.qualityTag}) @ ${currentMedia.frameRate}")
                        SpecRow("Audio Track", currentMedia.audioSpec)
                        SpecRow("Audio Channels", currentMedia.audioDetails)
                        SpecRow("Subtitle Engine", currentMedia.subtitleSummary)
                        SpecRow("Bitrate & Size", "${currentMedia.bitrate} • ${currentMedia.fileSize}")
                    }
                }
            }
        }
    }

    if (showEditMatchDialog) {
        AlertDialog(
            onDismissRequest = { showEditMatchDialog = false },
            containerColor = Color(0xFF151821),
            title = { Text("Match Movie / TV Show on TMDb", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        label = { Text("Enter Movie or TV Show Name", color = Color.Gray) },
                        singleLine = true,
                        trailingIcon = {
                            IconButton(onClick = {
                                scope.launch {
                                    isSearching = true
                                    searchResults = repository.scraper.searchCandidates(searchQuery)
                                    isSearching = false
                                }
                            }) {
                                Icon(Icons.Default.Search, contentDescription = "Search", tint = Color(0xFFF97316))
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    )

                    if (isSearching) {
                        LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = Color(0xFFF97316))
                    }

                    Column(
                        modifier = Modifier.heightIn(max = 280.dp).verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        searchResults.forEach { cand ->
                            Card(
                                colors = CardDefaults.cardColors(containerColor = Color(0xFF1F2430)),
                                modifier = Modifier.fillMaxWidth().clickable {
                                    repository.applyManualMetadataMatch(currentMedia.id, cand)
                                    val updated = repository.mediaList.value.find { it.id == currentMedia.id }
                                    if (updated != null) {
                                        currentMedia = updated
                                        onMetadataUpdated(updated)
                                    }
                                    showEditMatchDialog = false
                                }
                            ) {
                                Row(modifier = Modifier.padding(10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                                    AsyncImage(
                                        model = cand.posterUrl,
                                        contentDescription = null,
                                        modifier = Modifier.width(42.dp).aspectRatio(2f / 3f).clip(RoundedCornerShape(6.dp)),
                                        contentScale = ContentScale.Crop
                                    )
                                    Column {
                                        Text(cand.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        Text("${cand.year} • ${if (cand.isTv) "TV Series" else "Movie"} • ★ ${cand.rating}", color = Color(0xFFF97316), fontSize = 11.sp)
                                    }
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showEditMatchDialog = false }) {
                    Text("Cancel", color = Color.Gray)
                }
            }
        )
    }
}

@Composable
fun SpecRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Text(label, color = Color.Gray, fontSize = 12.sp, modifier = Modifier.weight(0.38f))
        Text(value, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(0.62f))
    }
}

fun formatSheetTime(ms: Long): String {
    val totalSecs = (ms / 1000).coerceAtLeast(0)
    val h = totalSecs / 3600
    val m = (totalSecs % 3600) / 60
    val s = totalSecs % 60
    return if (h > 0) String.format("%d:%02d:%02d", h, m, s) else String.format("%02d:%02d", m, s)
}
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/ui/library/LibraryScreen.kt
package com.infuse.player.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
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
    onMediaSelected: (MediaItem, Long) -> Unit,
    onPickLocalFile: () -> Unit,
    onRescanStorage: () -> Unit
) {
    val mediaList by repository.mediaList.collectAsState()
    val isScanning by repository.isScanning.collectAsState()
    var selectedItemForDetail by remember { mutableStateOf<MediaItem?>(null) }
    var activeTab by remember { mutableStateOf("all") }
    var searchQuery by remember { mutableStateOf("") }
    var showSearchBar by remember { mutableStateOf(false) }

    val filteredList = remember(mediaList, activeTab, searchQuery) {
        mediaList.filter { item ->
            val matchesTab = when (activeTab) {
                "movies" -> !item.isTvShow
                "tv" -> item.isTvShow
                "unwatched" -> !item.isWatched
                else -> true
            }
            val matchesSearch = searchQuery.isBlank() ||
                item.title.contains(searchQuery, ignoreCase = true) ||
                item.rawFilename.contains(searchQuery, ignoreCase = true) ||
                item.folderName.contains(searchQuery, ignoreCase = true)
            matchesTab && matchesSearch
        }
    }

    val continueWatchingList = remember(mediaList) {
        mediaList.filter { it.savedPositionMs > 2000L }
    }

    val foldersMap = remember(mediaList) {
        mediaList.groupBy { it.folderName }
    }

    Scaffold(
        topBar = {
            Column(modifier = Modifier.background(Color(0xFF090A0D))) {
                TopAppBar(
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Infuse", fontWeight = FontWeight.ExtraBold, color = Color.White, fontSize = 20.sp)
                            Badge(containerColor = Color(0x33F97316), contentColor = Color(0xFFF97316)) {
                                Text("PRO v5.0", fontSize = 9.sp, fontWeight = FontWeight.Black)
                            }
                        }
                    },
                    actions = {
                        IconButton(onClick = { showSearchBar = !showSearchBar }) {
                            Icon(Icons.Default.Search, contentDescription = "Search", tint = Color.LightGray)
                        }
                        Button(
                            onClick = onPickLocalFile,
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF97316)),
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Icon(Icons.Default.FolderOpen, contentDescription = "Open Video", modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Open Video", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                        IconButton(onClick = onRescanStorage) {
                            Icon(Icons.Default.Refresh, contentDescription = "Scan Storage", tint = Color.LightGray)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF090A0D))
                )

                if (showSearchBar) {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        placeholder = { Text("Search movies, filenames, or folders...", color = Color.Gray, fontSize = 13.sp) },
                        singleLine = true,
                        trailingIcon = {
                            if (searchQuery.isNotEmpty()) {
                                IconButton(onClick = { searchQuery = "" }) {
                                    Icon(Icons.Default.Clear, contentDescription = "Clear", tint = Color.Gray)
                                }
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 6.dp)
                    )
                }

                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    val tabs = listOf(
                        "all" to "All Videos (${mediaList.size})",
                        "movies" to "Movies",
                        "tv" to "TV Shows",
                        "folders" to "Folders (${foldersMap.size})",
                        "unwatched" to "Unwatched"
                    )
                    items(tabs) { (key, label) ->
                        val active = activeTab == key
                        FilterChip(
                            selected = active,
                            onClick = { activeTab = key },
                            label = { Text(label, fontSize = 12.sp, fontWeight = if (active) FontWeight.Bold else FontWeight.Medium) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = Color(0xFFF97316),
                                selectedLabelColor = Color.White,
                                containerColor = Color(0xFF151822),
                                labelColor = Color.LightGray
                            ),
                            border = null
                        )
                    }
                }
            }
        },
        containerColor = Color(0xFF090A0D)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp)
        ) {
            if (isScanning) {
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                    color = Color(0xFFF97316)
                )
            }

            if (activeTab == "folders") {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(minSize = 155.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    contentPadding = PaddingValues(vertical = 12.dp)
                ) {
                    items(foldersMap.entries.toList()) { (folderName, videos) ->
                        Card(
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFF141720)),
                            modifier = Modifier.fillMaxWidth().clickable {
                                searchQuery = folderName
                                activeTab = "all"
                            }
                        ) {
                            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Icon(Icons.Default.Folder, contentDescription = null, tint = Color(0xFFF97316), modifier = Modifier.size(32.dp))
                                Text(folderName, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1)
                                Text("${videos.size} video files", color = Color.Gray, fontSize = 12.sp)
                            }
                        }
                    }
                }
            } else {
                if (continueWatchingList.isNotEmpty() && activeTab == "all" && searchQuery.isEmpty()) {
                    Text("Continue Watching", color = Color(0xFFF97316), fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Spacer(modifier = Modifier.height(8.dp))
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
                    ) {
                        items(continueWatchingList) { item ->
                            Card(
                                modifier = Modifier
                                    .width(230.dp)
                                    .height(115.dp)
                                    .clip(RoundedCornerShape(14.dp))
                                    .clickable { onMediaSelected(item, item.savedPositionMs) },
                                colors = CardDefaults.cardColors(containerColor = Color(0xFF161922))
                            ) {
                                Box(modifier = Modifier.fillMaxSize()) {
                                    AsyncImage(
                                        model = item.backdropUrl.ifEmpty { item.posterUrl },
                                        contentDescription = null,
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                    Box(
                                        modifier = Modifier
                                            .fillMaxSize()
                                            .background(
                                                Brush.verticalGradient(
                                                    listOf(Color.Black.copy(alpha = 0.2f), Color.Black.copy(alpha = 0.85f))
                                                )
                                            )
                                    )
                                    Column(
                                        modifier = Modifier.align(Alignment.BottomStart).padding(10.dp)
                                    ) {
                                        Text(item.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp, maxLines = 1)
                                        Text("Resume at ${formatSheetTime(item.savedPositionMs)}", color = Color(0xFFF97316), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                        Spacer(modifier = Modifier.height(6.dp))
                                        LinearProgressIndicator(
                                            progress = { item.progressFraction },
                                            modifier = Modifier.fillMaxWidth().height(4.dp),
                                            color = Color(0xFFF97316),
                                            trackColor = Color.White.copy(alpha = 0.25f)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                LazyVerticalGrid(
                    columns = GridCells.Adaptive(minSize = 115.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    contentPadding = PaddingValues(bottom = 28.dp)
                ) {
                    items(filteredList) { item ->
                        Column(
                            modifier = Modifier.fillMaxWidth().clickable { selectedItemForDetail = item }
                        ) {
                            Card(
                                shape = RoundedCornerShape(12.dp),
                                colors = CardDefaults.cardColors(containerColor = Color(0xFF141720)),
                                modifier = Modifier.fillMaxWidth().aspectRatio(2f / 3f)
                            ) {
                                Box(modifier = Modifier.fillMaxSize()) {
                                    AsyncImage(
                                        model = item.posterUrl,
                                        contentDescription = item.title,
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                    Badge(
                                        containerColor = Color.Black.copy(alpha = 0.82f),
                                        contentColor = Color(0xFFF97316),
                                        modifier = Modifier.align(Alignment.TopStart).padding(6.dp)
                                    ) {
                                        Text(item.qualityTag, fontSize = 8.sp, fontWeight = FontWeight.Bold)
                                    }
                                    if (!item.isWatched && item.savedPositionMs == 0L) {
                                        Box(
                                            modifier = Modifier
                                                .align(Alignment.TopEnd)
                                                .padding(8.dp)
                                                .size(8.dp)
                                                .background(Color(0xFFF97316), RoundedCornerShape(4.dp))
                                        )
                                    }
                                    if (item.savedPositionMs > 2000L) {
                                        LinearProgressIndicator(
                                            progress = { item.progressFraction },
                                            modifier = Modifier
                                                .align(Alignment.BottomCenter)
                                                .fillMaxWidth()
                                                .height(4.dp),
                                            color = Color(0xFFF97316),
                                            trackColor = Color.Black.copy(alpha = 0.6f)
                                        )
                                    }
                                }
                            }
                            Spacer(modifier = Modifier.height(5.dp))
                            Text(item.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text("${item.videoCodec} • ${item.durationText}", color = Color.Gray, fontSize = 11.sp, maxLines = 1)
                        }
                    }
                }
            }
        }
    }

    selectedItemForDetail?.let { item ->
        MediaDetailSheet(
            media = item,
            repository = repository,
            onDismiss = { selectedItemForDetail = null },
            onPlayFromStart = {
                selectedItemForDetail = null
                onMediaSelected(item, 0L)
            },
            onResume = { savedMs ->
                selectedItemForDetail = null
                onMediaSelected(item, savedMs)
            },
            onToggleWatched = {
                repository.toggleWatched(item.id)
                selectedItemForDetail = repository.mediaList.value.find { it.id == item.id }
            },
            onMetadataUpdated = { updated ->
                selectedItemForDetail = updated
            }
        )
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/ui/player/PlayerScreen.kt
package com.infuse.player.ui.player

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.media.AudioManager
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.repository.MediaRepository
import kotlinx.coroutines.delay
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.interfaces.IMedia
import org.videolan.libvlc.util.VLCVideoLayout
import java.io.File
import java.io.FileOutputStream

data class VlcTrackOption(
    val id: Int,
    val name: String,
    val isSelected: Boolean
)

@Composable
fun PlayerScreen(
    media: MediaItem,
    initialSeekMs: Long,
    hasPrevious: Boolean,
    hasNext: Boolean,
    onSkipPrevious: () -> Unit,
    onSkipNext: () -> Unit,
    repository: MediaRepository,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val lifecycleOwner = LocalLifecycleOwner.current
    val audioManager = remember { context.getSystemService(Context.AUDIO_SERVICE) as AudioManager }

    val currentMedia by rememberUpdatedState(media)

    var isLandscape by remember { mutableStateOf(true) }
    var isControlsLocked by remember { mutableStateOf(false) }
    var showControls by remember { mutableStateOf(true) }
    var showBrightnessHud by remember { mutableStateOf(false) }
    var showVolumeHud by remember { mutableStateOf(false) }
    var showSeekHud by remember { mutableStateOf(false) }
    var seekPreviewText by remember { mutableStateOf("") }

    var showAudioDialog by remember { mutableStateOf(false) }
    var showSubtitleDialog by remember { mutableStateOf(false) }
    var showInfoDialog by remember { mutableStateOf(false) }

    var brightness by remember {
        val cur = activity?.window?.attributes?.screenBrightness ?: 0.8f
        mutableFloatStateOf(if (cur < 0) 0.8f else cur)
    }
    val maxVolume = remember { audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1) }
    var currentVolume by remember {
        mutableFloatStateOf(audioManager.getStreamVolume(AudioManager.STREAM_MUSIC).toFloat() / maxVolume)
    }

    var isPlaying by remember(media.id) { mutableStateOf(true) }
    var currentPosition by remember(media.id) { mutableLongStateOf(initialSeekMs) }
    var totalDuration by remember(media.id) { mutableLongStateOf((media.durationSeconds * 1000).coerceAtLeast(1L)) }
    var playbackSpeed by remember { mutableFloatStateOf(1.0f) }

    var audioTracks by remember(media.id) { mutableStateOf<List<VlcTrackOption>>(emptyList()) }
    var subtitleTracks by remember(media.id) { mutableStateOf<List<VlcTrackOption>>(emptyList()) }
    var currentScaleIdx by remember { mutableIntStateOf(0) }
    val scaleLabels = listOf("FIT", "FILL", "16:9", "4:3", "CROP")
    val scaleTypes = listOf(
        MediaPlayer.ScaleType.SURFACE_BEST_FIT,
        MediaPlayer.ScaleType.SURFACE_FILL,
        MediaPlayer.ScaleType.SURFACE_16_9,
        MediaPlayer.ScaleType.SURFACE_4_3,
        MediaPlayer.ScaleType.SURFACE_FIT_SCREEN
    )

    // Fullscreen Landscape Mode
    DisposableEffect(activity) {
        val window = activity?.window
        val originalOrientation = activity?.requestedOrientation ?: ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE

        if (window != null) {
            val controller = WindowCompat.getInsetsController(window, window.decorView)
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.systemBars())
        }

        onDispose {
            activity?.requestedOrientation = originalOrientation
            if (window != null) {
                val controller = WindowCompat.getInsetsController(window, window.decorView)
                controller.show(WindowInsetsCompat.Type.systemBars())
            }
        }
    }

    val libVlc = remember {
        val args = arrayListOf(
            "--aout=opensles,android_audiotrack",
            "--audio-time-stretch",
            "-vvv",
            "--network-caching=1500",
            "--file-caching=1500"
        )
        LibVLC(context, args)
    }

    val vlcPlayer = remember {
        MediaPlayer(libVlc).apply {
            setAudioOutput("android_audiotrack")
            volume = 100
        }
    }

    fun refreshVlcTracks() {
        val curAudio = vlcPlayer.audioTrack
        val aList = vlcPlayer.audioTracks?.map { desc ->
            VlcTrackOption(desc.id, desc.name ?: "Track ${desc.id}", desc.id == curAudio)
        } ?: emptyList()
        audioTracks = aList

        val curSpu = vlcPlayer.spuTrack
        val sList = vlcPlayer.spuTracks?.map { desc ->
            VlcTrackOption(desc.id, desc.name ?: "Subtitle ${desc.id}", desc.id == curSpu)
        } ?: emptyList()
        subtitleTracks = sList
    }

    // Load or switch video whenever media.streamUri changes (supports Next / Previous skipping!)
    DisposableEffect(media.streamUri, initialSeekMs) {
        var pfd: ParcelFileDescriptor? = null
        val uri = Uri.parse(media.streamUri)

        val vlcMedia = try {
            if (uri.scheme == "content") {
                pfd = context.contentResolver.openFileDescriptor(uri, "r")
                if (pfd != null) {
                    Media(libVlc, pfd!!.fileDescriptor)
                } else {
                    Media(libVlc, uri)
                }
            } else {
                Media(libVlc, uri)
            }
        } catch (_: Exception) {
            Media(libVlc, uri)
        }

        vlcMedia.setHWDecoderEnabled(true, false)
        // Tell LibVLC directly to start at the exact resume second!
        if (initialSeekMs > 1000L) {
            vlcMedia.addOption(":start-time=${initialSeekMs / 1000L}")
        }
        vlcPlayer.media = vlcMedia
        vlcMedia.release()

        var didSeekAfterPlay = false
        vlcPlayer.setEventListener { event ->
            when (event.type) {
                MediaPlayer.Event.Playing -> {
                    isPlaying = true
                    if (vlcPlayer.length > 0) totalDuration = vlcPlayer.length
                    if (!didSeekAfterPlay && initialSeekMs > 1000L) {
                        didSeekAfterPlay = true
                        if (vlcPlayer.time < initialSeekMs - 2000L) {
                            vlcPlayer.time = initialSeekMs
                        }
                    }
                    refreshVlcTracks()
                }
                MediaPlayer.Event.Paused -> {
                    isPlaying = false
                }
                MediaPlayer.Event.TimeChanged -> {
                    currentPosition = event.timeChanged
                }
                MediaPlayer.Event.LengthChanged -> {
                    if (event.lengthChanged > 0) totalDuration = event.lengthChanged
                }
                MediaPlayer.Event.ESAdded, MediaPlayer.Event.ESSelected -> {
                    refreshVlcTracks()
                }
            }
        }

        audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        vlcPlayer.play()

        onDispose {
            repository.savePlaybackPosition(media, currentPosition, totalDuration)
            vlcPlayer.stop()
            try { pfd?.close() } catch (_: Exception) {}
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            vlcPlayer.detachViews()
            vlcPlayer.release()
            libVlc.release()
        }
    }

    // Synchronously commit resume timestamp when user presses Home, switches apps, or closes app
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE || event == Lifecycle.Event.ON_STOP) {
                repository.savePlaybackPosition(currentMedia, currentPosition, totalDuration)
                if (vlcPlayer.isPlaying) vlcPlayer.pause()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val subtitleFilePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let { subUri ->
            try {
                val subFile = File(context.cacheDir, "ext_sub_${System.currentTimeMillis()}.srt")
                context.contentResolver.openInputStream(subUri)?.use { input ->
                    FileOutputStream(subFile).use { output -> input.copyTo(output) }
                }
                vlcPlayer.addSlave(IMedia.Slave.Type.Subtitle, Uri.fromFile(subFile), true)
                refreshVlcTracks()
            } catch (_: Exception) {}
            showSubtitleDialog = false
        }
    }

    LaunchedEffect(showControls, isPlaying) {
        if (showControls && isPlaying) {
            delay(4000)
            showControls = false
        }
    }

    // Save resume position every 2 seconds while playing
    LaunchedEffect(media.id) {
        while (true) {
            if (isPlaying && currentPosition > 1000L) {
                repository.savePlaybackPosition(currentMedia, currentPosition, totalDuration)
            }
            delay(2000)
        }
    }

    var gestureMode by remember { mutableStateOf("none") }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(isControlsLocked) {
                detectTapGestures(
                    onTap = { showControls = !showControls },
                    onDoubleTap = { offset ->
                        if (!isControlsLocked) {
                            val isLeft = offset.x < size.width / 2
                            val delta = if (isLeft) -10_000L else 10_000L
                            val nextTime = (currentPosition + delta).coerceIn(0L, totalDuration)
                            vlcPlayer.time = nextTime
                            currentPosition = nextTime
                        }
                    }
                )
            }
            .pointerInput(isControlsLocked) {
                if (!isControlsLocked) {
                    detectDragGestures(
                        onDragStart = { gestureMode = "none" },
                        onDragEnd = {
                            showBrightnessHud = false
                            showVolumeHud = false
                            showSeekHud = false
                            gestureMode = "none"
                        },
                        onDragCancel = {
                            showBrightnessHud = false
                            showVolumeHud = false
                            showSeekHud = false
                            gestureMode = "none"
                        },
                        onDrag = { change, dragAmount ->
                            change.consume()
                            if (gestureMode == "none") {
                                gestureMode = if (kotlin.math.abs(dragAmount.x) > kotlin.math.abs(dragAmount.y) * 1.3f) {
                                    "seek"
                                } else if (change.position.x < size.width / 2) {
                                    "brightness"
                                } else {
                                    "volume"
                                }
                            }

                            when (gestureMode) {
                                "brightness" -> {
                                    showBrightnessHud = true
                                    val delta = -dragAmount.y / 400f
                                    brightness = (brightness + delta).coerceIn(0.05f, 1f)
                                    activity?.window?.let { win ->
                                        val lp = win.attributes
                                        lp.screenBrightness = brightness
                                        win.attributes = lp
                                    }
                                }
                                "volume" -> {
                                    showVolumeHud = true
                                    val delta = -dragAmount.y / 400f
                                    currentVolume = (currentVolume + delta).coerceIn(0f, 1f)
                                    audioManager.setStreamVolume(
                                        AudioManager.STREAM_MUSIC,
                                        (currentVolume * maxVolume).toInt(),
                                        0
                                    )
                                }
                                "seek" -> {
                                    showSeekHud = true
                                    val seekDelta = (dragAmount.x * 150L).toLong()
                                    val target = (currentPosition + seekDelta).coerceIn(0L, totalDuration)
                                    vlcPlayer.time = target
                                    currentPosition = target
                                    seekPreviewText = formatMs(target)
                                }
                            }
                        }
                    )
                }
            }
    ) {
        AndroidView(
            factory = { ctx ->
                VLCVideoLayout(ctx).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    vlcPlayer.attachViews(this, null, true, false)
                    vlcPlayer.videoScale = scaleTypes[currentScaleIdx]
                }
            },
            update = {
                vlcPlayer.videoScale = scaleTypes[currentScaleIdx]
            },
            modifier = Modifier.fillMaxSize()
        )

        AnimatedVisibility(
            visible = showBrightnessHud,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.CenterStart).padding(start = 28.dp)
        ) {
            HudBar(Icons.Default.BrightnessMedium, brightness, "${(brightness * 100).toInt()}%", Color(0xFFF59E0B))
        }

        AnimatedVisibility(
            visible = showVolumeHud,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.CenterEnd).padding(end = 28.dp)
        ) {
            HudBar(Icons.Default.VolumeUp, currentVolume, "${(currentVolume * 100).toInt()}%", Color(0xFF38BDF8))
        }

        AnimatedVisibility(
            visible = showSeekHud,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.Center)
        ) {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color.Black.copy(alpha = 0.85f))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(Icons.Default.FastForward, contentDescription = null, tint = Color(0xFFF97316))
                    Text(seekPreviewText, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                }
            }
        }

        AnimatedVisibility(
            visible = showControls,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.fillMaxSize()
        ) {
            if (isControlsLocked) {
                Box(modifier = Modifier.fillMaxSize().padding(24.dp)) {
                    FloatingActionButton(
                        onClick = { isControlsLocked = false },
                        containerColor = Color(0xFFF97316),
                        modifier = Modifier.align(Alignment.BottomStart)
                    ) {
                        Icon(Icons.Default.Lock, contentDescription = "Unlock Controls", tint = Color.White)
                    }
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                listOf(Color.Black.copy(alpha = 0.82f), Color.Transparent, Color.Black.copy(alpha = 0.88f))
                            )
                        )
                        .padding(horizontal = 20.dp, vertical = 16.dp),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    // Top Bar
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(onClick = {
                            repository.savePlaybackPosition(media, currentPosition, totalDuration)
                            onBack()
                        }) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
                        }

                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.weight(1f).padding(horizontal = 8.dp)
                        ) {
                            Text(media.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1)
                            Text("${media.resolution} • ${media.videoCodec} • ${media.audioSpec}", color = Color(0xFFF97316), fontSize = 11.sp, maxLines = 1)
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = {
                                refreshVlcTracks()
                                showAudioDialog = true
                            }) {
                                Icon(Icons.Default.Audiotrack, contentDescription = "Audio Tracks", tint = Color.White)
                            }
                            IconButton(onClick = {
                                refreshVlcTracks()
                                showSubtitleDialog = true
                            }) {
                                Icon(Icons.Default.Subtitles, contentDescription = "Subtitles", tint = Color.White)
                            }
                            TextButton(onClick = {
                                val speeds = listOf(0.75f, 1.0f, 1.25f, 1.5f, 2.0f)
                                val next = speeds[(speeds.indexOf(playbackSpeed) + 1) % speeds.size]
                                playbackSpeed = next
                                vlcPlayer.rate = next
                            }) {
                                Text("${playbackSpeed}x", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                            TextButton(onClick = {
                                currentScaleIdx = (currentScaleIdx + 1) % scaleTypes.size
                            }) {
                                Text(scaleLabels[currentScaleIdx], color = Color(0xFFF97316), fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                            IconButton(onClick = { showInfoDialog = true }) {
                                Icon(Icons.Default.Info, contentDescription = "Stream Info", tint = Color.White)
                            }
                        }
                    }

                    // Center Transport Controls: Previous Video | -10s | Play/Pause | +10s | Next Video
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(
                            onClick = {
                                repository.savePlaybackPosition(media, currentPosition, totalDuration)
                                onSkipPrevious()
                            },
                            enabled = hasPrevious
                        ) {
                            Icon(
                                Icons.Default.SkipPrevious,
                                contentDescription = "Previous Video",
                                tint = if (hasPrevious) Color.White else Color.White.copy(alpha = 0.3f),
                                modifier = Modifier.size(36.dp)
                            )
                        }

                        IconButton(onClick = {
                            val target = (currentPosition - 10_000L).coerceAtLeast(0L)
                            vlcPlayer.time = target
                            currentPosition = target
                        }) {
                            Icon(Icons.Default.Replay10, contentDescription = "-10s", tint = Color.White, modifier = Modifier.size(36.dp))
                        }

                        IconButton(
                            onClick = {
                                if (vlcPlayer.isPlaying) vlcPlayer.pause() else vlcPlayer.play()
                            },
                            modifier = Modifier.size(72.dp).background(Color(0xFFF97316), CircleShape)
                        ) {
                            Icon(
                                if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                                contentDescription = "Play/Pause",
                                tint = Color.White,
                                modifier = Modifier.size(38.dp)
                            )
                        }

                        IconButton(onClick = {
                            val target = (currentPosition + 10_000L).coerceAtMost(totalDuration)
                            vlcPlayer.time = target
                            currentPosition = target
                        }) {
                            Icon(Icons.Default.Forward10, contentDescription = "+10s", tint = Color.White, modifier = Modifier.size(36.dp))
                        }

                        IconButton(
                            onClick = {
                                repository.savePlaybackPosition(media, currentPosition, totalDuration)
                                onSkipNext()
                            },
                            enabled = hasNext
                        ) {
                            Icon(
                                Icons.Default.SkipNext,
                                contentDescription = "Next Video",
                                tint = if (hasNext) Color.White else Color.White.copy(alpha = 0.3f),
                                modifier = Modifier.size(36.dp)
                            )
                        }
                    }

                    // Bottom Scrubber & Lock / Rotate Controls
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Slider(
                            value = if (totalDuration > 0) (currentPosition.toFloat() / totalDuration).coerceIn(0f, 1f) else 0f,
                            onValueChange = { frac ->
                                val target = (frac * totalDuration).toLong()
                                vlcPlayer.time = target
                                currentPosition = target
                            },
                            colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = Color(0xFFF97316))
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                IconButton(onClick = { isControlsLocked = true }, modifier = Modifier.size(28.dp)) {
                                    Icon(Icons.Default.LockOpen, contentDescription = "Lock Screen", tint = Color.LightGray, modifier = Modifier.size(18.dp))
                                }
                                Text(formatMs(currentPosition), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                            }

                            Text("LibVLC Universal • ${media.audioSpec}", color = Color(0xFF38BDF8), fontSize = 11.sp, fontWeight = FontWeight.Medium)

                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(formatMs(totalDuration), color = Color.LightGray, fontSize = 12.sp)
                                IconButton(
                                    onClick = {
                                        isLandscape = !isLandscape
                                        activity?.requestedOrientation = if (isLandscape) {
                                            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                                        } else {
                                            ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                                        }
                                    },
                                    modifier = Modifier.size(28.dp)
                                ) {
                                    Icon(Icons.Default.ScreenRotation, contentDescription = "Rotate Screen", tint = Color.LightGray, modifier = Modifier.size(18.dp))
                                }
                            }
                        }
                    }
                }
            }
        }

        if (showAudioDialog) {
            AlertDialog(
                onDismissRequest = { showAudioDialog = false },
                containerColor = Color(0xFF141720),
                title = { Text("Audio Tracks (AC3 / DTS / EAC3 / AAC)", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp) },
                text = {
                    Column(
                        modifier = Modifier.heightIn(max = 260.dp).verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        if (audioTracks.isEmpty()) {
                            Text("Default Audio Stream Active (${media.audioSpec})", color = Color.LightGray, fontSize = 13.sp)
                        } else {
                            audioTracks.forEach { track ->
                                Card(
                                    colors = CardDefaults.cardColors(
                                        containerColor = if (track.isSelected) Color(0x33F97316) else Color(0xFF1E222D)
                                    ),
                                    modifier = Modifier.fillMaxWidth().clickable {
                                        vlcPlayer.setAudioTrack(track.id)
                                        refreshVlcTracks()
                                        showAudioDialog = false
                                    }
                                ) {
                                    Row(
                                        modifier = Modifier.padding(12.dp).fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(track.name, color = if (track.isSelected) Color(0xFFF97316) else Color.White, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                                        if (track.isSelected) {
                                            Icon(Icons.Default.Check, contentDescription = null, tint = Color(0xFFF97316), modifier = Modifier.size(18.dp))
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showAudioDialog = false }) {
                        Text("Done", color = Color(0xFFF97316))
                    }
                }
            )
        }

        if (showSubtitleDialog) {
            AlertDialog(
                onDismissRequest = { showSubtitleDialog = false },
                containerColor = Color(0xFF141720),
                title = { Text("Subtitles & External .SRT / .ASS", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp) },
                text = {
                    Column(
                        modifier = Modifier.heightIn(max = 280.dp).verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = { subtitleFilePicker.launch(arrayOf("*/*")) },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF97316)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.FolderOpen, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Load External Subtitle File (.SRT / .ASS)", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }

                        Card(
                            colors = CardDefaults.cardColors(containerColor = Color(0xFF1E222D)),
                            modifier = Modifier.fillMaxWidth().clickable {
                                vlcPlayer.setSpuTrack(-1)
                                refreshVlcTracks()
                                showSubtitleDialog = false
                            }
                        ) {
                            Row(modifier = Modifier.padding(12.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Disable Subtitles (Off)", color = Color.LightGray, fontSize = 13.sp)
                            }
                        }

                        subtitleTracks.forEach { track ->
                            Card(
                                colors = CardDefaults.cardColors(
                                    containerColor = if (track.isSelected) Color(0x33F97316) else Color(0xFF1E222D)
                                ),
                                modifier = Modifier.fillMaxWidth().clickable {
                                    vlcPlayer.setSpuTrack(track.id)
                                    refreshVlcTracks()
                                    showSubtitleDialog = false
                                }
                            ) {
                                Row(
                                    modifier = Modifier.padding(12.dp).fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(track.name, color = if (track.isSelected) Color(0xFFF97316) else Color.White, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                                    if (track.isSelected) {
                                        Icon(Icons.Default.Check, contentDescription = null, tint = Color(0xFFF97316), modifier = Modifier.size(18.dp))
                                    }
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showSubtitleDialog = false }) {
                        Text("Close", color = Color(0xFFF97316))
                    }
                }
            )
        }

        if (showInfoDialog) {
            AlertDialog(
                onDismissRequest = { showInfoDialog = false },
                containerColor = Color(0xFF141720),
                title = { Text("Technical Format & Stream Inspector", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("File: ${media.rawFilename}", color = Color.White, fontSize = 12.sp)
                        Text("Container: ${media.container}", color = Color.LightGray, fontSize = 12.sp)
                        Text("Video Codec: ${media.videoCodec} • ${media.hdrFormat}", color = Color(0xFFF97316), fontSize = 12.sp)
                        Text("Resolution: ${media.resolution} (${media.qualityTag}) @ ${media.frameRate}", color = Color.White, fontSize = 12.sp)
                        Text("Audio Track: ${media.audioSpec} (${media.audioDetails})", color = Color(0xFF38BDF8), fontSize = 12.sp)
                        Text("Bitrate & Size: ${media.bitrate} • ${media.fileSize}", color = Color.LightGray, fontSize = 12.sp)
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showInfoDialog = false }) {
                        Text("Close", color = Color(0xFFF97316))
                    }
                }
            )
        }
    }
}

@Composable
fun HudBar(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: Float,
    label: String,
    color: Color
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Black.copy(alpha = 0.82f))
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
            Box(
                modifier = Modifier.width(6.dp).height(110.dp).background(Color.White.copy(alpha = 0.2f), RoundedCornerShape(3.dp)),
                contentAlignment = Alignment.BottomCenter
            ) {
                Box(modifier = Modifier.fillMaxWidth().fillMaxHeight(value).background(color, RoundedCornerShape(3.dp)))
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
EOF

cat << 'EOF' > app/src/main/java/com/infuse/player/MainActivity.kt
package com.infuse.player

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.repository.MediaRepository
import com.infuse.player.ui.library.LibraryScreen
import com.infuse.player.ui.player.PlayerScreen
import com.infuse.player.ui.theme.InfuseTheme

class MainActivity : ComponentActivity() {

    private lateinit var repository: MediaRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = MediaRepository(applicationContext)

        setContent {
            InfuseTheme {
                val mediaList by repository.mediaList.collectAsState()
                var activePlayback by remember { mutableStateOf<Pair<MediaItem, Long>?>(null) }

                BackHandler(enabled = activePlayback != null) {
                    activePlayback = null
                }

                LaunchedEffect(Unit) {
                    intent?.data?.let { externalUri ->
                        repository.addPickedVideoUri(externalUri) { item ->
                            activePlayback = item to repository.getSavedPosition(item)
                        }
                    }
                }

                val permissionLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestMultiplePermissions()
                ) {
                    repository.scanDeviceVideos()
                }

                val filePickerLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.OpenDocument()
                ) { uri ->
                    uri?.let {
                        try {
                            contentResolver.takePersistableUriPermission(
                                it,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                            )
                        } catch (_: Exception) {}
                        repository.addPickedVideoUri(it) { item ->
                            activePlayback = item to repository.getSavedPosition(item)
                        }
                    }
                }

                LaunchedEffect(Unit) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        permissionLauncher.launch(arrayOf(Manifest.permission.READ_MEDIA_VIDEO))
                    } else {
                        permissionLauncher.launch(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE))
                    }
                }

                if (activePlayback != null) {
                    val currentItem = activePlayback!!.first
                    val currentIndex = mediaList.indexOfFirst {
                        it.id == currentItem.id || it.rawFilename.equals(currentItem.rawFilename, ignoreCase = true)
                    }
                    val hasPrev = currentIndex > 0
                    val hasNext = currentIndex != -1 && currentIndex < mediaList.size - 1

                    PlayerScreen(
                        media = currentItem,
                        initialSeekMs = activePlayback!!.second,
                        hasPrevious = hasPrev,
                        hasNext = hasNext,
                        onSkipPrevious = {
                            if (hasPrev) {
                                val prevItem = mediaList[currentIndex - 1]
                                activePlayback = prevItem to repository.getSavedPosition(prevItem)
                            }
                        },
                        onSkipNext = {
                            if (hasNext) {
                                val nextItem = mediaList[currentIndex + 1]
                                activePlayback = nextItem to repository.getSavedPosition(nextItem)
                            }
                        },
                        repository = repository,
                        onBack = { activePlayback = null }
                    )
                } else {
                    LibraryScreen(
                        repository = repository,
                        onMediaSelected = { media, startPosMs ->
                            activePlayback = media to startPosMs
                        },
                        onPickLocalFile = { filePickerLauncher.launch(arrayOf("video/*", "application/octet-stream", "*/*")) },
                        onRescanStorage = { repository.scanDeviceVideos() }
                    )
                }
            }
        }
    }
}
EOF

cat << 'EOF' > gradle.properties
android.useAndroidX=true
android.nonTransitiveRClass=true
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
EOF

cat << 'EOF' > settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "InfuseAndroid"
include(":app")
EOF

cat << 'EOF' > build.gradle.kts
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.0" apply false
}
EOF

cat << 'EOF' > app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.infuse.player"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.infuse.player"
        minSdk = 26
        targetSdk = 35
        versionCode = 5
        versionName = "5.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation(platform("androidx.compose:compose-bom:2024.10.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("org.videolan.android:libvlc-all:3.6.0")
    implementation("io.coil-kt:coil-compose:2.7.0")
    implementation("com.hierynomus:smbj:0.13.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
EOF
