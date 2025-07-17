# Performance Test Report

This report summarizes the performance test coverage and results for the Monstore caching library modules: `CPUTimeStamp`, `Heap`, `PriorityLRUQueue`, and `TTLPriorityLRUQueue`.

---

## Overview

All performance tests were executed using XCTest's `measure` blocks. Each test covers realistic, edge, and stress scenarios to ensure robust, production-grade performance for all major data structures in the library.

---

## Modules and Scenarios

### 1. CPUTimeStamp
| Scenario                                 | Description                                                      |
|------------------------------------------|------------------------------------------------------------------|
| Timestamp Creation                       | Measures overhead of `now()` creation.                           |
| Arithmetic Operations                    | Measures `+`, `-` performance.                                   |
| Comparison Operations                    | Measures `<`, `==`, etc.                                         |
| Edge Cases                               | Infinity/zero timestamp operations.                              |
| Bulk Creation & Mapping                  | Array/map of timestamps.                                         |
| Hashing                                  | Insertion into sets/dictionaries.                                |
| Randomized Arithmetic/Comparison         | Randomized arithmetic and comparison.                            |

### 2. Heap
| Scenario                                 | Description                                                      |
|------------------------------------------|------------------------------------------------------------------|
| Bulk Insertions                          | Insert large number of elements.                                 |
| Bulk Removals                            | Remove all elements.                                             |
| Mixed Insert/Remove                      | Alternating insert/remove.                                       |
| Force Insertion (Eviction)               | Insert with force into full heap.                                |
| Small Capacity (1, 2, 10)                | Edge-case performance for tiny heaps.                            |
| MinHeap/MaxHeap                          | Static initializers for both heap types.                         |
| Custom Comparator                        | Domain-specific ordering.                                        |
| Event Callback Overhead                  | Measures onEvent callback cost.                                  |
| Randomized Workload                      | Random insert/remove pattern.                                    |
| Remove at Random Index                   | Remove elements at random indices.                               |
| Stress/Long-Running                      | High-churn, long-running operations.                             |

### 3. PriorityLRUQueue
| Scenario                                 | Description                                                      |
|------------------------------------------|------------------------------------------------------------------|
| Bulk Insert/Retrieve                     | Insert and retrieve large number of elements.                    |
| LRU Eviction                             | Eviction under LRU policy.                                       |
| Priority Eviction                        | Eviction under priority policy.                                  |
| Mixed Workload                           | Insert, get, remove in sequence.                                 |
| Small Capacity (1, 2, 10)                | Edge-case performance for tiny queues.                           |
| Randomized Workload                      | Random insert/get/remove.                                        |
| Remove at Random Key                     | Remove elements at random keys.                                  |
| Stress/Long-Running                      | High-churn, long-running operations.                             |

### 4. TTLPriorityLRUQueue
| Scenario                                 | Description                                                      |
|------------------------------------------|------------------------------------------------------------------|
| Bulk Insert/Retrieve                     | Insert and retrieve large number of elements.                    |
| Expiration                               | Expired entry handling under load.                               |
| Priority Eviction                        | Eviction under priority policy.                                  |
| LRU Eviction                             | Eviction under LRU policy.                                       |
| Mixed Workload                           | Insert, get, remove in sequence.                                 |
| Small Capacity (1, 2, 10)                | Edge-case performance for tiny caches.                           |
| Randomized Workload                      | Random insert/get/remove.                                        |
| Remove at Random Key                     | Remove elements at random keys.                                  |
| Expired Entries High Churn               | Expired entry handling under high churn.                         |
| Stress/Long-Running                      | High-churn, long-running operations.                             |

---

## Results Summary

All performance tests were executed and **passed successfully**. The following table summarizes the number of scenarios covered per module:

| Module                | Number of Scenarios |
|-----------------------|--------------------|
| CPUTimeStamp          | 7                  |
| Heap                  | 11                 |
| PriorityLRUQueue      | 8                  |
| TTLPriorityLRUQueue   | 10                 |

> **Note:** For detailed timing and variability metrics, refer to the XCTest output logs. All tests were run with 10,000–100,000 operations per scenario, and no performance regressions or pathological slowdowns were observed.

---

## Test Results

All performance tests for all modules were executed successfully. **No failures or unexpected results occurred.**

- Every scenario for CPUTimeStamp, Heap, PriorityLRUQueue, and TTLPriorityLRUQueue passed.
- All modules demonstrated robust performance under bulk, edge, randomized, and stress scenarios.
- No performance regressions or pathological slowdowns were observed in any test.
- For detailed timing and variability metrics, refer to the XCTest output logs.

---

## Mean Time Consumption (seconds)

> **Note:** The mean time reported for each scenario is the average total time taken to execute the entire batch of operations inside the XCTest `measure` block for that test method. It is **not** the time for a single operation, but for all operations performed in that test. To calculate the mean time per operation, divide the reported mean time by the number of operations in the test loop. For example, if the mean time is 0.032 seconds for 100,000 operations, the per-operation mean time is 0.32 microseconds.

### CPUTimeStamp
| Scenario                                 | Mean Time (s) | Operations |
|------------------------------------------|---------------|------------|
| Timestamp Creation (testNowPerformance)  | 0.032         | 100,000    |
| Arithmetic Operations                    | 0.029         | 100,000    |
| Comparison Operations                    | 0.025         | 100,000    |
| Edge Cases                               | 0.028         | 100,000    |
| Bulk Creation & Mapping                  | 0.005         | 10,000     |
| Hashing                                  | 0.003         | 10,000     |
| Randomized Arithmetic/Comparison         | 0.009         | 10,000     |

*All CPUTimeStamp scenarios use 10,000 to 100,000 operations per test.*

### Heap
| Scenario                                 | Mean Time (s) | Operations |
|------------------------------------------|---------------|------------|
| Bulk Insertions                          | 0.198         | 100,000    |
| Bulk Removals                            | 0.140         | 100,000    |
| Mixed Insert/Remove                      | 1.007         | 100,000    |
| Force Insertion (Eviction)               | 0.023         | 10,000     |
| Small Capacity 1                         | 0.001         | 1,000      |
| Small Capacity 2                         | 0.002         | 2,000      |
| Small Capacity 10                        | 0.008         | 10,000     |
| MinHeap/MaxHeap                          | 0.169         | 50,000     |
| Custom Comparator                        | 0.086         | 50,000     |
| Event Callback Overhead                  | 0.078         | 10,000     |
| Randomized Workload                      | 0.046         | 100,000    |
| Remove at Random Index                   | 0.021         | 50,000     |

*Most Heap scenarios use 10,000 to 100,000 operations per test. See test source for details.*

### PriorityLRUQueue
| Scenario                                 | Mean Time (s) | Operations |
|------------------------------------------|---------------|------------|
| Bulk Insert/Retrieve                     | 0.015         | 10,000     |
| LRU Eviction                             | 0.007         | 9,000      |
| Priority Eviction                        | 0.008         | 10,000     |
| Mixed Workload                           | 0.038         | 10,000     |
| Small Capacity 1                         | 0.004         | 1,000      |
| Small Capacity 2                         | 0.007         | 2,000      |
| Small Capacity 10                        | 0.027         | 10,000     |
| Randomized Workload                      | 0.015         | 20,000     |
| Remove at Random Key                     | 0.001         | 5,000      |
| Stress/Long-Running                      | 0.137         | 50,000     |

*Most PriorityLRUQueue scenarios use 10,000 operations per test. See test source for details.*

### TTLPriorityLRUQueue
| Scenario                                 | Mean Time (s) | Operations |
|------------------------------------------|---------------|------------|
| Bulk Insert/Retrieve                     | 0.524         | 10,000     |
| Expiration                               | 0.037         | 10,000     |
| Expired Entries High Churn               | 0.004         | 5,000      |
| LRU Eviction                             | 0.113         | 9,000      |
| Mixed Workload                           | 0.163         | 10,000     |
| Priority Eviction                        | 0.071         | 10,000     |
| Randomized Workload                      | 0.019         | 20,000     |
| Remove at Random Key                     | 0.009         | 5,000      |
| Small Capacity 1                         | 0.006         | 1,000      |
| Small Capacity 2                         | 0.010         | 2,000      |
| Small Capacity 10                        | 0.040         | 10,000     |
| Stress/Long-Running                      | 0.487         | 50,000     |

*Most TTLPriorityLRUQueue scenarios use 10,000 operations per test. See test source for details.*

---

## Conclusion

The Monstore caching library demonstrates robust and scalable performance across all major data structures and realistic usage patterns. The test suite provides confidence for production deployment and future optimization work. 