# NexaPOS 1.0.17

## Windows update compatibility

- Keeps the UAC-aware update handoff introduced in 1.0.16.
- Makes the installer start safely from older clients, including 1.0.14, then request administrator approval internally.
- Cancelling the UAC prompt leaves the existing installation unchanged.
