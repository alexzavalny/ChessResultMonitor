require_relative '../models/tournament_state'
require_relative 'change_detector'

# Message formatting for Telegram
class MessageFormatter
  def self.format_table(tournament_state)
    return "❌ No tournament data available" if tournament_state.nil? || tournament_state.empty?

    header = "🏆 *#{tournament_state.tournament_name}*\n"
    header += "📅 Last updated: #{format_time(tournament_state.last_updated)}\n"
    header += "👥 Players: #{tournament_state.player_count}\n\n"

    table_header = "```\n"
    table_header += "Bd | Player Name                    | Club/City              | Pts | Result\n"
    table_header += "---|--------------------------------|------------------------|-----|--------\n"

    table_rows = tournament_state.players.map do |player|
      format_player_row(player)
    end

    table_footer = "```"

    header + table_header + table_rows.join("\n") + "\n" + table_footer
  end

  def self.format_changes(changes_data)
    return "No changes detected" unless changes_data[:has_changes]

    changes = changes_data[:changes]
    return "No changes detected" if changes.empty?

    summary = ["📊 *Tournament Updates:*\n"]
    
    changes.each do |change|
      case change[:type]
      when :initial_data
        summary << "🎯 #{change[:message]} (#{change[:players].size} players)"
      when :data_lost
        summary << "⚠️ #{change[:message]}"
      when :new_player
        summary << "➕ #{change[:message]}"
      when :removed_player
        summary << "➖ #{change[:message]}"
      when :points_changed
        summary << "📈 #{change[:message]}"
      when :result_changed
        summary << "🏆 #{change[:message]}"
      when :club_changed
        summary << "🏢 #{change[:message]}"
      when :board_changed
        summary << "🔢 #{change[:message]}"
      when :player_count_changed
        summary << "👥 #{change[:message]}"
      when :tournament_name_changed
        summary << "🏷️ #{change[:message]}"
      else
        summary << "ℹ️ #{change[:message]}"
      end
    end

    # Add current table if there are significant changes
    if changes.any? { |c| [:initial_data, :new_player, :removed_player, :points_changed].include?(c[:type]) }
      summary << "\n📋 *Current Standings:*"
      # Note: We don't include the full table here to avoid message length limits
      # The full table can be requested with the status command
    end

    summary.join("\n")
  end

  def self.format_status_response(tournament_state)
    if tournament_state.nil? || tournament_state.empty?
      return "❌ *Status: No Data*\n\nUnable to fetch tournament data. Please try again later."
    end

    status = "✅ *Status: Active*\n"
    status += "🏆 Tournament: *#{tournament_state.tournament_name}*\n"
    status += "📅 Last updated: #{format_time(tournament_state.last_updated)}\n"
    status += "👥 Players: #{tournament_state.player_count}\n\n"
    status += "Use /status to see the current table anytime!"
    
    status
  end

  def self.format_error_message(error_type, details = nil)
    case error_type
    when :network_error
      "❌ *Network Error*\n\nUnable to connect to the tournament server. Please try again later."
    when :parsing_error
      "❌ *Parsing Error*\n\nUnable to parse tournament data. The website structure may have changed."
    when :timeout_error
      "⏰ *Timeout Error*\n\nThe request took too long to complete. Please try again later."
    when :unknown_error
      "❌ *Unknown Error*\n\nAn unexpected error occurred: #{details}"
    else
      "❌ *Error*\n\nSomething went wrong. Please try again later."
    end
  end

  private

  def self.format_player_row(player)
    board = (player.board_number || "").to_s.ljust(2)
    name = truncate_string(player.player_name || "", 30)
    club = truncate_string(player.club_city || "", 22)
    points = (player.points || 0).to_s.ljust(3)
    result = (player.result || "").to_s.ljust(6)

    "#{board} | #{name} | #{club} | #{points} | #{result}"
  end

  def self.truncate_string(str, max_length)
    return "" if str.nil?
    return str if str.length <= max_length
    
    str[0, max_length - 3] + "..."
  end

  def self.format_time(time)
    return "Unknown" if time.nil?
    
    time.strftime("%Y-%m-%d %H:%M:%S UTC")
  end
end
