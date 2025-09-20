require_relative 'scraper/chess_results_scraper'
require_relative 'utils/change_detector'
require_relative 'utils/message_formatter'
require_relative 'telegram/bot_handler'
require_relative 'models/tournament_state'
require_relative '../config/tournament_config'

# Main monitoring application
class ChessResultMonitor
  def initialize
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::INFO
    @scraper = ChessResultsScraper.new
    @change_detector = ChangeDetector.new
    @bot_handler = BotHandler.new
    @current_state = nil
    @state_file = 'data/state_cache.json'
    @running = false
    
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
        @bot_handler.start_bot
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

  private

  def start_monitoring_loop
    @logger.info("Starting monitoring loop (checking every #{MONITORING_INTERVAL} seconds)")
    
    while @running
      begin
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
    
    # Format the changes message
    changes_message = MessageFormatter.format_changes({ has_changes: true, changes: changes })
    
    # Send notification to all subscribers
    @bot_handler.send_notification_to_subscribers(changes_message)
    
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
