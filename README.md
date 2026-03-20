# GIAE Calendar

A Rails web application that scrapes and displays school meal information from the GIAE portal, allowing users to view their meal tickets and receive notifications.

## Features

- **User Authentication**: Sign up and sign in with email/password
- **GIAE Integration**: Automatically scrapes meal data from the GIAE portal using your credentials
- **Calendar View**: Visual calendar showing which days have meals purchased
- **Day Details Modal**: Click any day to see the full menu (soup, main dish, vegetables, dessert, bread)
- **Notifications**: In-app and email notifications for upcoming meals without tickets
- **Background Jobs**: Automated refresh of meal data using Solid Queue with separate database
- **Session Management**: Secure handling of GIAE session cookies with automatic refresh
- **Remember Me**: Stay logged in across browser sessions
- **Multi-Database Architecture**: Separate databases for app data and background jobs to prevent SQLite locking

## Tech Stack

- **Framework**: Ruby on Rails 8.1.2
- **Database**: SQLite3 with multi-database setup (separate databases for app and queue data)
- **Frontend**: Tailwind CSS, Turbo, Stimulus
- **Background Jobs**: Solid Queue with dedicated queue database
- **HTTP Client**: Net::HTTP (for GIAE scraping)
- **Authentication**: bcrypt with remember me tokens
- **Encryption**: Active Record Encryption for sensitive data
- **Deployment**: Docker, Fly.io

## Prerequisites

- Ruby 3.4+
- SQLite3
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

### Multi-Database Setup (Production)

In production, the application uses two separate SQLite databases to prevent locking issues:

- **Primary Database** (`production.sqlite3`): App data (users, meal tickets, notifications)
- **Queue Database** (`production_queue.sqlite3`): Solid Queue tables (jobs, processes, executions)

This separation allows concurrent access between web requests and background jobs without SQLite locking errors.

## Environment Variables

Create a `.env` file in the root directory:

```env
# Optional: Customize stale data threshold (default: 4 hours)
MEAL_TICKETS_STALE_HOURS=4

# Optional: Enable GIAE debug logging
GIAE_DEBUG=1
```

## Usage

### User Registration

1. Visit `/sign_up` to create an account
2. Enter your GIAE credentials (username, password, school code)
3. The system will automatically scrape your meal data

### Viewing Calendar

- Visit `/calendar` to see your meal tickets
- Days with purchased meals are highlighted
- Click on any day to see the full menu details in a modal popup
- Click "Refresh" to manually update data from GIAE

### Notifications

- Visit `/notifications` to see your notification history
- Enable/disable in-app and email notifications in your account settings
- Notifications are sent for days without meal tickets

## Background Jobs

The application uses Solid Queue for background processing with a dedicated queue database:

- **RefreshMealTicketsJob**: Scrapes GIAE portal for meal data
- **FetchSaldoDisponivelJob**: Fetches current account balance
- **RefreshStaleMealTicketsJob**: Periodically refreshes stale data
- **NotifyUpcomingMealTicketsJob**: Sends notifications for missing tickets
- **CleanupGiaeSessionsJob**: Cleans up expired GIAE sessions

Start the job processor in development:
```bash
bundle exec rake solid_queue:start
```

In production, Solid Queue starts automatically with the application.

## Database Architecture

### Development
Single SQLite database (`storage/development.sqlite3`) with all tables.

### Production
Two separate SQLite databases:

```yaml
# config/database.yml
production:
  primary:
    database: /data/production.sqlite3
  queue:
    database: /data/production_queue.sqlite3
```

The queue database is automatically created on startup with the proper schema.

## Testing

### Running Tests

Run the full test suite:
```bash
rails test
```

Run tests with coverage report:
```bash
COVERAGE=true rails test
```

View the coverage report:
```bash
open coverage/index.html
```

### Test Coverage

The application uses **SimpleCov** for code coverage analysis. Current coverage:
- **Line Coverage**: ~70% (431 / 610 lines)
- **Branch Coverage**: ~57% (85 / 150 branches)

Coverage reports are generated in the `coverage/` directory when running tests with `COVERAGE=true`.

### Writing Tests

When adding new features, include comprehensive tests:

```bash
# Generate a model test
rails generate test_unit:model User

# Generate a controller test
rails generate test_unit:controller Calendars

# Generate a job test
rails generate test_unit:job RefreshMealTicketsJob
```

Test files are located in `test/` with subdirectories for:
- `models/` - Model validation and business logic
- `controllers/` - Request handling and responses
- `jobs/` - Background job behavior
- `services/` - Service object functionality
- `helpers/` - View helper methods
- `mailers/` - Email delivery and content
- `integration/` - End-to-end user flows

### Test Organization

The test suite includes:
- **Model tests** (User, MealTicket, MealDetail, Notification, GiaeSession, etc.)
- **Controller tests** (Sessions, Registrations, Notifications, Calendars)
- **Job tests** (All background jobs)
- **Service tests** (GiaeScraperService, NotificationService, GiaeSessionManager)
- **Helper tests** (ApplicationHelper)
- **Mailer tests** (UserMailer)
- **Integration tests** (Authentication flow, Remember Me)

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

The deployment includes:
- Automatic database setup
- Queue database creation
- Solid Queue worker startup
- Health checks

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
├── database.yml     # Multi-database configuration
├── queue.yml        # Solid Queue configuration
├── routes.rb        # URL routing
└── credentials/     # Encrypted credentials

db/
├── migrate/         # Database migrations
├── queue_schema.sql # Solid Queue schema for production
└── seeds.rb         # Seed data

test/
├── controllers/     # Controller tests
├── models/          # Model tests
├── jobs/            # Job tests
├── services/        # Service tests
└── integration/     # Integration tests
```

## Models

- **User**: Authentication, encrypted GIAE credentials, notification preferences, remember me tokens
- **MealTicket**: Daily meal purchase status
- **MealDetail**: Detailed meal information (soup, main dish, vegetables, dessert, bread)
- **SaldoRecord**: Account balance history
- **Notification**: User notifications (in-app/email)
- **GiaeSession**: Managed GIAE portal sessions with automatic refresh

## Services

- **GiaeScraperService**: Scrapes the GIAE portal using HTTP requests
- **NotificationService**: Sends in-app and email notifications
- **GiaeSessionManager**: Manages GIAE session lifecycle with automatic refresh on expiration
- **GiaeDebug**: Optional debug logging for GIAE requests/responses

## Troubleshooting

### GIAE Login Failures
- Verify your GIAE credentials are correct
- Check that the GIAE portal is accessible
- Check the GIAE portal URL in your credentials
- Enable debug mode with `GIAE_DEBUG=1` to see detailed logs

### Session Expired Errors
The application automatically refreshes GIAE sessions older than 24 hours. If you see session errors:
- The session will be refreshed automatically on the next job run
- Check GIAE portal availability

### Master Key Issues
If you get encryption errors:
- Ensure `config/master.key` exists and is correct
- Set `RAILS_MASTER_KEY` environment variable in production

## Support

For issues and feature requests, please open an issue on the repository.

## Credits

Built with Rails, Tailwind CSS, and Solid Queue for background processing.
Multi-database architecture inspired by Rails guides for SQLite production usage.
