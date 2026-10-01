# NexaPOS 1.0.58

Support reliability and Windows Hello release.

- Support ticket lists and messages now accept numeric IDs returned as strings by the PHP/MySQL API, so shop tickets and replies load normally.
- Support shows a connection error for real timeouts and socket failures, and a separate response error for malformed server data.
- On Windows 11, grant the Windows Security prompt foreground permission when starting Windows Hello sign-in. The taskbar hint remains available if Windows keeps the prompt behind another window.
- The Windows 7/8 legacy installer keeps its existing compatible runtime and does not include the Windows Hello plugin.
