# NexaPOS 1.0.69

Support-screen fixes. Install it on every device; nothing about selling, stock, licences or payments changes.

- **Pasted and attached pictures now send.** A screenshot copied on Windows reaches the app as a BMP, which the support server refuses ("Use a PNG, JPEG or WebP photo up to 16 megapixels"). Pictures are now converted before they are sent: BMP and GIF become PNG/JPEG, and a picture that is too big (a phone photo over 2 MB, a 4K screenshot) is made smaller automatically instead of being refused. A picture that already fits is sent exactly as it is. The "+" file chooser also accepts BMP and GIF.
- **Tap a picture to see it.** In the message box, tapping a waiting picture opens it full size (pinch or scroll to zoom); the picture stays attached.
- **A clear round X on each picture.** The X on the top-right corner of a picture removes just that picture.
- **Web app: updating shows real progress and forces the new version in.** In the browser version, **Download & Install** now shows a progress bar with a percentage while the new version downloads, then restarts the app by itself on the newest version - it no longer downloads the update twice, and it gives up with a clear message (and a **Try again** button) if the connection stalls. Tapping **Check for Updates** while an update is running no longer interrupts it or resets its progress. Your shop data is never touched. (The progress bar appears from the update *after* this one, because the update to 1.0.69 itself is run by the older version.)
- If a picture cannot be read, the message now says so ("This picture could not be read. Try a PNG or JPEG photo.").

This release does not change the licence, payment or database format. Windows 7/8 keeps its separate installer.
