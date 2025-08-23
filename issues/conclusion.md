# Test Failure Summary

This document summarizes all failed test cases found in the CI logs from the issues folder, grouped by issue type.

## Issue 1: Queue Capacity & Priority Event Ordering (KVHeavyTasksManager)

**Test:** `testCrossScenario_QueueCapacity_Priority_EventOrdering`

### Occurrence 1: KVHeavyTaskManager2.txt
- **Line 205:** XCTAssertEqual failed: ("2") is not equal to ("3") 
- **Line 206:** XCTAssertEqual failed: ("["3", "1", "5", "2"]") is not equal to ("["1", "3", "5", "4", "2"]")

### Occurrence 2: KVHeavyTaskManager3.txt  
- **Line 205:** XCTAssertEqual failed: ("2") is not equal to ("3")
- **Line 206:** XCTAssertEqual failed: ("["5", "2", "1", "3"]") is not equal to ("["2", "5", "1", "3", "4"]")

### Occurrence 3: KVHeavyTaskManager4.txt
- **Line 207:** XCTAssertEqual failed: ("2") is not equal to ("3") 
- **Line 208:** XCTAssertEqual failed: ("["2", "5", "1", "3"]") is not equal to ("["2", "1", "3", "4", "5"]")

**Status:** ❌ CRITICAL - Consistently failing across all runs
**Description:** Queue capacity and priority event ordering is inconsistent. The test expects a specific count and task ordering, but gets different results each time, indicating potential race conditions or non-deterministic behavior.
**Root Cause:** Race conditions or non-deterministic queue ordering behavior

## Issue 2: Memory Management with Weak References (MonoTask)

**Test:** `testMemoryManagementWeakSelfGlobalExecution`

### Occurrence 1: MonoTask2.txt
- **Line 203:** XCTAssertEqual failed: ("1") is not equal to ("0") - Execution should have started

### Occurrence 2: MonoTask3.txt
- **Line 203:** XCTAssertEqual failed: ("1") is not equal to ("0") - Execution should have started

**Status:** ❌ CRITICAL - Consistently failing across multiple runs
**Description:** Memory management with weak self references in global execution context is not working properly - execution should have started but didn't.
**Root Cause:** Weak self references in global execution context preventing proper execution

## Issue 3: FIFO Eviction & Resume Events (KVHeavyTasksManager)

**Test:** `testCrossScenario_FIFO_Eviction_Resume_Events`

### Occurrence 1: KVHeavyTaskManager1.txt
- **Line 202:** XCTAssertEqual failed: ("["task3"]") is not equal to ("["task2", "task3"]")

**Status:** ❌ FAILED
**Description:** FIFO eviction and resume events are not working as expected - missing task2 in the result.
**Root Cause:** FIFO eviction mechanism missing tasks during resume operations

## Issue 4: TTL Microsecond Precision (MemoryCache)

**Test:** `testTTLRandomizationWithMicrosecondPrecision`

### Occurrence 1: MemoryCache3.txt
- **Line 396:** XCTAssertEqual failed: ("nil") is not equal to ("Optional("micro1")")
- **Line 397:** XCTAssertEqual failed: ("nil") is not equal to ("Optional("micro2")")

**Status:** ❌ FAILED
**Description:** TTL randomization with microsecond precision is not working correctly - expected cached values are nil when they should contain "micro1" and "micro2".
**Root Cause:** TTL precision handling not working at microsecond level - cache returning nil instead of expected values

## Issue 5: Property Access During State Transitions (MonoTask)

**Test:** `testPropertyAccessDuringStateTransitions`

### Occurrence 1: MonoTask1.txt (MonoTaskCrossScenarioTests)
- **Line 179:** XCTAssertEqual failed: ("1") is not equal to ("0")

**Status:** ❌ FAILED
**Description:** Property access during state transitions is not behaving as expected.
**Root Cause:** Property access synchronization issues during state transitions

## Summary Statistics

- **Total Issues:** 5 distinct failure patterns grouped from original 7 failed test cases
- **Total Failed Test Instances:** 7 across multiple log files
- **Total Error Lines:** 11 specific assertion failures with complete error messages preserved
- **Critical Issues (Multiple Occurrences):** 2
  - Issue 1: Queue Capacity & Priority Event Ordering (3 occurrences across KVHeavyTaskManager logs)
  - Issue 2: Memory Management with Weak References (2 occurrences across MonoTask logs)

## Detailed Issue Breakdown
- **Issue 1:** 6 assertion failures (2 per occurrence × 3 occurrences)
- **Issue 2:** 2 assertion failures (1 per occurrence × 2 occurrences)  
- **Issue 3:** 1 assertion failure
- **Issue 4:** 2 assertion failures  
- **Issue 5:** 1 assertion failure

## Issue Distribution by Component
- **KVHeavyTasksManager:** 2 unique issues
  - Issue 1: 3 occurrences (KVHeavyTaskManager2.txt, KVHeavyTaskManager3.txt, KVHeavyTaskManager4.txt)
  - Issue 3: 1 occurrence (KVHeavyTaskManager1.txt)
- **MonoTask:** 2 unique issues  
  - Issue 2: 2 occurrences (MonoTask2.txt, MonoTask3.txt)
  - Issue 5: 1 occurrence (MonoTask1.txt - MonoTaskCrossScenarioTests)
- **MemoryCache:** 1 unique issue
  - Issue 4: 1 occurrence (MemoryCache3.txt)

## Complete Source File Coverage
- **KVHeavyTaskManager1.txt:** Issue 3 (line 202)
- **KVHeavyTaskManager2.txt:** Issue 1 (lines 205-206)
- **KVHeavyTaskManager3.txt:** Issue 1 (lines 205-206)  
- **KVHeavyTaskManager4.txt:** Issue 1 (lines 207-208)
- **MemoryCache3.txt:** Issue 4 (lines 396-397)
- **MonoTask1.txt:** Issue 5 (line 179)
- **MonoTask2.txt:** Issue 2 (line 203)
- **MonoTask3.txt:** Issue 2 (line 203)

## Fix Priority Recommendations

1. **Priority 1 - CRITICAL:** 
   - Issue 1: Queue Capacity & Priority Event Ordering (affects core task management)
   - Issue 2: Memory Management with Weak References (affects execution reliability)

2. **Priority 2 - HIGH:**
   - Issue 3: FIFO Eviction & Resume Events (affects task resumption)

3. **Priority 3 - MEDIUM:**
   - Issue 4: TTL Microsecond Precision (affects cache precision)
   - Issue 5: Property Access During State Transitions (affects state consistency)

## Root Cause Analysis
- **Race Conditions:** Issues 1 and 5 likely involve concurrency problems
- **Memory Management:** Issue 2 involves weak reference lifecycle management
- **Algorithm Logic:** Issues 3 and 4 involve implementation correctness

All issues should be addressed to ensure system reliability and deterministic behavior.
