#!/bin/bash

echo "🏆 Setting up Chess Result Monitor..."

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 3.0 or higher."
    exit 1
fi

# Check Ruby version
RUBY_VERSION=$(ruby -v | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$RUBY_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ Ruby version $RUBY_VERSION is too old. Please install Ruby 3.0 or higher."
    exit 1
fi

echo "✅ Ruby version $RUBY_VERSION is compatible"

# Install dependencies
echo "📦 Installing dependencies..."
bundle install

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"

# Create data directory
echo "📁 Creating data directory..."
mkdir -p data

# Create logs directory
echo "📁 Creating logs directory..."
mkdir -p logs

# Check for environment variables
echo "🔧 Checking configuration..."

if [ -z "$CHESSRESULTS_TELEGRAM_TOKEN" ]; then
    echo "⚠️  CHESSRESULTS_TELEGRAM_TOKEN environment variable is not set"
    echo "   Please set it with: export CHESSRESULTS_TELEGRAM_TOKEN='your_bot_token_here'"
    echo "   Get a bot token from @BotFather on Telegram"
else
    echo "✅ CHESSRESULTS_TELEGRAM_TOKEN is configured"
fi

if [ -z "$TELEGRAM_CHAT_IDS" ]; then
    echo "ℹ️  TELEGRAM_CHAT_IDS is not set (optional)"
    echo "   Users will be added as subscribers when they interact with the bot"
else
    echo "✅ TELEGRAM_CHAT_IDS is configured"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "To run the application:"
echo "  ruby main.rb"
echo ""
echo "Or make it executable and run:"
echo "  chmod +x main.rb"
echo "  ./main.rb"
echo ""
echo "For help, see README.md"
