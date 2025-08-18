//
//  MonoTaskTests.swift
//  Monstra
//
//  Created by Larkin on 2025/8/18.
//

//consider what test cases should be added, here are some insights:
//
//1. call callback just once per invocation of execution
//2. execute just once before result is expired (including the running period and caching period)
//3. re-execute after result is expired
//4. retry-count
//5. different dispatch queue check
//6. different execute method
//7. currentResult check
//8. clearResult check
//9. isExecuting check
//
//you should check the functions and check their correction under concurrency senarios
