# Telegram Bot Configuration
BOT_TOKEN = ENV['CHESSRESULTS_TELEGRAM_TOKEN']
CHAT_IDS = ENV['TELEGRAM_CHAT_IDS']&.split(',') || []

# Validate required configuration
if BOT_TOKEN.nil? || BOT_TOKEN.empty?
  raise "CHESSRESULTS_TELEGRAM_TOKEN environment variable is required"
end

if CHAT_IDS.empty?
  puts "Warning: No CHAT_IDS configured. Bot will only respond to direct messages."
end
