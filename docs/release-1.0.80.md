# NexaPOS 1.0.80

Face ID sign-in on the web version now works on iPhones that wrongly reported "no Face ID". Nothing else changes: stock, reports, payments and licences are not affected.

- **Face ID / fingerprint sign-in is no longer blocked by the browser's guess.** Since iOS 26.2, an iPhone can tell a web page there is no Face ID even though it has one (and the Home Screen copy always said so until iOS 26.3). NexaPOS now tries to set it up anyway and lets the phone decide, so the Face ID prompt appears. If the phone really cannot do it, the message says what to check (Face ID & Passcode, and Passwords turned on in iCloud), with a short code.
- **Once it is set up it stays available.** The sign-in button is shown whenever quick sign in was set up on that browser, whatever the browser answers later. Turning quick sign in off removes it completely.
