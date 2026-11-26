package com.nexapos.nexapos_mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The rules the phone uses to decide what leaves it (see SmsForwardRules). */
class SmsForwardRulesTest {
    private val mpesaTill =
        "TKJ7Q2X9AB Confirmed. on 25/11/26 at 2:15 PM Ksh500.00 received from 254712345678 JOHN DOE. New Account balance is Ksh10,500.00."
    private val mpesaPersonal =
        "TKJ7Q2X9AC Confirmed. You have received Ksh250.00 from JANE WANJIKU 0712345678 on 25/11/26 at 2:16 PM New M-PESA balance is Ksh1,200.00."
    private val equity = "Confirmed KES 10.00 received from JOHN DOE 0712345678 Ref TKJ7Q2X9AD on 25/11/26 2:17 PM. Thank you."

    @Test
    fun paymentMessagesFromNamedSendersArePassedOn() {
        assertTrue(SmsForwardRules.shouldForward("MPESA", mpesaTill))
        assertTrue(SmsForwardRules.shouldForward("MPESA", mpesaPersonal))
        assertTrue(SmsForwardRules.shouldForward("Equity Bank", equity))
        assertTrue(SmsForwardRules.shouldForward("Co-opBank", "You have received Ksh 300.00 from JOHN DOE Ref ABC123XYZ"))
        assertTrue(SmsForwardRules.shouldForward("40100", "Ksh 700.00 received. Ref QWE123RTY"), "a bank short code is not a person")
    }

    @Test
    fun messagesFromPeopleNeverLeaveThePhone() {
        // Exactly the trick the shop worried about: a copied M-Pesa text forwarded from someone's own phone.
        for (sender in listOf("+254712345678", "254712345678", "0712345678", "0712 345 678", "0712-345-678", "(0712) 345.678", "someone@example.com")) {
            assertFalse(sender, SmsForwardRules.shouldForward(sender, mpesaTill))
            assertTrue(sender, SmsForwardRules.fromPerson(sender))
        }
        assertFalse(SmsForwardRules.fromPerson("MPESA"))
        assertFalse(SmsForwardRules.fromPerson("22522"))
    }

    @Test
    fun messagesWithoutMoneyAreNotPassedOn() {
        assertFalse(SmsForwardRules.shouldForward("MPESA", "Your M-PESA PIN has been changed successfully."))
        assertFalse(SmsForwardRules.shouldForward("Safaricom", "Dear customer, your data bundle expires today."))
        assertFalse(SmsForwardRules.shouldForward("MPESA", ""))
        assertFalse(SmsForwardRules.shouldForward("", mpesaTill))
        assertFalse(SmsForwardRules.shouldForward(null, mpesaTill))
        assertFalse(SmsForwardRules.shouldForward("MPESA", null))
    }

    @Test
    fun moneyWordsAreFoundInAnyCase() {
        assertTrue(SmsForwardRules.shouldForward("MPESA", "CONFIRMED. KSH50 RECEIVED"))
        assertTrue(SmsForwardRules.shouldForward("MPESA", "confirmed. you have received kes50"))
    }

    @Test
    fun aLongMessageIsPutBackTogetherInOrder() {
        assertEquals("abcdef", SmsForwardRules.joinParts(listOf("ab", "cd", "ef")))
        assertEquals("abef", SmsForwardRules.joinParts(listOf("ab", null, "ef")))
    }

    @Test
    fun theShopsAnswerDecidesWhatHappensNext() {
        assertEquals(SmsForwardRules.Outcome.TRY_AGAIN, SmsForwardRules.outcomeOf(null))
        assertEquals(SmsForwardRules.Outcome.DONE, SmsForwardRules.outcomeOf(200))
        assertEquals(SmsForwardRules.Outcome.DONE, SmsForwardRules.outcomeOf(201))
        assertEquals(SmsForwardRules.Outcome.KEY_REFUSED, SmsForwardRules.outcomeOf(401))
        assertEquals(SmsForwardRules.Outcome.KEY_REFUSED, SmsForwardRules.outcomeOf(403))
        assertEquals(SmsForwardRules.Outcome.TRY_AGAIN, SmsForwardRules.outcomeOf(500))
        assertEquals(SmsForwardRules.Outcome.TRY_AGAIN, SmsForwardRules.outcomeOf(503))
        assertEquals(SmsForwardRules.Outcome.TRY_AGAIN, SmsForwardRules.outcomeOf(429))
        assertEquals(SmsForwardRules.Outcome.TRY_AGAIN, SmsForwardRules.outcomeOf(408))
        assertEquals(SmsForwardRules.Outcome.REFUSED, SmsForwardRules.outcomeOf(400))
        assertEquals(SmsForwardRules.Outcome.REFUSED, SmsForwardRules.outcomeOf(404))
    }

    @Test
    fun theKeyIsTakenFromTheKeyOrTheSetUpLink() {
        val key = "npk_e58e0eec8584c2e192fb25f8515a2634430be62c0295a5c8"
        assertEquals(key, SmsForwardRules.keyFrom(key))
        assertEquals(key, SmsForwardRules.keyFrom("  $key \n"))
        assertEquals(key, SmsForwardRules.keyFrom("https://nexapos.cc/lite/phone.html#k=$key"))
        assertNull(SmsForwardRules.keyFrom("npk_"))
        assertNull(SmsForwardRules.keyFrom("hello"))
        assertNull(SmsForwardRules.keyFrom(null))
    }

    private fun assertTrue(condition: Boolean, message: String) = org.junit.Assert.assertTrue(message, condition)
}
