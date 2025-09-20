require_relative '../scraper/chess_results_scraper'
require_relative '../utils/message_formatter'
require_relative '../../config/tournament_config'

# Command processor for Telegram bot
class CommandProcessor
  def initialize
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::DEBUG
    @scraper = ChessResultsScraper.new
  end

  def handle_status_command(message, bot)
    chat_id = message.chat.id
    
    begin
      @logger.info("Processing status command from chat #{chat_id}")
      
      # Send immediate acknowledgment
      bot.api.send_message(
        chat_id: chat_id,
        text: "🔄 Fetching current tournament table..."
      )
      
      # Fetch current tournament data
      tournament_state = @scraper.fetch_tournament_data
      
      # Format and send the table
      formatted_table = MessageFormatter.format_table(tournament_state)
      
      @logger.debug("Formatted table length: #{formatted_table.length}")
      @logger.debug("Formatted table content:")
      @logger.debug("=" * 50)
      @logger.debug(formatted_table)
      @logger.debug("=" * 50)
      
      # Split message if too long (Telegram has a 4096 character limit)
      if formatted_table.length > 4000
        @logger.debug("Message too long (#{formatted_table.length} chars), splitting into chunks")
        send_long_message(bot, chat_id, formatted_table)
      else
        @logger.debug("Sending single message (#{formatted_table.length} chars)")
        bot.api.send_message(
          chat_id: chat_id,
          text: formatted_table,
          parse_mode: 'Markdown'
        )
      end
      
      # Send additional game info message
      send_game_info_message(bot, chat_id, tournament_state)
      
      @logger.info("Status command completed successfully for chat #{chat_id}")
      
    rescue Timeout::Error, Net::ReadTimeout => e
      @logger.error("Timeout error in status command: #{e.message}")
      bot.api.send_message(
        chat_id: chat_id,
        text: MessageFormatter.format_error_message(:timeout_error)
      )
    rescue StandardError => e
      @logger.error("Error in status command: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
      bot.api.send_message(
        chat_id: chat_id,
        text: MessageFormatter.format_error_message(:unknown_error, e.message)
      )
      raise e  # Re-raise to kill the application for debugging
    end
  end

  def handle_start_command(message, bot)
    chat_id = message.chat.id
    user_name = message.from.first_name || "User"
    
    welcome_message = "🎯 *Welcome to Chess Tournament Monitor!*\n\n"
    welcome_message += "Hello #{user_name}! I'll monitor the chess tournament and notify you of any updates.\n\n"
    welcome_message += "*Available commands:*\n"
    welcome_message += "• `subscribe` - Subscribe to tournament updates\n"
    welcome_message += "• `status` - Get current tournament table\n"
    welcome_message += "• `help` - Show this help message\n\n"
    welcome_message += "I'll automatically send you updates every time the tournament table changes!"
    
    bot.api.send_message(
      chat_id: chat_id,
      text: welcome_message
    )
    
    @logger.info("Start command processed for user #{user_name} (chat #{chat_id})")
  end

  def handle_subscribe_command(message, bot, monitor)
    chat_id = message.chat.id
    user_name = message.from.first_name || "User"
    
    begin
      # Add the chat ID to the monitor's subscriber list
      monitor.add_subscriber(chat_id)
      
      subscribe_message = "✅ *Successfully Subscribed!*\n\n"
      subscribe_message += "Hello #{user_name}! You're now subscribed to tournament updates.\n\n"
      subscribe_message += "I'll send you notifications whenever the tournament table changes with:\n"
      subscribe_message += "• New results\n"
      subscribe_message += "• New players\n"
      subscribe_message += "• Any other updates\n\n"
      subscribe_message += "Use `status` to see the current table anytime!"
      
      bot.api.send_message(
        chat_id: chat_id,
        text: subscribe_message
      )
      
      @logger.info("Subscribe command processed for user #{user_name} (chat #{chat_id})")
      
    rescue StandardError => e
      @logger.error("Error in subscribe command: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
      
      # Truncate error message for Telegram
      error_msg = e.message.to_s
      error_msg = error_msg[0, 200] + "..." if error_msg.length > 200
      
      backtrace_msg = e.backtrace.first(3).join("\n")
      backtrace_msg = backtrace_msg[0, 300] + "..." if backtrace_msg.length > 300
      
      bot.api.send_message(
        chat_id: chat_id,
        text: "❌ *Subscription Failed*\n\nError: #{error_msg}\n\nBacktrace:\n#{backtrace_msg}"
      )
      raise e  # Re-raise to kill the application for debugging
    end
  end

  def handle_help_command(message, bot)
    chat_id = message.chat.id
    
    help_message = "🤖 *Chess Tournament Monitor Help*\n\n"
    help_message += "*Commands:*\n"
    help_message += "• `subscribe` - Subscribe to tournament updates\n"
    help_message += "• `status` - Get the current tournament standings\n"
    help_message += "• `help` - Show this help message\n\n"
    help_message += "*About:*\n"
    help_message += "I monitor the chess tournament every 10 seconds and notify you when the table updates with new results, new players, or any changes.\n\n"
    help_message += "The tournament I'm monitoring: *#{extract_tournament_name}*"
    
    bot.api.send_message(
      chat_id: chat_id,
      text: help_message
    )
    
    @logger.info("Help command processed for chat #{chat_id}")
  end

  def handle_unknown_command(message, bot)
    chat_id = message.chat.id
    
    unknown_message = "❓ *Unknown command*\n\n"
    unknown_message += "I didn't understand that. Here are the available commands:\n\n"
    unknown_message += "• `subscribe` - Subscribe to tournament updates\n"
    unknown_message += "• `status` - Get current tournament table\n"
    unknown_message += "• `help` - Show help information\n\n"
    unknown_message += "Just type `status` to see the current tournament standings!"
    
    bot.api.send_message(
      chat_id: chat_id,
      text: unknown_message
    )
    
    @logger.info("Unknown command processed for chat #{chat_id}: #{message.text}")
  end

  private

  def send_game_info_message(bot, chat_id, tournament_state)
    return if tournament_state.nil? || tournament_state.empty?
    
    # Extract game number and table number from tournament data
    game_number = extract_game_number(tournament_state)
    table_number = extract_table_number(tournament_state)
    
    if game_number && table_number
      game_info = "🎮 Game #{game_number} - table number #{table_number}"
      
      bot.api.send_message(
        chat_id: chat_id,
        text: game_info
      )
      
      @logger.info("Sent game info: #{game_info} to chat #{chat_id}")
    else
      @logger.debug("Could not extract game info from tournament state")
    end
  rescue StandardError => e
    @logger.error("Error sending game info message: #{e.message}")
    # Don't raise here, just log the error
  end

  def extract_game_number(tournament_state)
    # Extract game number from the highest round number in the tournament data
    return nil if tournament_state.players.empty?
    
    # Get the highest round number from all players
    max_round = tournament_state.players.map { |p| p.round_number.to_i }.max
    max_round
  end

  def extract_table_number(tournament_state)
    # Extract table number from the last player's board number
    return nil if tournament_state.players.empty?
    
    # Get the board number from the last player in the list
    last_player = tournament_state.players.last
    return nil unless last_player
    
    last_player.board_number.to_i
  end

  def send_long_message(bot, chat_id, long_text)
    # Split the message into chunks that fit within Telegram's limits
    max_length = 4000
    chunks = []
    
    current_chunk = ""
    lines = long_text.split("\n")
    
    lines.each do |line|
      if (current_chunk + line + "\n").length > max_length
        chunks << current_chunk.strip
        current_chunk = line + "\n"
      else
        current_chunk += line + "\n"
      end
    end
    
    chunks << current_chunk.strip unless current_chunk.strip.empty?
    
    # Send each chunk
    chunks.each_with_index do |chunk, index|
      bot.api.send_message(
        chat_id: chat_id,
        text: chunk,
        parse_mode: 'Markdown'
      )
      
      # Small delay between messages to avoid rate limiting
      sleep(0.5) if index < chunks.length - 1
    end
  end

  def extract_tournament_name
    # Extract tournament name from the URL or configuration
    "ChessMania Tournament"
  end
end
