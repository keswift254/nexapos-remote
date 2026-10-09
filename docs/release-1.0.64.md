# NexaPOS 1.0.64

Focused activation and PDF sharing update based on 1.0.63.

- Keep visible activation timeout/error reporting from 1.0.62.
- Use the platform PDF file share picker in Reports on Android, iOS, supported browsers, and supported Windows versions.
- On Windows 7 and browsers without file sharing, show a clear Save-and-attach instruction instead of silently opening or downloading the PDF.
- Preserve the separate Windows 7/8 installer.

This release does not include the pending support-storage changes or require their database migration. It reports activation failures rather than repairing an underlying license or network fault; preserve the client's installation and data while diagnosing the cause.
