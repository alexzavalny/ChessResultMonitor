require 'telegram/bot'
require_relative 'command_processor'
require_relative '../utils/message_formatter'
require_relative '../../config/bot_config'

# Main Telegram bot handler
class BotHandler
  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @command_processor = CommandProcessor.new
    @subscribed_chats = Set.new
    load_subscribed_chats
  end

  def start_bot
    @logger.info("Starting Telegram bot...")
    
    Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
      @bot = bot
      
      bot.listen do |message|
        handle_message(message)
      end
    end
  rescue StandardError => e
    @logger.error("Bot error: #{e.message}")
    @logger.error(e.backtrace.join("\n"))
    raise
  end

  def send_notification_to_subscribers(message_text)
    return if @subscribed_chats.empty?
    
    @logger.info("Sending notification to #{@subscribed_chats.size} subscribers")
    
    @subscribed_chats.each do |chat_id|
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
        @subscribed_chats.delete(chat_id) if e.message.include?('chat not found')
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
          text: formatted_message,
          parse_mode: 'Markdown'
        )
      end
    rescue StandardError => e
      @logger.error("Failed to send status to chat #{chat_id}: #{e.message}")
      @bot.api.send_message(
        chat_id: chat_id,
        text: MessageFormatter.format_error_message(:unknown_error, e.message),
        parse_mode: 'Markdown'
      )
    end
  end

  private

  def handle_message(message)
    return unless message.is_a?(Telegram::Bot::Types::Message)
    return unless message.text

    chat_id = message.chat.id
    text = message.text.strip.downcase

    @logger.info("Received message from chat #{chat_id}: #{message.text}")

    # Add chat to subscribers if not already subscribed
    @subscribed_chats.add(chat_id) unless @subscribed_chats.include?(chat_id)
    save_subscribed_chats

    case text
    when '/start'
      @command_processor.handle_start_command(message, @bot)
    when '/help'
      @command_processor.handle_help_command(message, @bot)
    when 'status'
      @command_processor.handle_status_command(message, @bot)
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
        text: "❌ Sorry, something went wrong. Please try again later.",
        parse_mode: 'Markdown'
      )
    rescue StandardError
      # Ignore if we can't send error message
    end
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
