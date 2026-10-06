package com.helltar.twitchviewerbot.database

import com.helltar.twitchviewerbot.DatabaseConfig
import com.helltar.twitchviewerbot.database.tables.UserChannelsTable
import com.helltar.twitchviewerbot.database.tables.UsersTable
import io.github.oshai.kotlinlogging.KotlinLogging
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jetbrains.exposed.v1.jdbc.JdbcTransaction
import org.jetbrains.exposed.v1.jdbc.SchemaUtils
import org.jetbrains.exposed.v1.jdbc.transactions.transaction
import java.io.File
import org.jetbrains.exposed.v1.jdbc.Database as ExposedDatabase

object Database {

    private val log = KotlinLogging.logger {}

    private lateinit var database: ExposedDatabase

    fun init(config: DatabaseConfig) {
        val file = File(config.path).absoluteFile
        file.parentFile?.mkdirs()

        database =
            ExposedDatabase.connect(
                url = "jdbc:sqlite:${file.path}",
                driver = "org.sqlite.JDBC",
                // runs on every new connection, before Exposed opens a transaction on it
                setupConnection = { connection ->
                    connection.createStatement().use { statement ->
                        statement.execute("PRAGMA journal_mode = WAL") // readers don't block the writer
                        statement.execute("PRAGMA synchronous = NORMAL") // safe with WAL, far fewer fsyncs
                        statement.execute("PRAGMA foreign_keys = ON") // SQLite ignores FKs (ON DELETE CASCADE) unless enabled
                        statement.execute("PRAGMA busy_timeout = 5000") // wait for a concurrent writer instead of failing
                    }
                }
            )

        // creates only the tables that don't exist yet; new columns later need an explicit migration
        transaction(database) {
            SchemaUtils.create(UsersTable, UserChannelsTable)
        }

        log.info { "SQLite database: ${file.path}" }
    }

    suspend fun <T> dbTransaction(block: JdbcTransaction.() -> T): T =
        withContext(Dispatchers.IO) {
            transaction(database) { block() }
        }
}
