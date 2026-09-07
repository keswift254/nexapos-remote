# NexaPOS 1.0.19

- Receipts include the NEXAPOS wordmark, installation contact 0768415017, and a stable receipt barcode. Merchant footer text is preserved.
- Receipt actions are Print to thermal printer and New Sale.
- NexaPOS commission is zero on new payments, including previously configured subaccounts. Paystack processing fees are borne by the merchant.
- Inventory's Add Product action reserves its own space below pagination, including Android navigation insets.
- Renewed licenses can be activated again on their original device without resetting the paid extension.
- The license admin page can queue a device authenticator reset and issue a one-time support password.
- Forgot login details opens support recovery. Username nexapos-support is reserved and is not an editable shop account; its device-specific password expires after 15 minutes and is consumed once. Recovery can reset one existing active account's password without changing its role.

For support: verify the client's ownership, enter their device ID in the license generator, then choose Reset authenticator or Generate super admin recovery password. For authenticator reset, the client connects and selects Check for approved reset. For login recovery, enter the one-time password under Forgot login details, select the account, and set its new password. No reusable master password is embedded in the app.
