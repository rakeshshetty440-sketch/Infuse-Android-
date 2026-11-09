package com.infuse.player.data.scraper

import com.infuse.player.data.model.MediaItem
import com.infuse.player.data.model.MediaType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.URLEncoder

/**
 * TMDb metadata scraper that pulls official movie/show posters, plot synopses, and ratings.
 */
class TmdbScraperService(
    private val apiKey: String = "f52f0d6c1b1784ece4eed64ff99052ac",
    private val client: OkHttpClient = OkHttpClient()
) {
    private val tmdbBaseUrl = "https://api.themoviedb.org/3"
    private val imageBaseUrl = "https://image.tmdb.org/t/p"

    suspend fun scrape(rawFilename: String, fileStreamUri: String): MediaItem = withContext(Dispatchers.IO) {
        val parsed = FilenameParser.parse(rawFilename)
        val query = URLEncoder.encode(parsed.cleanTitle, "UTF-8")
        val endpoint = if (parsed.isTvShow) "search/tv" else "search/movie"
        val yearParam = if (parsed.year != null && !parsed.isTvShow) "&year=${parsed.year}" else ""
        val url = "$tmdbBaseUrl/$endpoint?api_key=$apiKey&query=$query$yearParam"

        try {
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw Exception("TMDb API response code: ${response.code}")
                val json = JSONObject(response.body?.string() ?: "{}")
                val results = json.optJSONArray("results")

                if (results != null && results.length() > 0) {
                    val first = results.getJSONObject(0)
                    val title = if (parsed.isTvShow) first.optString("name", parsed.cleanTitle) else first.optString("title", parsed.cleanTitle)
                    val posterPath = first.optString("poster_path")
                    val backdropPath = first.optString("backdrop_path")
                    val overview = first.optString("overview", "No plot description available.")
                    val voteAverage = first.optDouble("vote_average", 7.5)
                    val releaseDate = if (parsed.isTvShow) first.optString("first_air_date") else first.optString("release_date")
                    val year = releaseDate.take(4).toIntOrNull() ?: parsed.year ?: 2026

                    return@withContext MediaItem(
                        id = "tmdb_${first.optLong("id")}",
                        title = title,
                        year = year,
                        type = if (parsed.isTvShow) MediaType.TV_SHOW else MediaType.MOVIE,
                        durationText = "2h 15m",
                        durationSeconds = 8100,
                        rating = String.format("%.1f", voteAverage),
                        qualityTag = "4K HDR",
                        audioSpec = "TrueHD Atmos 7.1",
                        videoCodec = "HEVC 2160p",
                        container = rawFilename.substringAfterLast(".").uppercase(),
                        bitrate = "42.0 Mbps",
                        fileSize = "34.5 GB",
                        streamUri = fileStreamUri,
                        posterUrl = if (posterPath.isNotEmpty()) "$imageBaseUrl/w500$posterPath" else "",
                        backdropUrl = if (backdropPath.isNotEmpty()) "$imageBaseUrl/original$backdropPath" else "",
                        synopsis = overview,
                        audioTracks = listOf("English (TrueHD Atmos 7.1)", "English (AC3 5.1)"),
                        subtitles = listOf("English [SDH]", "None")
                    )
                }
            }
        } catch (e: Exception) {
            // Fallback to local parsed info if offline or key missing
        }

        // Offline / Fallback Record
        MediaItem(
            id = "local_${rawFilename.hashCode()}",
            title = parsed.cleanTitle,
            year = parsed.year ?: 2026,
            type = if (parsed.isTvShow) MediaType.TV_SHOW else MediaType.MOVIE,
            durationText = "Unknown",
            durationSeconds = 7200,
            rating = "N/A",
            qualityTag = "Direct Play",
            audioSpec = "Auto Detect",
            videoCodec = "Direct",
            container = rawFilename.substringAfterLast(".").uppercase(),
            bitrate = "--",
            fileSize = "--",
            streamUri = fileStreamUri,
            posterUrl = "",
            backdropUrl = "",
            synopsis = "Local stream parsed from filename: $rawFilename"
        )
    }
}
