# GIAE Calendar

A Rails web application that scrapes and displays school meal information from the GIAE portal, allowing users to view their meal tickets and receive notifications.

## Features

- **User Authentication**: Sign up and sign in with email/password
- **GIAE Integration**: Automatically scrapes meal data from the GIAE portal using your credentials
- **Calendar View**: Visual calendar showing which days have meals purchased
- **Notifications**: In-app and email notifications for upcoming meals without tickets
- **Background Jobs**: Automated refresh of meal data using Solid Queue
- **Session Management**: Secure handling of GIAE session cookies with automatic refresh

## Tech Stack

- **Framework**: Ruby on Rails 8.1.2
- **Database**: SQLite3 with Litestream for backups
- **Frontend**: Tailwind CSS, Turbo, Stimulus
- **Background Jobs**: Solid Queue
- **Browser Automation**: Ferrum (Chrome/Chromium headless browser)
- **Authentication**: bcrypt
- **Deployment**: Docker, Kamal, Fly.io

## Prerequisites

- Ruby 3.3+
- SQLite3
- Chrome/Chromium browser (for Ferrum scraping)
- Node.js (for Tailwind CSS)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd giae_calendar
```

2. Install dependencies:
```bash
bundle install
```

3. Setup the database:
```bash
rails db:create db:migrate
```

4. Start the development server:
```bash
bin/dev
```

## Configuration

The application uses Rails credentials for sensitive data. Set up your credentials:

```bash
EDITOR="vim" rails credentials:edit
```

Add your GIAE portal URL in the credentials or environment variables.

## Environment Variables

Create a `.env` file in the root directory:

```env
# Optional: Customize stale data threshold (default: 4 hours)
MEAL_TICKETS_STALE_HOURS=4
```

## Usage

### User Registration

1. Visit `/sign_up` to create an account
2. Enter your GIAE credentials (username, password, school code)
3. The system will automatically scrape your meal data

### Viewing Calendar

- Visit `/calendar` to see your meal tickets
- Days with purchased meals are highlighted
- Click "Refresh" to manually update data from GIAE

### Notifications

- Visit `/notifications` to see your notification history
- Enable/disable in-app and email notifications in your account settings
- Notifications are sent for days without meal tickets

## Background Jobs

The application uses Solid Queue for background processing:

- **RefreshMealTicketsJob**: Scrapes GIAE portal for meal data
- **RefreshStaleMealTicketsJob**: Periodically refreshes stale data
- **NotifyUpcomingMealTicketsJob**: Sends notifications for missing tickets
- **CleanupGiaeSessionsJob**: Cleans up expired GIAE sessions

Start the job processor:
```bash
bundle exec rake solid_queue:start
```

Or in production, use the Procfile:
```bash
bundle exec foreman start
```

## Testing

Run the test suite:
```bash
rails test
```

The test suite includes:
- Model tests (User, MealTicket, MealDetail, Notification, etc.)
- Controller tests (Sessions, Registrations, Notifications, Calendars)
- Job tests (All background jobs)
- Service tests (GiaeScraperService, NotificationService)
- Integration tests (Authentication flow)

## Deployment

### Docker

Build and run with Docker:
```bash
docker build -t giae-calendar .
docker run -p 3000:3000 giae-calendar
```

### Fly.io

Deploy to Fly.io:
```bash
fly deploy
```

## Project Structure

```
app/
├── controllers/     # Request handling
├── models/          # Business logic and data
├── views/           # Templates (ERB)
├── jobs/            # Background jobs
├── services/        # Business logic services
└── assets/          # CSS, JS, images

config/
├── routes.rb        # URL routing
└── credentials/     # Encrypted credentials

db/
├── migrate/         # Database migrations
└── seeds.rb         # Seed data

test/
├── controllers/     # Controller tests
├── models/          # Model tests
├── jobs/            # Job tests
├── services/        # Service tests
└── integration/     # Integration tests
```

## Models

- **User**: Authentication, GIAE credentials (encrypted), notification preferences
- **MealTicket**: Daily meal purchase status
- **MealDetail**: Detailed meal information (soup, main dish, etc.)
- **SaldoRecord**: Account balance history
- **Notification**: User notifications (in-app/email)
- **GiaeSession**: Managed GIAE portal sessions

## Services

- **GiaeScraperService**: Scrapes the GIAE portal using Ferrum
- **NotificationService**: Sends in-app and email notifications
- **GiaeSessionManager**: Manages GIAE session lifecycle

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Submit a pull request

## License

This project is proprietary software for personal/educational use.

## Troubleshooting

### Chrome/Chromium Not Found
If you get errors about Chrome not being found, install Chromium:
```bash
# macOS
brew install chromium

# Ubuntu/Debian
sudo apt-get install chromium-browser
```

### Database Locked Errors
SQLite can have concurrency issues. In production, use a single Puma worker or switch to PostgreSQL.

### GIAE Login Failures
- Verify your GIAE credentials are correct
- Check that the GIAE portal is accessible
- Ensure Chrome/Chromium is properly installed

## Support

For issues and feature requests, please open an issue on the repository.

## Credits

Built with Rails, Tailwind CSS, and Ferrum for browser automation.
