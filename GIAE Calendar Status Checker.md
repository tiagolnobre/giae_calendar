# GIAE Calendar Status Checker

This Ruby script logs into the GIAE portal, opens the **Aquisição de Refeições** page, and prints the purchase status of school meals for all **weekdays** in the **currently displayed month** of the calendar, always assuming the **current year**.

It classifies each day as:

- `BOUGHT` – the day’s cell has the CSS class `highlight-green`
- `not bought` – the day’s cell has the CSS class `highlight` (or lacks `highlight-green`)

Weekends (Saturday/Sunday) and Portuguese national bank holidays are excluded from the output.

## What the script does step by step

1. **Setup and configuration**

   - Loads environment variables:
     - `GIAE_USERNAME` – login username (utilizador / nº cartão).
     - `GIAE_PASSWORD` – login password.
     - `GIAE_LOGIN_URL` – AUTENTICAÇÃO page for your GIAE instance (e.g. `https://aemgn.giae.pt/index.html`).
     - `GIAE_AQUISITION_URL` – kept for completeness, but not used directly (navigation is via the menu).
     - `GIAE_HEADLESS` – if `"false"`, opens a visible browser window; otherwise runs headless.
   - Requires the following gems:
     - `ferrum` – drives a real Chromium/Chrome instance so GIAE’s JavaScript runs.
     - `nokogiri` – parses the HTML to inspect the calendar.
     - `holidays` – filters out Portuguese bank holidays.
   - Creates a `Ferrum::Browser` with a generous timeout (120 seconds), optionally headless.

2. **Login to GIAE**

   - Navigates to `GIAE_LOGIN_URL`.
   - Waits until the page shows the `AUTENTICAÇÃO` heading.
   - Waits for the login inputs:
     - `#username` – “Utilizador / Nº Cartão”.
     - `#password` – “Palavra-passe”.
   - Types the username and password into these fields using realistic key events, clearing any previous content first.
   - Clicks somewhere on the `<body>` to blur the inputs so Knockout/JS bindings see the new values.
   - Finds the first `Entrar` button on the page and clicks it.
   - Waits until the home page displays the text `Bem-vindo ao netGIAE.`, confirming a successful login.

3. **Navigate to the meal acquisition calendar**

   - From the netGIAE home page:
     - Clicks the `Refeições` menu entry.
     - Clicks the `Aquisição` submenu entry.
   - Waits until the page shows both:
     - `Aquisição de Refeições`
     - The description text `Aquisição de refeições.`

   At this point, the month calendar with clickable days is visible.

4. **Wait for and parse the calendar**

   - Polls the page until it finds at least one `td` with `data-handler="selectDay"`, which is what jQuery UI uses for date cells.
   - Captures the page HTML and parses it with Nokogiri.
   - Collects all cells:
     - `td[data-handler='selectDay']`
   - If no cells are found, writes the full HTML to `giae_no_day_cells.html` and aborts so you can debug.

5. **Determine the month and year being analysed**

   - Searches the entire page text for the Portuguese month name (e.g. `Março`).
   - Maps that month name to a numeric month (`1..12`) using a static map.
   - Always sets the year to the current year:
     - `year = Date.today.year`
   - Logs which month/year is being analysed, e.g.:
     - `Analysing calendar for Março/2026`

   Note: even if the GIAE header shows a different year (e.g. 2025), the script **always** uses the system’s current year.

6. **Filter days and classify “bought” vs “not bought”**

   For each `td[data-handler='selectDay']` cell:

   - Reads the visible day number from the `<a>` inside the cell (e.g. `24`).
   - Builds a `Date` from `year`, `month`, and `day`.
   - Skips:
     - Saturdays and Sundays (`date.saturday? || date.sunday?`).
     - Portuguese national bank holidays:
       - Uses `Holidays.on(date, :pt)` from the `holidays` gem.
   - Reads the cell’s `class` attribute and splits it into class names.
     - If the classes include `highlight-green`, the script treats that date as **meal purchased**.
     - Otherwise, it treats the date as **not purchased** (e.g. `highlight` or no special class).

   For each remaining date (weekday, non‑holiday), it prints a single line:

   ```text
   YYYY-MM-DD: BOUGHT
   YYYY-MM-DD: not bought
