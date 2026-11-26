package com.nexapos.nexapos_mobile

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Sends one payment message to the shop, exactly as the iPhone Shortcut does: a JSON POST of key, text and sender to
 * the shop's payment_inbox_ingest address. Plain JVM code (no Android types, no org.json), so it is tested on this PC
 * against a real server; ForwardPaymentSmsWorker calls it and decides from the answer whether to try again.
 */
object PaymentSmsSender {
    /** [status]: the HTTP status, or null when the shop could not be reached. [reason]: the shop's word, if any. */
    data class Answer(val status: Int?, val reason: String)

    fun send(address: String, key: String, sender: String, text: String, timeoutMs: Int = 20_000): Answer {
        return try {
            val connection = URL(address).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = timeoutMs
                connection.readTimeout = timeoutMs
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                connection.outputStream.use { it.write(body(key, text, sender).toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val answer = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                Answer(status, reasonOf(answer))
            } finally {
                connection.disconnect()
            }
        } catch (e: IOException) {
            Answer(null, "")
        } catch (e: ClassCastException) {
            Answer(null, "")
        }
    }

    /** The JSON the shop expects: {"key":…,"text":…,"sender":…}. */
    fun body(key: String, text: String, sender: String): String =
        "{\"key\":${quote(key)},\"text\":${quote(text)},\"sender\":${quote(sender)}}"

    /** A JSON string: quotes, backslashes and control characters escaped; everything else (Ksh, names, emoji) as is. */
    fun quote(value: String): String {
        val out = StringBuilder(value.length + 2).append('"')
        for (c in value) {
            when {
                c == '"' -> out.append("\\\"")
                c == '\\' -> out.append("\\\\")
                c == '\n' -> out.append("\\n")
                c == '\r' -> out.append("\\r")
                c == '\t' -> out.append("\\t")
                c < ' ' -> out.append(String.format("\\u%04x", c.code))
                else -> out.append(c)
            }
        }
        return out.append('"').toString()
    }

    /** The "reason" in the shop's answer, or "". */
    fun reasonOf(answer: String): String =
        Regex("\"reason\"\\s*:\\s*\"([^\"]*)\"").find(answer)?.groupValues?.get(1).orEmpty()
}

/**
 * The plain rules of passing the till's payment messages on (no Android types, so they are unit-tested on the JVM).
 *
 * The phone passes on what the iPhone Shortcut passes on: a message from a NAMED sender (MPESA, a bank - never a phone
 * number, so nobody can forward a fake payment text from their own phone, and personal messages never leave the
 * phone) that mentions money the way those senders do ("Ksh", "KES") or says "Confirmed" (M-Pesa and Equity both do).
 * The server then keeps only real payments received.
 */
object SmsForwardRules {
    private val moneyWords = listOf("ksh", "kes", "confirmed")
    private val separators = Regex("[\\s\\u00A0\\-()./]+")
    private val phoneNumber = Regex("^\\+?\\d{7,15}$")

    /** Whether a message from [sender] with [text] is passed on to the shop. */
    fun shouldForward(sender: String?, text: String?): Boolean {
        val from = sender?.trim().orEmpty()
        val body = text?.trim().orEmpty()
        if (from.isEmpty() || body.isEmpty()) return false
        if (fromPerson(from)) return false
        val lower = body.lowercase()
        return moneyWords.any { lower.contains(it) }
    }

    /**
     * A person's phone number (7 to 15 digits, maybe a +, spaces and dashes ignored) or an e-mail address - the same
     * rule as the shop's server (MpesaSms::fromPerson), so a message the server would refuse never leaves the phone.
     * Short codes (5 digits) and named senders (MPESA, Equity Bank) are not people.
     */
    fun fromPerson(sender: String): Boolean {
        val trimmed = sender.trim()
        if (trimmed.contains('@')) return true
        return phoneNumber.matches(trimmed.replace(separators, ""))
    }

    /** One message from the parts Android delivers (a long M-Pesa message comes in several), in order. */
    fun joinParts(parts: List<String?>): String = parts.joinToString(separator = "") { it.orEmpty() }

    /** What to do after the shop answered [status] (an HTTP status, or null when it could not be reached). */
    fun outcomeOf(status: Int?): Outcome = when {
        status == null -> Outcome.TRY_AGAIN
        status in 200..299 -> Outcome.DONE
        status == 401 || status == 403 -> Outcome.KEY_REFUSED
        status == 408 || status == 429 || status >= 500 -> Outcome.TRY_AGAIN
        else -> Outcome.REFUSED
    }

    /** Accepts the till-phone key itself, or the set-up link (…#k=KEY) the PC shows; null when neither. */
    fun keyFrom(input: String?): String? {
        val text = input?.trim().orEmpty()
        val match = Regex("npk_[0-9a-fA-F]{16,128}").find(text) ?: return null
        return match.value
    }

    enum class Outcome { DONE, TRY_AGAIN, KEY_REFUSED, REFUSED }
}
