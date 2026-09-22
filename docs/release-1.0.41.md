# NexaPOS 1.0.41

- Fixed offline changes sometimes disappearing after a page reload on the browser POS (most noticeable on iPhone Safari): a device's own changes could be left unsaved in the browser's memory instead of its offline storage until something else happened to save them.
- Fixed "leave shop" failing on a device that had received but not yet forwarded another device's local-network sync data - it no longer blocks leaving or the device's own sync.
- Payment errors now say clearly when the payments server itself could not be reached or was slow to respond, instead of always suggesting the device's own internet connection is the problem.
- The authenticator code entry (used when generating a join/invite code and other sensitive actions) is now six separate digit boxes instead of one text line.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Android, Windows 10/11, and Windows 7/8 builds are cumulative. The installed POS is not modified by publication.
