# Tinysums

Tinysums is a Rails 8 app that periodically fetches the current top 30 stories from Hacker News and uses AI to generate summaries for both the articles and their comment threads. It features a React frontend embedded within the Rails application.

This README provides instructions for setting up and running the application locally.

## Tech Stack

* Ruby 3.4.2
* Rails 8.0.2
* Node.js 23.10.0
* Yarn
* PostgreSQL
* Redis
* Sidekiq
* React
* Tailwind CSS
* Gemini API
* Perplexity API

### AI Usage Notes

By default:

* **Perplexity:** Used for extracting structured information from story URLs.
* **Gemini:** Used for all other AI tasks, including generating summaries (for stories and comments) and performing classifications.

## Prerequisites

Before you begin, ensure you have the following installed:

* Ruby 3.4.2 (consider using a version manager like `rbenv` or `rvm`)
* Node.js 23.10.0 (consider using a version manager like `nvm`)
* Yarn package manager (`npm install -g yarn`)
* PostgreSQL database server
* Redis server

## Setup Instructions

1. **Clone the repository:**

    ```bash
    git clone <repository-url> # Replace with the actual URL
    cd tinysums
    ```

2. **Install Ruby dependencies:**

    ```bash
    bundle install
    ```

3. **Install Node.js dependencies:**

    ```bash
    yarn install
    ```

4. **Configure Environment Variables:**

    Create a `.env` file in the root of the project. You will need to add API keys for Google AI (Gemini) and Perplexity, along with connection URLs for your database and Redis instance.

    ```dotenv
    # Example .env file
    DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/tinysums_development
    REDIS_URL=redis://<host>:<port>/<db_number>
    GOOG_GEM_API_KEY=your_google_ai_gemini_api_key
    PERP_API_KEY=your_perplexity_api_key
    ```

    * Replace placeholders (`<...>`) with your actual database and Redis connection details. Ensure the user specified in `DATABASE_URL` exists and has privileges on the `tinysums_development` database.
    * Obtain API keys from [Google AI Studio](https://aistudio.google.com/) (for Gemini) and [Perplexity Labs](https://docs.perplexity.ai/) (ensure it's a key for their API, not just a Pro account).
    * **API Keys are required** for the core summarization functionality.

5. **Setup the database:**

    ```bash
    # Create the development and test databases
    rails db:create

    # Run database migrations
    rails db:migrate
    ```

## Running the Application

1. **Ensure PostgreSQL and Redis servers are running.**

2. **Start the application components (Web server, JS/CSS builders):**

    Use the `bin/dev` command, which utilizes the `Procfile.dev` configuration:

    ```bash
    bin/dev
    ```

3. **Access the application:**

    Open your web browser and navigate to `http://localhost:3000`.

## Running Background Jobs (Sidekiq)

**Important:** The application will initially appear empty (no stories listed) when you first access it. You must run the `TopStoriesSummaryJob` (via Sidekiq) at least once to fetch and summarize the initial set of Hacker News stories. Subsequent runs of the job will refresh the stories database and regenerate summaries as needed.

1. **Start Sidekiq:**

    In a **separate terminal window**, run the following command from the project root to start the Sidekiq worker process:

    ```bash
    bundle exec sidekiq
    ```

2. **Manually Triggering the Summary Job (Optional):**

    The `TopStoriesSummaryJob` is responsible for fetching and summarizing stories. While it runs automatically hourly, you can trigger it manually for initial population or testing.

    Open a Rails console:

    ```bash
    bin/rails c
    ```

    Then, run the following command within the console to enqueue the job:

    ```ruby
    # Enqueue the job to run asynchronously via Sidekiq
    TopStoriesSummaryJob.perform_async
    ```

    *Note: This job fetches data and makes multiple AI API calls. It might take some time to complete depending on the number of stories and API response times. Monitor the Sidekiq process terminal for progress.*

3. **Automatic Hourly Job:**

    As configured in `config/schedule.yml`, the `TopStoriesSummaryJob` is automatically scheduled to run via Sidekiq Cron at the top of every hour.

## License

This project is released under the MIT License. See the [LICENSE](LICENSE) file for details.
