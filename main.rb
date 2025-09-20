#!/usr/bin/env ruby

require 'bundler/setup'
require_relative 'lib/chess_result_monitor'
require_relative 'config/bot_config'
require_relative 'config/tournament_config'

# Main application entry point
def main
  puts "🏆 Chess Result Monitor Starting..."
  puts "Tournament URL: #{TOURNAMENT_URL}"
  puts "Monitoring interval: #{MONITORING_INTERVAL} seconds"
  puts "Bot token configured: #{BOT_TOKEN ? 'Yes' : 'No'}"
  puts ""

  # Create and start the monitor
  monitor = ChessResultMonitor.new
  
  # Handle graceful shutdown
  trap('INT') do
    puts "\n🛑 Shutting down gracefully..."
    monitor.stop_monitoring
    exit(0)
  end

  trap('TERM') do
    puts "\n🛑 Shutting down gracefully..."
    monitor.stop_monitoring
    exit(0)
  end

  # Start monitoring
  monitor.start_monitoring
rescue StandardError => e
  puts "❌ Fatal error: #{e.message}"
  puts e.backtrace.join("\n")
  exit(1)
end

# Run the application
main if __FILE__ == $0
