Pod::Spec.new do |spec|
  spec.name         = "Monstra"
  spec.version      = "0.1.0"
  spec.summary      = "High-performance task execution and caching framework for Swift"
  spec.description  = <<-DESC
    Monstra is a thread-safe, high-performance task executor that ensures only one instance
    of a task runs at a time while providing intelligent result caching and retry capabilities.
    
    Features:
    - Execution Merging: Multiple concurrent requests are merged into a single execution
    - TTL-based Caching: Results are cached for a configurable duration
    - Retry Logic: Automatic retry with exponential backoff for failed executions
    - Thread Safety: Full thread safety with fine-grained locking using semaphores
    - Queue Management: Separate queues for task execution and callback invocation
    - Manual Cache Control: Manual cache invalidation with execution strategy options
  DESC
  
  spec.homepage     = "https://github.com/yangchenlarkin/Monstra"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Larkin" => "yangchenlarkin@gmail.com" }
  spec.platform     = :ios, "13.0"
  spec.platform     = :osx, "10.15"
  spec.source       = { :git => "https://github.com/yangchenlarkin/Monstra.git", :tag => "v#{spec.version}" }
  
  spec.swift_version = "5.5"
  
  # Build all source files as one unified framework
  spec.source_files = "Sources/**/*.swift"
  
  # Specify module name explicitly
  spec.module_name = "Monstra"
  
  # Ensure proper dependency resolution during linting
  spec.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.5',
    'CLANG_ENABLE_MODULES' => 'YES'
  }
  
  # Exclude test files and examples from pod
  spec.exclude_files = "Tests/**/*", "Examples/**/*"
end
