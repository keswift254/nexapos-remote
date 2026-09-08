# NexaPOS 1.0.25

- Sharper thermal-report PDF previews, including zoom and high-resolution displays.
- Reports has an explicit back button; dashboard stock value is hidden by default and re-hides after 60 seconds or refresh.
- New devices can join an existing shop from activation using an owner-generated invite, without a separate device activation.
- Joined-only access is checked on startup, resume, and the two-minute sync cycle, with up to 24 hours of cached offline access. Confirmed removal locks access and preserves local records for support recovery.
- Verified, backed-up shop departure removes joined access but preserves any separately activated license.
- The online device dashboard distinguishes joined-only access, standalone activation requirements, and removed devices.
- Checkout now labels the hosted Paystack flow as M-Pesa Prompt, and Android reliably receives the successful-payment return link before verifying payment.
- Fingerprint or face sign-in is available on Android, with Windows Hello on Windows; no NexaPOS password is stored for quick sign-in.
- Privacy settings can lock the app immediately when left, or after 1, 5, or 30 minutes of inactivity.
- A licensed first-time device opens account setup immediately while primary-device registration completes in the background.

Windows and Android releases are cumulative. Installing this release does not require installing skipped versions first.
