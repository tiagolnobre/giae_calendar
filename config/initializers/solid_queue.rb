# frozen_string_literal: true

# Configure Solid Queue to use the separate queue database
# This prevents SQLite locking between web requests and background jobs
# This must be set before Solid Queue models are loaded
if Rails.env.production?
  SolidQueue.connects_to = { database: { writing: :queue, reading: :queue } }
end
