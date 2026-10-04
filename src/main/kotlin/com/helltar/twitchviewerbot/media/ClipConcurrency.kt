package com.helltar.twitchviewerbot.media

import com.helltar.twitchviewerbot.Config
import io.github.oshai.kotlinlogging.KotlinLogging
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

// process-wide limit on simultaneous recordings: every clip spawns streamlink + ffmpeg and buffers up to ~100 MB,
// so without a global cap many users pressing /clip at once can exhaust CPU, memory and /tmp
object ClipConcurrency {

    private val log = KotlinLogging.logger {}

    val maxConcurrent: Int = Config.maxConcurrentClips
    private val semaphore = Semaphore(maxConcurrent)

    suspend fun <T> withSlot(userId: Long, block: suspend () -> T): T {
        if (semaphore.availablePermits == 0)
            log.info { "all $maxConcurrent clip slots busy, user-$userId is queued" }

        return semaphore.withPermit { block() }
    }
}
