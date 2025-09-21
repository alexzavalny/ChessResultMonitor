require_relative '../models/tournament_state'
require_relative 'change_detector'

# Message formatting for Telegram
class MessageFormatter
  def self.format_table(tournament_state)
    return "❌ No tournament data available" if tournament_state.nil? || tournament_state.empty?

    header = "🏆 #{tournament_state.tournament_name}\n"
    header += "📅 Last updated: #{format_time(tournament_state.last_updated)}\n"
    header += "👥 Players: #{tournament_state.player_count}\n\n"

    # Calculate column widths based on actual content
    column_widths = calculate_column_widths(tournament_state.players)
    
    # Debug: log the calculated widths
    puts "DEBUG: Column widths: #{column_widths}"
    
    # Create table header with calculated widths
    table_header = "Bd | " + "Player Name".ljust(column_widths[:name]) + " | Pts | Result\n"
    # The dashes need to match the total width including spaces around the content
    dashes_line = "---|" + "-" * column_widths[:name] + "--|-----|--------\n"
    puts "DEBUG: Dashes line length: #{dashes_line.length}, dashes count: #{dashes_line.count('-')}"
    table_header += dashes_line

    table_rows = tournament_state.players.map do |player|
      format_player_row_with_widths(player, column_widths)
    end

    # Wrap the table in monospace code block
    table_content = table_header + table_rows.join("\n")
    header + "```\n" + table_content + "\n```"
  end

  def self.format_changes(changes_data)
    return "No changes detected" unless changes_data[:has_changes]

    changes = changes_data[:changes]
    return "No changes detected" if changes.empty?

    summary = ["📊 *Tournament Updates:*\n"]
    
    changes.each do |change|
      case change[:type]
      when :initial_data
        summary << "🎯 #{escape_markdown(change[:message])} (#{change[:players].size} players)"
      when :data_lost
        summary << "⚠️ #{escape_markdown(change[:message])}"
      when :new_player
        summary << "➕ #{escape_markdown(change[:message])}"
      when :points_changed
        summary << "📈 #{escape_markdown(change[:message])}"
      when :result_changed
        summary << "🏆 #{escape_markdown(change[:message])}"
      when :board_changed
        summary << "🔢 #{escape_markdown(change[:message])}"
      when :player_count_changed
        summary << "👥 #{escape_markdown(change[:message])}"
      else
        summary << "ℹ️ #{escape_markdown(change[:message])}"
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
    status += "🏆 Tournament: *#{escape_markdown(tournament_state.tournament_name)}*\n"
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

  def self.calculate_column_widths(players)
    return { name: 30, points: 3, result: 6 } if players.empty?
    
    max_name_length = players.map { |p| (p.player_name || "").length }.max
    max_points_length = players.map { |p| (p.points || 0).to_s.length }.max
    max_result_length = players.map { |p| (p.result || "").length }.max
    
    # Also check the header text length
    header_name_length = "Player Name".length
    
    {
      name: [max_name_length, header_name_length, 10].max,  # Minimum 10 characters
      points: [max_points_length, 3].max,
      result: [max_result_length, 6].max
    }
  end

  def self.format_player_row_with_widths(player, column_widths)
    board = (player.board_number || "").to_s.ljust(2)
    name = (player.player_name || "").ljust(column_widths[:name])
    points = (player.points || 0).to_s.ljust(column_widths[:points])
    result = format_result_with_emoji(player.result || "").ljust(column_widths[:result])

    row = "#{board} | #{name} | #{points} | #{result}"
    puts "DEBUG: Row: '#{row}' (name length: #{name.length}, expected: #{column_widths[:name]})"
    row
  end

  def self.format_result_with_emoji(result)
    case result.to_s.strip
    when "1"
      "🏆"
    when "0"
      "❌"
    when "0.5"
      "🤝"
    when ""
      ""
    else
      result.to_s
    end
  end

  def self.format_player_row(player)
    board = (player.board_number || "").to_s.ljust(2)
    name = truncate_string(player.player_name || "", 35)
    points = (player.points || 0).to_s.ljust(3)
    result = (player.result || "").to_s.ljust(6)

    "#{board} | #{name} | #{points} | #{result}"
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

  def self.escape_markdown(text)
    return "" if text.nil?
    
    # Escape special Markdown characters
    text.to_s.gsub(/([_*\[\]()~`>#+=|{}.!-])/, '\\\\\1')
  end
end
