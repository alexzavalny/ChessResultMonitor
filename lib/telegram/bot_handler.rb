require 'telegram/bot'
require_relative 'command_processor'
require_relative '../utils/message_formatter'
require_relative '../../config/bot_config'

# Main Telegram bot handler
class BotHandler
  def initialize
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::INFO
    @command_processor = CommandProcessor.new
    @subscribed_chats = Set.new
    load_subscribed_chats
  end

  def start_bot(monitor = nil)
    @logger.info("Starting Telegram bot...")
    @monitor = monitor
    
    Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
      @bot = bot
      
      bot.listen do |message|
        handle_message(message, @monitor)
      end
    end
  rescue StandardError => e
    @logger.error("Bot error: #{e.message}")
    @logger.error(e.backtrace.join("\n"))
    raise e  # Kill the application for debugging
  end

  def send_notification_to_subscribers(message_text, subscribers = nil)
    target_chats = subscribers || @subscribed_chats
    return if target_chats.empty?
    
    @logger.info("Sending notification to #{target_chats.size} subscribers")
    
    target_chats.each do |chat_id|
      begin
        @bot.api.send_message(
          chat_id: chat_id,
          text: message_text,
          parse_mode: 'Markdown'
        )
        @logger.debug("Notification sent to chat #{chat_id}")
      rescue StandardError => e
        @logger.error("Failed to send notification to chat #{chat_id}: #{e.message}")
        # Remove invalid chat IDs
        target_chats.delete(chat_id) if e.message.include?('chat not found')
      end
    end
  end

  def send_status_to_chat(chat_id, tournament_state)
    begin
      formatted_message = MessageFormatter.format_table(tournament_state)
      
      if formatted_message.length > 4000
        send_long_message(chat_id, formatted_message)
      else
        @bot.api.send_message(
          chat_id: chat_id,
          text: formatted_message
        )
      end
    rescue StandardError => e
      @logger.error("Failed to send status to chat #{chat_id}: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
      @bot.api.send_message(
        chat_id: chat_id,
        text: MessageFormatter.format_error_message(:unknown_error, e.message)
      )
      raise e  # Kill the application for debugging
    end
  end

  private

  def handle_message(message, monitor = nil)
    return unless message.is_a?(Telegram::Bot::Types::Message)
    return unless message.text

    chat_id = message.chat.id
    text = message.text.strip.downcase

    @logger.info("Received message from chat #{chat_id}: #{message.text}")

    case text
    when '/start', 'start'
      @command_processor.handle_start_command(message, @bot)
    when '/help', 'help'
      @command_processor.handle_help_command(message, @bot)
    when '/status', 'status'
      @command_processor.handle_status_command(message, @bot, monitor)
    when '/subscribe', 'subscribe'
      if monitor
        @command_processor.handle_subscribe_command(message, @bot, monitor)
      else
        @command_processor.handle_unknown_command(message, @bot)
      end
    when %r{\A/seturl(?:@\w+)?\b}, %r{\Aseturl\b}
      if monitor
        @command_processor.handle_set_url_command(message, @bot, monitor)
      else
        @command_processor.handle_unknown_command(message, @bot)
      end
    when '/pause', 'pause'
      if monitor
        @command_processor.handle_pause_command(message, @bot, monitor)
      else
        @command_processor.handle_unknown_command(message, @bot)
      end
    when '/resume', 'resume'
      if monitor
        @command_processor.handle_resume_command(message, @bot, monitor)
      else
        @command_processor.handle_unknown_command(message, @bot)
      end
    else
      @command_processor.handle_unknown_command(message, @bot)
    end
  rescue StandardError => e
    @logger.error("Error handling message: #{e.message}")
    @logger.error(e.backtrace.join("\n"))
    
    # Send error message to user
    begin
      @bot.api.send_message(
        chat_id: message.chat.id,
        text: "❌ Sorry, something went wrong. Please try again later."
      )
    rescue StandardError
      # Ignore if we can't send error message
    end
    
    raise e  # Kill the application for debugging
  end

  def send_long_message(chat_id, long_text)
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
      @bot.api.send_message(
        chat_id: chat_id,
        text: chunk,
        parse_mode: 'Markdown'
      )
      
      # Small delay between messages to avoid rate limiting
      sleep(0.5) if index < chunks.length - 1
    end
  end

  def load_subscribed_chats
    # Load subscribed chat IDs from environment or file
    if CHAT_IDS.any?
      @subscribed_chats = Set.new(CHAT_IDS.map(&:to_i))
      @logger.info("Loaded #{@subscribed_chats.size} subscribed chats from configuration")
    else
      @subscribed_chats = Set.new
      @logger.info("No pre-configured chat IDs, will add users as they interact with the bot")
    end
  end

  def save_subscribed_chats
    # In a production environment, you might want to persist this to a database
    # For now, we'll just log the current subscribers
    @logger.info("Current subscribers: #{@subscribed_chats.to_a}")
  end
end
