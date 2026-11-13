# NexaPOS 1.0.81

The M-Pesa prompt now goes straight to the customer's phone: no payment page opens any more. Cash sales, stock, reports and licences are not affected.

- **Send the M-Pesa prompt without opening the Paystack page.** Choose M-Pesa Prompt in the cart, type the customer's number (like 0712 345 678) and tap Send M-Pesa prompt. The customer approves it on their own phone with their M-Pesa PIN, and the sale completes by itself. This works the same in the Android, Windows and web versions.
- **If the customer declines or the prompt runs out,** the screen says so and offers Send the prompt again. It checks one last time that the customer did not approve, cancels the first sale (the stock goes back) and puts the items back in the cart with the number filled in, so nothing is typed again and the customer is never charged twice.
- **Cash plus M-Pesa for the rest** also asks for the customer's number and sends the prompt for just the remainder.
- **Paying by card is still possible:** under the number box, Customer pays by card instead? Open the payment page opens the Paystack page as before.
- **A crash fixed:** leaving the cart screen after a cart came back with M-Pesa chosen could fail; the fields are now set up when the screen opens.
