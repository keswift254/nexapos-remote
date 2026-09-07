# NexaPOS 1.0.18

- Import and backup show Done; completed imports no longer wait for network sync.
- Backup passwords now accept 8 or more characters, with existing encryption and restore compatibility.
- Checkout offers Cash and Paystack. Historical M-Pesa records remain available in reports.
- Paystack checkout returns through a browser link to NexaPOS on Windows and Android. The app still verifies payment with the server before issuing a receipt.

The browser may ask permission to open NexaPOS. An Open NexaPOS button is available if automatic opening is blocked. Windows setup registers the return protocol; portable ZIP installations do not register it.
