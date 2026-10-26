# NexaPOS 1.0.73

Printing improvements. Nothing about selling, stock, licences or payments changes.

- **Reports print directly to the thermal printer.** In the installed app, Reports > Print now sends the daily or monthly report straight to the printer set up under Business, Receipts & Themes, with no PDF print-setup window. The report is printed as text at the saved 58 mm or 80 mm width, so it is no longer faint or clipped. Export PDF is unchanged.
- **Browsers still show the browser's print window.** A website cannot print silently; only the installed app can.
- **Find network printers.** The network-printer setting can search your local network for printers that accept direct IP printing (port 9100); pick the address it finds and save. It only searches when you ask it to.
- **USB or shared Windows printers.** The Windows printer option is now labelled for both USB and shared printers, and has a refresh button to pick up a printer you just connected in Windows. A printer shared from another PC does not appear in the network search; add it in Windows first, then choose it here.
- **Faster, safer network printing.** Network printing no longer waits on delayed packets and gives up after a bounded time. It never resends a ticket that may already have printed, so you do not get duplicates.
- The public website's headline now sits closer to the top of the page.

This release does not change the licence, payment or database format. Windows 7/8 keeps its separate installer.
