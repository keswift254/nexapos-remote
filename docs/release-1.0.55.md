# NexaPOS 1.0.55

Infrastructure and updater repair release.

- Windows installers launch NexaPOS automatically after setup completes.
- In-app Windows updates now run the native installer silently after UAC approval, then reopen NexaPOS.
- Windows 7/8 builds stamp the actual release version/build into the known-good legacy runner instead of retaining an older version resource.
- Android release builds now require the permanent NexaPOS signing key and fail unless the APK certificate SHA-256 is exactly `a6f671d84bd85601d4c40f18eab6b42d3b4833deae7c7570489211fa827edfa9`.
- Existing activation-plan live refresh and server-authoritative checkout pricing remain unchanged.
