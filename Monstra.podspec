Pod::Spec.new do |spec|
  spec.name         = "Monstra"
  spec.version      = "1.0.0"
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
  spec.source       = { :git => "https://github.com/yangchenlarkin/Monstra.git", :tag => "#{spec.version}" }
  
  spec.swift_version = "5.5"
  
  # Core Monstra library
  spec.subspec "MonstraBase" do |ss|
    ss.source_files = "Sources/MonstraBase/**/*.swift"
  end
  
  spec.subspec "Monstore" do |ss|
    ss.source_files = "Sources/Monstore/**/*.swift"
    ss.dependency "Monstra/MonstraBase"
  end
  
  spec.subspec "Monstask" do |ss|
    ss.source_files = "Sources/Monstask/**/*.swift"
    ss.dependency "Monstra/MonstraBase"
    ss.dependency "Monstra/Monstore"
  end
  
  # Default subspec includes all components
  spec.default_subspecs = "Monstask"
  
  # Exclude test files and examples from pod
  spec.exclude_files = "Tests/**/*", "Examples/**/*"
end
