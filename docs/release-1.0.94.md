# NexaPOS 1.0.94

**The key that unlocks a PC's saved data can no longer be lost the way it was on 25 November 2026.** That day a Windows PC showed "NexaPOS can't open its saved data": three copies of NexaPOS had been running at once - one of them left running as administrator by an update - and between them they emptied the small file that holds the key, and then its backup too. The data itself was intact and the real key was found in copies NexaPOS had set aside. This release closes each step of that chain:

- **Only one NexaPOS at a time (Windows 10/11 and Windows 7/8).** Starting NexaPOS while it is already open brings the open window to the front instead of starting a second copy - also when the open one runs as administrator.
- **An update never leaves NexaPOS running as administrator.** The in-app update starts Setup with administrator rights, and Setup then restarted NexaPOS with them too. Setup now starts NexaPOS through the user's own desktop, without administrator rights.
- **The key's backup is never replaced by a file without the key.** If the key file loses the database key behind NexaPOS's back, NexaPOS puts the backup back and carries on, instead of copying the emptied file over the backup.
- **NexaPOS finds a lost key by itself.** When the key is missing (or does not open the data) at start-up, NexaPOS looks in its backup and in every copy it set aside, and puts back the newest one whose key really opens this PC's data - before asking anyone. Newer settings from the emptied file are kept; nothing is deleted. Up to ten set-aside copies are kept (was three), and the newest one that still holds the key is never deleted.

Only Windows changes; Android and the web POS behave as before.
