# frozen_string_literal: true

# Configure Solid Queue to use the separate queue database
# This prevents SQLite locking between web requests and background jobs
# This must be set before Solid Queue models are loaded
if Rails.env.production?
  SolidQueue.connects_to = { database: { writing: :queue, reading: :queue } }
elsif Rails.env.development?
  # Use async adapter in development to avoid SQLite locking issues
  # Jobs run in background threads instead of separate processes
  Rails.application.config.active_job.queue_adapter = :async
end
