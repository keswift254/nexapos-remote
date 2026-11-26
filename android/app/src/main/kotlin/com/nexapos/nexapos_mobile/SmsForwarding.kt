package com.nexapos.nexapos_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * This phone passes the till's M-Pesa / bank payment messages on to the shop, like the iPhone Shortcut does
 * (Settings > M-Pesa Till Phone). Kept here, outside Flutter, because a message must be passed on even when NexaPOS
 * is closed: Android starts [PaymentSmsReceiver] for every text message, and a [ForwardPaymentSmsWorker] sends it
 * once there is internet, trying again later when the shop cannot be reached.
 */
object SmsForwardingStore {
    private const val PREFS = "nexapos_sms_forwarding"
    const val WORK_TAG = "nexapos-payment-sms"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean("enabled", false)
    fun key(context: Context): String? = prefs(context).getString("key", null)
    fun address(context: Context): String? = prefs(context).getString("address", null)

    fun enable(context: Context, key: String, address: String) {
        prefs(context).edit()
            .putBoolean("enabled", true)
            .putString("key", key)
            .putString("address", address)
            .remove("lastResult")
            .commit()
    }

    fun disable(context: Context) {
        prefs(context).edit().putBoolean("enabled", false).commit()
        WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
    }

    fun record(context: Context, sender: String, result: String) {
        val p = prefs(context)
        p.edit()
            .putLong("lastAt", System.currentTimeMillis())
            .putString("lastSender", sender)
            .putString("lastResult", result)
            .putInt("passedOn", p.getInt("passedOn", 0) + if (result == "recorded" || result == "already_have_it") 1 else 0)
            .commit()
    }

    fun snapshot(context: Context): Map<String, Any?> {
        val p = prefs(context)
        val key = p.getString("key", null)
        return mapOf(
            "enabled" to p.getBoolean("enabled", false),
            "keyEnd" to key?.takeLast(4),
            "address" to p.getString("address", null),
            "lastAt" to (if (p.contains("lastAt")) p.getLong("lastAt", 0) else null),
            "lastSender" to p.getString("lastSender", null),
            "lastResult" to p.getString("lastResult", null),
            "passedOn" to p.getInt("passedOn", 0),
        )
    }
}

/** Every text message: if passing on is switched on and the message is a payment from a named sender, queue it. */
class PaymentSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!SmsForwardingStore.isEnabled(context)) return
        val messages = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        } catch (e: Exception) {
            return
        }
        // A long message arrives in parts; put each sender's parts back together, in order.
        val bySender = linkedMapOf<String, MutableList<String?>>()
        for (message in messages) {
            val sender = message?.originatingAddress ?: continue
            bySender.getOrPut(sender) { mutableListOf() }.add(message.messageBody)
        }
        for ((sender, parts) in bySender) {
            val text = SmsForwardRules.joinParts(parts)
            if (!SmsForwardRules.shouldForward(sender, text)) continue
            ForwardPaymentSmsWorker.enqueue(context, sender, text)
        }
    }
}

/** Sends one message to the shop; waits for internet, and tries again later (up to about a day) when it cannot. */
class ForwardPaymentSmsWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val context = applicationContext
        val sender = inputData.getString("sender") ?: return Result.failure()
        val text = inputData.getString("text") ?: return Result.failure()
        if (!SmsForwardingStore.isEnabled(context)) return Result.failure()
        val key = SmsForwardingStore.key(context) ?: return Result.failure()
        val address = SmsForwardingStore.address(context) ?: return Result.failure()

        val answer = PaymentSmsSender.send(address, key, sender, text)
        val status = answer.status
        val reason = answer.reason

        return when (SmsForwardRules.outcomeOf(status)) {
            SmsForwardRules.Outcome.DONE -> {
                SmsForwardingStore.record(context, sender, reason.ifEmpty { "recorded" })
                Result.success()
            }
            SmsForwardRules.Outcome.KEY_REFUSED -> {
                SmsForwardingStore.record(context, sender, "key_refused")
                Result.failure()
            }
            SmsForwardRules.Outcome.REFUSED -> {
                SmsForwardingStore.record(context, sender, "refused_$status")
                Result.failure()
            }
            SmsForwardRules.Outcome.TRY_AGAIN -> {
                if (runAttemptCount >= MAX_ATTEMPTS) {
                    SmsForwardingStore.record(context, sender, "gave_up")
                    Result.failure()
                } else {
                    SmsForwardingStore.record(context, sender, "waiting")
                    Result.retry()
                }
            }
        }
    }

    companion object {
        // With exponential back-off from 30 seconds (capped by WorkManager at 5 hours) this is well over a day.
        private const val MAX_ATTEMPTS = 20

        fun enqueue(context: Context, sender: String, text: String) {
            val request = OneTimeWorkRequestBuilder<ForwardPaymentSmsWorker>()
                .setInputData(Data.Builder().putString("sender", sender).putString("text", text).build())
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .addTag(SmsForwardingStore.WORK_TAG)
                .build()
            WorkManager.getInstance(context).enqueue(request)
        }
    }
}
