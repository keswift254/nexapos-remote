# NexaPOS 1.0.61

Support and activation follow-up release.

- New support tickets open immediately while the ticket list refreshes in the background.
- Support photo selection reads files concurrently and checks image and ticket limits before upload.
- The support conversation labels the shop with its business name and colors the shop's messages blue.
- Invite and join failures now distinguish a slow or unreachable shop server from an API rejection; this does not bypass certificate verification or change payment behavior.
- Activation recovery preserves existing seeded roles when another opener creates them during startup.

The support dashboard's photo-count and image-display changes require the matching platform API and license dashboard deployment. Windows 7/8 remains a legacy build and must be tested on an affected device; a successful build is not proof that its network or certificate environment can reach the API.
