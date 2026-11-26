package com.nexapos.nexapos_mobile

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.net.InetAddress
import java.net.ServerSocket
import kotlin.concurrent.thread

/** What the phone sends to the shop for one payment message, and what it makes of the answer (PaymentSmsSender). */
class PaymentSmsSenderTest {
    private var server: ServerSocket? = null
    @Volatile private var gotMethod = ""
    @Volatile private var gotType = ""
    @Volatile private var gotBody = ""

    /** A one-request web server on plain sockets (Android's unit tests do not see the JDK's own). */
    private fun serve(status: Int, answer: String): String {
        val socket = ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))
        server = socket
        thread(isDaemon = true) {
            socket.accept().use { client ->
                val input = client.getInputStream()
                fun line(): String {
                    val bytes = ByteArrayOutputStream()
                    while (true) {
                        val b = input.read()
                        if (b < 0 || b == LF) break
                        if (b != CR) bytes.write(b)
                    }
                    return bytes.toString("UTF-8")
                }
                gotMethod = line().substringBefore(' ')
                var length = 0
                while (true) {
                    val header = line()
                    if (header.isEmpty()) break
                    val name = header.substringBefore(':').trim().lowercase()
                    val value = header.substringAfter(':').trim()
                    if (name == "content-type") gotType = value
                    if (name == "content-length") length = value.toInt()
                }
                val body = ByteArray(length)
                var read = 0
                while (read < length) {
                    val n = input.read(body, read, length - read)
                    if (n < 0) break
                    read += n
                }
                gotBody = String(body, 0, read, Charsets.UTF_8)
                val bytes = answer.toByteArray(Charsets.UTF_8)
                val head = "HTTP/1.1 $status X" + CRLF + "Content-Type: application/json" + CRLF +
                    "Content-Length: ${bytes.size}" + CRLF + "Connection: close" + CRLF + CRLF
                client.getOutputStream().apply {
                    write(head.toByteArray(Charsets.US_ASCII))
                    write(bytes)
                    flush()
                }
            }
        }
        return "http://127.0.0.1:${socket.localPort}/index.php?action=payment_inbox_ingest"
    }

    @After
    fun stop() {
        server?.close()
    }

    @Test
    fun sendsTheKeyTheTextAndTheSenderAsJson() {
        val address = serve(200, """{"success":true,"recorded":true,"reason":"recorded"}""")
        val answer = PaymentSmsSender.send(address, "npk_abc", "MPESA", "TKJ7Q2X9AB Confirmed. Ksh500.00 received")
        assertEquals("POST", gotMethod)
        assertEquals("application/json", gotType)
        assertEquals("""{"key":"npk_abc","text":"TKJ7Q2X9AB Confirmed. Ksh500.00 received","sender":"MPESA"}""", gotBody)
        assertEquals(PaymentSmsSender.Answer(200, "recorded"), answer)
    }

    @Test
    fun aRefusalIsReportedWithItsStatus() {
        val address = serve(401, """{"success":false,"message":"Unknown key"}""")
        assertEquals(PaymentSmsSender.Answer(401, ""), PaymentSmsSender.send(address, "npk_bad", "MPESA", "x"))
        assertEquals(SmsForwardRules.Outcome.KEY_REFUSED, SmsForwardRules.outcomeOf(401))
    }

    @Test
    fun noShopToReachIsTryAgainLater() {
        val free = ServerSocket(0).use { it.localPort } // a port nobody listens on any more
        val answer = PaymentSmsSender.send("http://127.0.0.1:$free/index.php", "npk_abc", "MPESA", "x", timeoutMs = 3000)
        assertNull(answer.status)
        assertEquals(SmsForwardRules.Outcome.TRY_AGAIN, SmsForwardRules.outcomeOf(answer.status))
    }

    @Test
    fun theTextIsSentExactlyAsWrittenInValidJson() {
        assertEquals("\"plain\"", PaymentSmsSender.quote("plain"))
        assertEquals("\"say \\\"hi\\\"\"", PaymentSmsSender.quote("say \"hi\""))
        assertEquals("\"a\\\\b\"", PaymentSmsSender.quote("a\\b"))
        assertEquals("\"line1\\nline2\\r\\ttab\"", PaymentSmsSender.quote("line1\nline2\r\ttab"))
        assertEquals("\"\\u0001\"", PaymentSmsSender.quote("\u0001"))
        assertEquals("\"Ksh1,000 · O'Brien ✓\"", PaymentSmsSender.quote("Ksh1,000 · O'Brien ✓"))
    }

    @Test
    fun theReasonIsReadFromTheAnswer() {
        assertEquals("already_have_it", PaymentSmsSender.reasonOf("""{"success":true,"recorded":false,"reason":"already_have_it"}"""))
        assertEquals("", PaymentSmsSender.reasonOf("not json"))
    }

    /**
     * Against a REAL shop server (the local test copy), with a real till-phone key: run with
     * NEXAPOS_RIG_INGEST=http://127.0.0.1:8095/index.php?action=payment_inbox_ingest and NEXAPOS_RIG_KEY=npk_…
     * Skipped otherwise.
     */
    @Test
    fun aRealShopServerRecordsAPaymentOnceAndRefusesTheRest() {
        val address = System.getenv("NEXAPOS_RIG_INGEST")
        val key = System.getenv("NEXAPOS_RIG_KEY")
        assumeTrue("no test server given", !address.isNullOrBlank() && !key.isNullOrBlank())
        val code = "T" + (1..9).map { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".random() }.joinToString("")
        val payment = "$code Confirmed. on 25/11/26 at 2:15 PM Ksh750.00 received from 254712345678 JOHN DOE. New Account balance is Ksh10,500.00."
        println("payment code: $code")

        assertEquals(true, SmsForwardRules.shouldForward("MPESA", payment))
        assertEquals(PaymentSmsSender.Answer(200, "recorded"), PaymentSmsSender.send(address!!, key!!, "MPESA", payment))
        assertEquals(PaymentSmsSender.Answer(200, "already_have_it"), PaymentSmsSender.send(address, key, "MPESA", payment))
        assertEquals(200, PaymentSmsSender.send(address, key, "MPESA", "Your M-PESA PIN has been changed.").status)
        assertEquals(401, PaymentSmsSender.send(address, "npk_0000000000000000000000000000000000000000000000ff", "MPESA", payment).status)
    }

    private companion object {
        const val LF = 10
        const val CR = 13
        const val CRLF = "\r\n"
    }
}
