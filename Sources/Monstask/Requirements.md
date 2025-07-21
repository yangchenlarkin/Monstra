# KVTask
## requirements:
- LightTask: small resources download with task queue in memory
- HeavyTask: large resources download with task queue in disk (e.g. video downloading feature of video platform)

## Fetch api
- callback
- concurrency

## Queue
### Light Tasks:
- LRU
- limitation
- multi-thread
- processing task strategy: await, cancel, pause
- batch fetch
### heavy Tasks:
- LIFO
- limitation
- multi-thread
- processing task strategy: await, cancel, pause
- batch fetch

## Task
- retryCount
- pause/resume
- process tracking
- error handling
