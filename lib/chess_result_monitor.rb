require 'set'
require_relative 'scraper/chess_results_scraper'
require_relative 'utils/change_detector'
require_relative 'utils/message_formatter'
require_relative 'telegram/bot_handler'
require_relative 'models/tournament_state'
require_relative '../config/tournament_config'

# Main monitoring application
class ChessResultMonitor
  PAUSED_POLL_INTERVAL = 5

  def initialize
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::INFO
    @scraper = ChessResultsScraper.new
    @change_detector = ChangeDetector.new
    @bot_handler = BotHandler.new
    @current_state = nil
    @state_file = 'data/state_cache.json'
    @running = false
    @subscribers = Set.new
    @paused = false
    
    # Ensure data directory exists
    FileUtils.mkdir_p('data') unless Dir.exist?('data')
    
    # Load previous state if available
    load_previous_state
  end

  def start_monitoring
    @logger.info("Starting Chess Result Monitor...")
    @running = true
    
    # Start the bot in a separate thread
    @bot_thread = Thread.new do
      begin
        @bot_handler.start_bot(self)
      rescue StandardError => e
        @logger.error("Bot thread error: #{e.message}")
        @running = false
      end
    end
    
    # Start monitoring loop
    start_monitoring_loop
  end

  def stop_monitoring
    @logger.info("Stopping Chess Result Monitor...")
    @running = false
    
    # Wait for bot thread to finish
    @bot_thread&.join(5) # Wait up to 5 seconds
    
    @logger.info("Chess Result Monitor stopped")
  end

  def check_for_updates
    if paused?
      @logger.debug("Skipping update check because monitoring is paused")
      return
    end

    @logger.debug("Checking for tournament updates...")
    
    begin
      # Fetch current tournament data
      new_state = @scraper.fetch_tournament_data
      
      if new_state.nil? || new_state.empty?
        @logger.warn("No tournament data received")
        return
      end
      
      # Check for changes
      changes_result = @change_detector.detect_changes(@current_state, new_state)
      
      if changes_result[:has_changes]
        @logger.info("Changes detected! Processing updates...")
        process_changes(changes_result[:changes], new_state)
      else
        @logger.debug("No changes detected")
      end
      
      # Update current state
      @current_state = new_state
      save_current_state
      
    rescue StandardError => e
      @logger.error("Error during update check: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
      raise e  # Kill the application for debugging
    end
  end

  def add_subscriber(chat_id)
    @subscribers.add(chat_id)
    @logger.info("Added subscriber: #{chat_id} (total: #{@subscribers.size})")
  end

  def pause_monitoring
    if paused?
      @logger.info("Monitoring already paused")
      return false
    end

    @paused = true
    @logger.info("Monitoring paused")
    true
  end

  def resume_monitoring
    unless paused?
      @logger.info("Monitoring already running")
      return false
    end

    @paused = false
    @logger.info("Monitoring resumed")
    true
  end

  def paused?
    @paused
  end

  private

  def start_monitoring_loop
    @logger.info("Starting monitoring loop (checking every #{MONITORING_INTERVAL} seconds)")
    
    while @running
      begin
        if paused?
          @logger.debug("Monitoring paused; sleeping before rechecking state")
          sleep([MONITORING_INTERVAL, PAUSED_POLL_INTERVAL].min)
          next
        end

        check_for_updates
        sleep(MONITORING_INTERVAL)
      rescue Interrupt
        @logger.info("Received interrupt signal, stopping...")
        break
      rescue StandardError => e
        @logger.error("Error in monitoring loop: #{e.message}")
        @logger.error(e.backtrace.join("\n"))
        raise e  # Kill the application for debugging
      end
    end
  end

  def process_changes(changes, new_state)
    @logger.info("Processing #{changes.size} changes")
    
    # Check if we should send the full table
    significant_changes = changes.any? do |change|
      [:new_player, :removed_player, :result_changed, :points_changed, :player_count_changed].include?(change[:type])
    end
    
    # Format the changes message
    changes_message = MessageFormatter.format_changes({ has_changes: true, changes: changes })
    
    # Send notification to all subscribers
    #@bot_handler.send_notification_to_subscribers(changes_message, @subscribers)
    
    # If significant changes, also send the full table
    if significant_changes
      @logger.info("Significant changes detected, sending full table to subscribers")
      full_table = MessageFormatter.format_table(new_state)
      @bot_handler.send_notification_to_subscribers(full_table, @subscribers)

      game_info = MessageFormatter.format_game_info(new_state)
      if game_info
        @logger.info("Sending game info to subscribers: #{game_info}")
        @bot_handler.send_notification_to_subscribers(game_info, @subscribers)
      else
        @logger.debug("Game info unavailable for the current state")
      end
    end
    
    # Log the changes
    changes.each do |change|
      @logger.info("Change: #{change[:message]}")
    end
  end

  def load_previous_state
    @current_state = TournamentState.load_from_file(@state_file)
    
    if @current_state.nil? || @current_state.empty?
      @logger.info("No previous state found, starting fresh")
    else
      @logger.info("Loaded previous state with #{@current_state.player_count} players")
    end
  end

  def save_current_state
    return if @current_state.nil?
    
    begin
      @current_state.save_to_file(@state_file)
      @logger.debug("State saved to #{@state_file}")
    rescue StandardError => e
      @logger.error("Failed to save state: #{e.message}")
    end
  end
end
