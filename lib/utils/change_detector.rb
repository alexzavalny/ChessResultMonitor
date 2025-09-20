require_relative '../models/tournament_state'

# Change detection system for tournament updates
class ChangeDetector
  def initialize
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::INFO
  end

  def detect_changes(old_state, new_state)
    return { has_changes: false, changes: [] } if old_state.nil? || new_state.nil?
    return { has_changes: false, changes: [] } if old_state.empty? && new_state.empty?

    changes = []

    # Check if this is the first time we're seeing data
    if old_state.empty? && !new_state.empty?
      changes << {
        type: :initial_data,
        message: "Tournament data loaded for the first time",
        players: new_state.players
      }
      return { has_changes: true, changes: changes }
    end

    # Check if data was lost
    if !old_state.empty? && new_state.empty?
      changes << {
        type: :data_lost,
        message: "Tournament data is no longer available",
        old_players: old_state.players
      }
      return { has_changes: true, changes: changes }
    end

    # Compare table hashes for quick change detection
    if old_state.table_hash != new_state.table_hash
      @logger.info("Table hash changed, analyzing detailed differences")
      
      # Detailed comparison
      changes.concat(detect_player_changes(old_state.players, new_state.players))
      changes.concat(detect_structure_changes(old_state, new_state))
    end

    { has_changes: !changes.empty?, changes: changes }
  end

  private

  def detect_player_changes(old_players, new_players)
    changes = []
    
    # Create lookup hashes for efficient comparison
    old_players_hash = old_players.map { |p| [p.player_name, p] }.to_h
    new_players_hash = new_players.map { |p| [p.player_name, p] }.to_h

    # Find new players
    new_players.each do |new_player|
      unless old_players_hash.key?(new_player.player_name)
        changes << {
          type: :new_player,
          message: "New player added: #{new_player.player_name}",
          player: new_player
        }
      end
    end

    # Find updated players
    old_players.each do |old_player|
      new_player = new_players_hash[old_player.player_name]
      next unless new_player

      player_changes = detect_individual_player_changes(old_player, new_player)
      changes.concat(player_changes) unless player_changes.empty?
    end

    changes
  end

  def detect_individual_player_changes(old_player, new_player)
    changes = []

    # Check for result changes
    if old_player.result != new_player.result
      changes << {
        type: :result_changed,
        message: "#{new_player.player_name}: result changed from '#{old_player.result}' to '#{new_player.result}'",
        old_player: old_player,
        new_player: new_player,
        field: :result,
        old_value: old_player.result,
        new_value: new_player.result
      }
    end

    # Check for board number changes
    if old_player.board_number != new_player.board_number
      changes << {
        type: :board_changed,
        message: "#{new_player.player_name}: board number changed from #{old_player.board_number} to #{new_player.board_number}",
        old_player: old_player,
        new_player: new_player,
        field: :board_number,
        old_value: old_player.board_number,
        new_value: new_player.board_number
      }
    end

    changes
  end

  def detect_structure_changes(old_state, new_state)
    changes = []

    # Check for player count changes
    if old_state.player_count != new_state.player_count
      changes << {
        type: :player_count_changed,
        message: "Player count changed from #{old_state.player_count} to #{new_state.player_count}",
        old_count: old_state.player_count,
        new_count: new_state.player_count
      }
    end

    changes
  end

  def format_changes_summary(changes)
    return "No changes detected" if changes.empty?

    summary = ["📊 Tournament Updates:"]
    
    changes.each do |change|
      case change[:type]
      when :initial_data
        summary << "🎯 #{change[:message]} (#{change[:players].size} players)"
      when :data_lost
        summary << "⚠️ #{change[:message]}"
      when :new_player
        summary << "➕ #{change[:message]}"
      when :points_changed
        summary << "📈 #{change[:message]}"
      when :result_changed
        summary << "🏆 #{change[:message]}"
      when :board_changed
        summary << "🔢 #{change[:message]}"
      when :player_count_changed
      else
        summary << "ℹ️ #{change[:message]}"
      end
    end

    summary.join("\n")
  end
end
