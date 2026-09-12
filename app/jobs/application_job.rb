class ApplicationJob < ActiveJob::Base
  # Base job class for the application.
  # Common Active Job behavior can be centralized here when the project grows.

  # Automatically retry jobs that encountered a deadlock.
  # retry_on ActiveRecord::Deadlocked

  # Ignore jobs whose target record no longer exists when the serialization fails.
  # discard_on ActiveJob::DeserializationError
end
