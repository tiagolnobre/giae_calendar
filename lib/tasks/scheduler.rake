desc "Refresh stale meal tickets for all users"
task refresh_stale_meal_tickets: :environment do
  RefreshStaleMealTicketsJob.perform_later
end

desc "Notify users about upcoming meal tickets"
task notify_upcoming_meal_tickets: :environment do
  NotifyUpcomingMealTicketsJob.perform_later
end
