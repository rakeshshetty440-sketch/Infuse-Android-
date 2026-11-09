package com.infuse.player.data.scraper

/**
 * Intelligent media filename cleaner for Infuse-style automatic library organization.
 * Extracts clean titles, release years, and TV episode markers from raw scene filenames.
 */
object FilenameParser {

    private val TV_EPISODE_REGEX = Regex("(?i)[._ -]S(\\d{1,2})[._ -]?E(\\d{1,3})")
    private val YEAR_REGEX = Regex("[._ -]\\(?((?:19|20)\\d{2})\\)?")
    private val SCENE_TAGS = listOf(
        "2160p", "1080p", "720p", "480p", "4k", "uhd", "hdr", "hdr10", "hdr10plus", "dv", "dovi",
        "remux", "bluray", "bdrip", "web-dl", "webrip", "hdtv", "dvdrip",
        "x264", "x265", "h264", "h265", "hevc", "av1", "10bit",
        "truehd", "atmos", "dts-hd", "dts", "ac3", "eac3", "ddp5.1", "aac", "flac"
    )

    data class ParsedMediaInfo(
        val cleanTitle: String,
        val year: Int?,
        val isTvShow: Boolean,
        val season: Int? = null,
        val episode: Int? = null
    )

    fun parse(rawFilename: String): ParsedMediaInfo {
        var name = rawFilename.substringBeforeLast(".") // Strip extension

        // Check for TV Show pattern (e.g. S01E02)
        val tvMatch = TV_EPISODE_REGEX.find(name)
        if (tvMatch != null) {
            val season = tvMatch.groupValues[1].toIntOrNull()
            val episode = tvMatch.groupValues[2].toIntOrNull()
            val titlePart = name.substring(0, tvMatch.range.first)
                .replace(Regex("[._-]"), " ")
                .trim()
            return ParsedMediaInfo(cleanTitle = cleanName(titlePart), year = null, isTvShow = true, season = season, episode = episode)
        }

        // Check for release year (e.g. Inception.2010.1080p)
        val yearMatch = YEAR_REGEX.find(name)
        var year: Int? = null
        var titlePart = name
        if (yearMatch != null) {
            year = yearMatch.groupValues[1].toIntOrNull()
            titlePart = name.substring(0, yearMatch.range.first)
        }

        // Clean scene tags & formatting dots
        val cleanTitle = cleanName(titlePart)
        return ParsedMediaInfo(cleanTitle = cleanTitle, year = year, isTvShow = false)
    }

    private fun cleanName(raw: String): String {
        var str = raw.replace(Regex("[._\\[\\]()]"), " ").trim()
        SCENE_TAGS.forEach { tag ->
            str = str.replace(Regex("(?i)\\b$tag\\b"), "")
        }
        return str.replace(Regex("\\s+"), " ").trim()
    }
}
