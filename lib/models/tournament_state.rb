require 'json'
require_relative 'player'

# Tournament state management
class TournamentState
  attr_accessor :last_updated, :players, :table_hash, :raw_html, :tournament_name

  def initialize(tournament_name: nil, last_updated: nil, players: [], table_hash: nil, raw_html: nil)
    @tournament_name = tournament_name
    @last_updated = last_updated || Time.now
    @players = players
    @table_hash = table_hash
    @raw_html = raw_html
  end

  def to_hash
    {
      tournament_name: @tournament_name,
      last_updated: @last_updated&.iso8601,
      players: @players.map(&:to_hash),
      table_hash: @table_hash,
      raw_html: @raw_html
    }
  end

  def to_json(*args)
    to_hash.to_json(*args)
  end

  def self.from_json(json_string)
    data = JSON.parse(json_string, symbolize_names: true)
    
    players = data[:players]&.map do |player_data|
      Player.new(
        board_number: player_data[:board_number],
        player_name: player_data[:player_name],
        club_city: player_data[:club_city],
        points: player_data[:points],
        result: player_data[:result],
        opponent: player_data[:opponent],
        fide_id: player_data[:fide_id],
        rating: player_data[:rating]
      )
    end || []

    new(
      tournament_name: data[:tournament_name],
      last_updated: data[:last_updated] ? Time.parse(data[:last_updated]) : Time.now,
      players: players,
      table_hash: data[:table_hash],
      raw_html: data[:raw_html]
    )
  end

  def save_to_file(file_path)
    File.write(file_path, to_json)
  end

  def self.load_from_file(file_path)
    return new unless File.exist?(file_path)
    
    from_json(File.read(file_path))
  rescue JSON::ParserError, StandardError => e
    puts "Error loading tournament state: #{e.message}"
    new
  end

  def ==(other)
    return false unless other.is_a?(TournamentState)
    
    @table_hash == other.table_hash &&
    @players == other.players
  end

  def hash
    [@table_hash, @players].hash
  end

  def eql?(other)
    self == other
  end

  def empty?
    @players.nil? || @players.empty?
  end

  def player_count
    @players&.size || 0
  end
end
