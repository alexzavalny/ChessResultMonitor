require_relative '../scraper/chess_results_scraper'
require_relative '../utils/message_formatter'
require_relative '../../config/tournament_config'

# Command processor for Telegram bot
class CommandProcessor
  def initialize
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::INFO
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
          text: formatted_table
        )
      end
      
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
    welcome_message += "• `status` - Get current tournament table\n"
    welcome_message += "• `help` - Show this help message\n\n"
    welcome_message += "I'll automatically send you updates every time the tournament table changes!"
    
    bot.api.send_message(
      chat_id: chat_id,
      text: welcome_message
    )
    
    @logger.info("Start command processed for user #{user_name} (chat #{chat_id})")
  end

  def handle_help_command(message, bot)
    chat_id = message.chat.id
    
    help_message = "🤖 *Chess Tournament Monitor Help*\n\n"
    help_message += "*Commands:*\n"
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
