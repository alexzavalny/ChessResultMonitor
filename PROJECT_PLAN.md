# ChessResultMonitor Project Plan

## Project Overview
A Ruby-based Telegram bot that monitors chess tournament results from chess-results.com and sends real-time updates to subscribed users when the tournament table is updated.

## Requirements Analysis
- **Language**: Ruby
- **Platform**: Telegram Bot
- **Monitoring Frequency**: Every 10 seconds
- **Target URL**: https://s3.chess-results.com/tnr1163083.aspx?art=9&fed=LAT&turdet=YES&snr=63&SNode=S0
- **Functionality**: Detect table changes and send updates to Telegram users

## Technical Architecture

### 1. Core Components

#### 1.1 Web Scraper Module
- **Purpose**: Extract tournament table data from chess-results.com
- **Technology**: Ruby with HTTP client (Net::HTTP or HTTParty)
- **HTML Parser**: Nokogiri for parsing HTML content
- **Data Structure**: Parse table rows containing:
  - Board number (Rd.Bo)
  - Player names
  - Club/City information
  - Points
  - Results

#### 1.2 Change Detection System
- **Purpose**: Compare current table state with previous state
- **Method**: Hash-based comparison or detailed field-by-field comparison
- **Storage**: In-memory cache or simple file-based storage
- **Detection Logic**: 
  - Compare table structure (number of rows)
  - Compare individual cell values
  - Detect new players, updated scores, or changed pairings

#### 1.3 Telegram Bot Integration
- **Purpose**: Send notifications to subscribed users
- **Technology**: telegram-bot-ruby gem
- **Features**:
  - User subscription management
  - Message formatting for table updates
  - Error handling and retry logic
  - Status command to send current table on demand
  - Real-time table fetching for status requests

#### 1.4 Scheduler
- **Purpose**: Execute monitoring every 10 seconds
- **Technology**: Ruby's built-in threading or cron-like scheduler
- **Implementation**: Loop with sleep(10) or use rufus-scheduler gem

### 2. Data Models

#### 2.1 Player Data Structure
```ruby
Player = Struct.new(
  :board_number,
  :player_name,
  :club_city,
  :points,
  :result,
  :opponent
)
```

#### 2.2 Tournament State
```ruby
TournamentState = Struct.new(
  :last_updated,
  :players,
  :table_hash,
  :raw_html
)
```

### 3. File Structure
```
ChessResultMonitor/
├── Gemfile
├── Gemfile.lock
├── README.md
├── config/
│   ├── bot_config.rb
│   └── tournament_config.rb
├── lib/
│   ├── chess_result_monitor.rb
│   ├── scraper/
│   │   └── chess_results_scraper.rb
│   ├── telegram/
│   │   ├── bot_handler.rb
│   │   └── command_processor.rb
│   ├── models/
│   │   ├── player.rb
│   │   └── tournament_state.rb
│   └── utils/
│       ├── change_detector.rb
│       └── message_formatter.rb
├── data/
│   └── state_cache.json
├── logs/
│   └── monitor.log
└── spec/
    ├── scraper_spec.rb
    ├── change_detector_spec.rb
    └── bot_handler_spec.rb
```

### 4. Implementation Phases

#### Phase 1: Basic Infrastructure (Week 1)
1. **Project Setup**
   - Initialize Ruby project with Bundler
   - Create Gemfile with required dependencies
   - Set up basic project structure

2. **Web Scraping Foundation**
   - Implement HTTP client for fetching the target URL
   - Create HTML parser for extracting table data
   - Handle basic error cases (network timeouts, invalid responses)

3. **Data Models**
   - Define Player and TournamentState structures
   - Implement serialization/deserialization for state persistence

#### Phase 2: Change Detection (Week 2)
1. **State Management**
   - Implement state caching mechanism
   - Create change detection algorithms
   - Add logging for debugging and monitoring

2. **Testing Framework**
   - Set up RSpec for unit testing
   - Create test fixtures with sample HTML data
   - Implement integration tests

#### Phase 3: Telegram Integration (Week 3)
1. **Bot Setup**
   - Create Telegram bot using BotFather
   - Implement basic bot commands (/start, /stop, /status)
   - Add user subscription management
   - Implement "status" text command to send current table

2. **Message Formatting**
   - Design readable table format for Telegram
   - Implement diff formatting for changes
   - Add emoji and formatting for better UX
   - Create status command response with current table

3. **Status Command Implementation**
   - Listen for "status" text messages from users
   - Fetch current table data on demand
   - Format table for immediate display
   - Handle errors gracefully (network issues, parsing failures)
   - Provide user feedback for command processing

#### Phase 4: Monitoring & Scheduling (Week 4)
1. **Scheduler Implementation**
   - Implement 10-second monitoring loop
   - Add error handling and recovery mechanisms
   - Implement graceful shutdown

2. **Production Readiness**
   - Add comprehensive logging
   - Implement configuration management
   - Add monitoring and alerting for bot health

### 5. Dependencies

#### 5.1 Required Gems
```ruby
gem 'telegram-bot-ruby', '~> 0.15'
gem 'nokogiri', '~> 1.13'
gem 'httparty', '~> 0.21'
gem 'rufus-scheduler', '~> 3.8'
gem 'json', '~> 2.6'
gem 'logger', '~> 1.5'
```

#### 5.2 Development Gems
```ruby
gem 'rspec', '~> 3.12'
gem 'webmock', '~> 3.18'
gem 'vcr', '~> 6.1'
gem 'rubocop', '~> 1.50'
```

### 6. Configuration

#### 6.1 Bot Configuration
```ruby
# config/bot_config.rb
BOT_TOKEN = ENV['CHESSRESULTS_TELEGRAM_TOKEN']
CHAT_IDS = ENV['TELEGRAM_CHAT_IDS'].split(',')
```

#### 6.2 Status Command Implementation
```ruby
# lib/telegram/command_processor.rb
class CommandProcessor
  def handle_status_command(message, bot)
    begin
      # Send "Fetching current table..." message
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "🔄 Fetching current tournament table..."
      )
      
      # Fetch current table data
      current_table = ChessResultsScraper.new.fetch_tournament_data
      
      # Format and send table
      formatted_table = MessageFormatter.format_table(current_table)
      bot.api.send_message(
        chat_id: message.chat.id,
        text: formatted_table,
        parse_mode: 'HTML'
      )
    rescue => e
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "❌ Error fetching table: #{e.message}"
      )
    end
  end
end
```

#### 6.3 Tournament Configuration
```ruby
# config/tournament_config.rb
TOURNAMENT_URL = 'https://s3.chess-results.com/tnr1163083.aspx?art=9&fed=LAT&turdet=YES&snr=63&SNode=S0'
MONITORING_INTERVAL = 10 # seconds
```

### 7. Bot Message Handling Flow

#### 7.1 Message Processing
1. **Message Reception**: Bot receives all incoming messages
2. **Command Detection**: Check if message text matches "status" (case-insensitive)
3. **Status Command Flow**:
   - Send immediate acknowledgment ("Fetching current table...")
   - Fetch fresh data from chess-results.com
   - Parse and format table data
   - Send formatted table to user
   - Handle any errors with user-friendly messages

#### 7.2 Status Command Features
- **Real-time Data**: Always fetches fresh data, not cached
- **User Feedback**: Immediate response to show command is being processed
- **Error Handling**: Graceful error messages for network or parsing issues
- **Formatting**: Same table format as change notifications for consistency

### 8. Error Handling Strategy

#### 8.1 Network Errors
- Implement exponential backoff for failed requests
- Add timeout handling (30 seconds max)
- Log network errors for debugging

#### 8.2 Parsing Errors
- Graceful handling of HTML structure changes
- Fallback parsing strategies
- Alert administrators of parsing failures

#### 8.3 Telegram API Errors
- Retry failed message sends
- Handle rate limiting
- Implement user notification for service issues

### 9. Monitoring & Logging

#### 9.1 Log Levels
- **INFO**: Normal operations, successful updates
- **WARN**: Recoverable errors, retries
- **ERROR**: Critical failures, parsing errors
- **DEBUG**: Detailed operation traces

#### 9.2 Metrics to Track
- Number of successful checks per hour
- Number of changes detected
- Response times for HTTP requests
- Telegram message delivery success rate

### 10. Deployment Considerations

#### 10.1 Environment Setup
- Ruby version: 3.0+
- Required environment variables
- Process management (systemd, PM2, or similar)

#### 10.2 Security
- Secure storage of bot tokens
- Input validation for all user inputs
- Rate limiting for bot commands

#### 10.3 Scalability
- Design for multiple tournament monitoring
- Efficient memory usage for state storage
- Configurable monitoring intervals

### 11. Testing Strategy

#### 11.1 Unit Tests
- Individual component testing
- Mock external dependencies
- Test error conditions

#### 11.2 Integration Tests
- End-to-end bot functionality
- Real HTTP requests (with VCR)
- Telegram API integration

#### 11.3 Performance Tests
- Memory usage monitoring
- Response time benchmarks
- Concurrent user handling

### 12. Future Enhancements

#### 12.1 Additional Features
- Support for multiple tournaments
- User preferences for notification types
- Historical data storage
- Web dashboard for monitoring

#### 12.2 Advanced Monitoring
- Tournament-specific change detection
- Smart filtering of irrelevant updates
- Custom notification schedules

### 13. Success Criteria

#### 13.1 Functional Requirements
- ✅ Monitors target URL every 10 seconds
- ✅ Detects table changes accurately
- ✅ Sends formatted updates to Telegram
- ✅ Handles errors gracefully
- ✅ Responds to "status" command with current table

#### 13.2 Performance Requirements
- ✅ Response time < 5 seconds per check
- ✅ 99% uptime for monitoring
- ✅ Accurate change detection (no false positives)

#### 13.3 User Experience
- ✅ Clear, readable table updates
- ✅ Reliable notification delivery
- ✅ Easy bot interaction

## Next Steps

1. **Immediate Actions**:
   - Set up Ruby project structure
   - Create Telegram bot via BotFather
   - Implement basic web scraping functionality

2. **Week 1 Deliverables**:
   - Working HTML parser for tournament table
   - Basic data models and state management
   - Initial test suite

3. **Project Timeline**: 4 weeks total
   - Week 1: Infrastructure and scraping
   - Week 2: Change detection and testing
   - Week 3: Telegram integration
   - Week 4: Production deployment and monitoring

This plan provides a comprehensive roadmap for building a robust chess tournament monitoring system with Ruby and Telegram integration.
