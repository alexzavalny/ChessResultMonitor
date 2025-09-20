# Chess Result Monitor

A Ruby-based Telegram bot that monitors chess tournament results from chess-results.com and sends real-time updates to subscribed users when the tournament table is updated.

## Features

- 🔄 Monitors tournament data every 10 seconds
- 📊 Detects changes in player standings, scores, and results
- 🤖 Sends notifications via Telegram bot
- 📱 Responds to `status` command for current table
- 🛡️ Robust error handling and retry logic
- 📝 Comprehensive logging

## Setup

### Prerequisites

- Ruby 3.0 or higher
- A Telegram bot token (get one from [@BotFather](https://t.me/botfather))

### Installation

1. Clone or download this repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up environment variables:
   ```bash
   export CHESSRESULTS_TELEGRAM_TOKEN="your_bot_token_here"
   export TELEGRAM_CHAT_IDS="chat_id1,chat_id2"  # Optional: pre-configure chat IDs
   ```

4. Create the data directory:
   ```bash
   mkdir -p data
   ```

### Running the Application

```bash
ruby main.rb
```

Or make it executable and run directly:
```bash
chmod +x main.rb
./main.rb
```

## Usage

### Telegram Bot Commands

- `/start` - Welcome message and bot introduction
- `/help` - Show available commands
- `status` - Get current tournament standings (just type "status")

### Automatic Monitoring

The bot automatically:
- Checks the tournament every 10 seconds
- Detects changes in player standings, scores, or results
- Sends notifications to all subscribed users
- Handles errors gracefully with retry logic

## Configuration

### Tournament Configuration

Edit `config/tournament_config.rb` to change:
- Tournament URL
- Monitoring interval
- Request timeout
- HTTP headers

### Bot Configuration

Edit `config/bot_config.rb` to modify:
- Bot token handling
- Chat ID management
- Error messages

## Project Structure

```
ChessResultMonitor/
├── main.rb                          # Application entry point
├── Gemfile                          # Ruby dependencies
├── config/
│   ├── bot_config.rb               # Telegram bot configuration
│   └── tournament_config.rb        # Tournament monitoring configuration
├── lib/
│   ├── chess_result_monitor.rb     # Main monitoring application
│   ├── models/
│   │   ├── player.rb               # Player data model
│   │   └── tournament_state.rb     # Tournament state management
│   ├── scraper/
│   │   └── chess_results_scraper.rb # Web scraper for chess-results.com
│   ├── telegram/
│   │   ├── bot_handler.rb          # Main Telegram bot handler
│   │   └── command_processor.rb    # Command processing logic
│   └── utils/
│       ├── change_detector.rb      # Change detection system
│       └── message_formatter.rb    # Message formatting for Telegram
├── data/
│   └── state_cache.json            # Cached tournament state
└── logs/                           # Application logs
```

## Monitoring

The application monitors the following changes:
- New players added to the tournament
- Players removed from the tournament
- Changes in player scores/points
- Changes in game results
- Changes in player club/city information
- Changes in board numbers
- Changes in tournament structure

## Error Handling

The application includes comprehensive error handling for:
- Network timeouts and connection issues
- HTML parsing errors
- Telegram API errors
- File system errors
- Invalid data formats

## Logging

Logs are written to stdout with different levels:
- `INFO`: Normal operations and successful updates
- `WARN`: Recoverable errors and retries
- `ERROR`: Critical failures and parsing errors
- `DEBUG`: Detailed operation traces

## Development

### Running Tests

```bash
bundle exec rspec
```

### Code Style

```bash
bundle exec rubocop
```

## Troubleshooting

### Common Issues

1. **Bot not responding**: Check that `CHESSRESULTS_TELEGRAM_TOKEN` is set correctly
2. **No notifications**: Ensure users have started a conversation with the bot
3. **Parsing errors**: The tournament website structure may have changed
4. **Network errors**: Check internet connection and firewall settings

### Debug Mode

Set the log level to DEBUG for more detailed output:
```ruby
@logger.level = Logger::DEBUG
```

## License

This project is open source and available under the MIT License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues and questions, please create an issue in the repository or contact the maintainers.
