package com.infuse.player.data.network

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.PlaybackException
import androidx.media3.datasource.BaseDataSource
import androidx.media3.datasource.DataSpec
import com.hierynomus.msdtyp.AccessMask
import com.hierynomus.mssmb2.SMB2CreateDisposition
import com.hierynomus.mssmb2.SMB2ShareAccess
import com.hierynomus.smbj.SMBClient
import com.hierynomus.smbj.auth.AuthenticationContext
import com.hierynomus.smbj.connection.Connection
import com.hierynomus.smbj.session.Session
import com.hierynomus.smbj.share.DiskShare
import com.hierynomus.smbj.share.File
import java.io.IOException
import java.io.InputStream
import java.util.EnumSet

/**
 * Custom Media3 / ExoPlayer DataSource for direct streaming from SMBv2/v3 shares without downloading.
 * Supports byte-range requests for instant seeking in multi-gigabyte 4K/HDR files.
 */
class SmbDataSource(
    private val credentialsProvider: (Uri) -> AuthenticationContext? = { null }
) : BaseDataSource(/* isNetwork = */ true) {

    private var client: SMBClient? = null
    private var connection: Connection? = null
    private var session: Session? = null
    private var share: DiskShare? = null
    private var file: File? = null
    private var inputStream: InputStream? = null
    private var dataSpec: DataSpec? = null
    private var bytesRemaining: Long = 0

    override fun open(dataSpec: DataSpec): Long {
        this.dataSpec = dataSpec
        transferInitializing(dataSpec)

        val uri = dataSpec.uri
        val host = uri.host ?: throw PlaybackException("Missing SMB host", null, PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS)
        val port = if (uri.port != -1) uri.port else 445
        val pathSegments = uri.pathSegments
        if (pathSegments.size < 2) {
            throw PlaybackException("Invalid SMB path: share name and file path required", null, PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND)
        }
        val shareName = pathSegments[0]
        val filePath = pathSegments.drop(1).joinToString("\\")

        try {
            client = SMBClient()
            connection = client?.connect(host, port)
            val auth = credentialsProvider(uri) ?: AuthenticationContext.anonymous()
            session = connection?.authenticate(auth)
            share = session?.connectShare(shareName) as? DiskShare
                ?: throw IOException("Target is not a disk share: $shareName")

            file = share?.openFile(
                filePath,
                EnumSet.of(AccessMask.FILE_READ_DATA),
                null,
                SMB2ShareAccess.ALL,
                SMB2CreateDisposition.FILE_OPEN,
                null
            )

            val fileLength = file?.fileInformation?.standardInformation?.endOfFile ?: C.LENGTH_UNSET.toLong()
            val position = dataSpec.position
            if (position > fileLength && fileLength != C.LENGTH_UNSET.toLong()) {
                throw PlaybackException("Position out of bounds", null, PlaybackException.ERROR_CODE_IO_READ_POSITION_OUT_OF_RANGE)
            }

            bytesRemaining = if (dataSpec.length != C.LENGTH_UNSET.toLong()) {
                dataSpec.length
            } else {
                fileLength - position
            }

            val rawStream = file?.inputStream
            rawStream?.skip(position)
            inputStream = rawStream

            transferStarted(dataSpec)
            return bytesRemaining
        } catch (e: Exception) {
            throw PlaybackException("SMB connection failed: ${e.message}", e, PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED)
        }
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) return 0
        if (bytesRemaining == 0L) return C.RESULT_END_OF_INPUT

        val bytesToRead = if (bytesRemaining == C.LENGTH_UNSET.toLong()) length else minOf(bytesRemaining, length.toLong()).toInt()
        val bytesRead = inputStream?.read(buffer, offset, bytesToRead) ?: -1
        if (bytesRead == -1) {
            return C.RESULT_END_OF_INPUT
        }

        if (bytesRemaining != C.LENGTH_UNSET.toLong()) {
            bytesRemaining -= bytesRead
        }
        bytesTransferred(bytesRead)
        return bytesRead
    }

    override fun getUri(): Uri? = dataSpec?.uri

    override fun close() {
        try {
            inputStream?.close()
            file?.close()
            share?.close()
            session?.close()
            connection?.close()
            client?.close()
        } catch (e: Exception) {
            // Log cleanup safely
        } finally {
            inputStream = null
            file = null
            share = null
            session = null
            connection = null
            client = null
            if (dataSpec != null) {
                transferEnded()
                dataSpec = null
            }
        }
    }
}
