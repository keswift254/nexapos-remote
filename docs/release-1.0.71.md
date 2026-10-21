# NexaPOS 1.0.71

This release improves Support messages, app settings and updates. Install the new version on each device to receive the app changes.

- Support replies on the dashboard now show **Delivered** when the server accepts them and **Read** after the shop opens the conversation in NexaPOS. A read receipt is not sent by background ticket checks.
- Choose **Use system setting**, **Light** or **Dark** under Settings > Business & Receipts. The system theme is the default; your choice is saved on this device or browser.
- The Settings menu has clearer names for security, receipts, payments, sync, devices, backup, date and time, licence and software updates.
- Connected Devices accepts device IDs returned as either numbers or numeric strings, so the page no longer fails to load for that response format.
- The web Support screen plays the send sound when you press Send, within the browser's permitted user gesture.
- The web updater shows preparation progress on the first attempt and retries interrupted asset downloads. Windows installer downloads retry once after a transient network failure.
- On Windows and other native builds, closing NexaPOS ends the current sign-in session. Your shop data, device identity and licence remain stored.

Support read receipts require the accompanying platform API and dashboard update. **Delivered** means the server accepted the reply; it does not prove that a customer device received it.
