require 'httparty'
require 'nokogiri'
require_relative '../models/player'
require_relative '../models/tournament_state'
require_relative '../../config/tournament_config'

# Web scraper for chess-results.com
class ChessResultsScraper
  include HTTParty
  
  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  def fetch_tournament_data
    @logger.info("Fetching tournament data from #{TOURNAMENT_URL}")
    
    retries = 0
    begin
      response = HTTParty.get(TOURNAMENT_URL, {
        headers: HTTP_HEADERS,
        timeout: REQUEST_TIMEOUT
      })
      
      if response.success?
        parse_tournament_data(response.body)
      else
        raise "HTTP request failed with status #{response.code}: #{response.message}"
      end
    rescue Net::TimeoutError, Net::ReadTimeout => e
      retries += 1
      if retries <= MAX_RETRIES
        @logger.warn("Request timeout, retrying (#{retries}/#{MAX_RETRIES}): #{e.message}")
        sleep(2 ** retries) # Exponential backoff
        retry
      else
        @logger.error("Max retries reached for tournament data fetch: #{e.message}")
        raise
      end
    rescue StandardError => e
      @logger.error("Error fetching tournament data: #{e.message}")
      raise
    end
  end

  private

  def parse_tournament_data(html)
    doc = Nokogiri::HTML(html)
    
    # Extract tournament name
    tournament_name = extract_tournament_name(doc)
    
    # Find the main results table
    table = find_results_table(doc)
    
    if table.nil?
      @logger.warn("No results table found in HTML")
      return TournamentState.new(tournament_name: tournament_name)
    end

    # Parse table rows
    players = parse_table_rows(table)
    
    # Generate table hash for change detection
    table_hash = generate_table_hash(players)
    
    @logger.info("Successfully parsed #{players.size} players from tournament table")
    
    TournamentState.new(
      tournament_name: tournament_name,
      last_updated: Time.now,
      players: players,
      table_hash: table_hash,
      raw_html: html
    )
  end

  def extract_tournament_name(doc)
    # Try to find tournament name in various locations
    title_element = doc.at_css('title')
    if title_element
      title_text = title_element.text.strip
      # Extract tournament name from title (usually contains "ChessMania" or similar)
      if title_text.include?('ChessMania')
        return 'ChessMania Tournament'
      elsif title_text.include?('Turnīrs')
        return 'Chess Tournament'
      end
    end
    
    # Look for tournament name in page content
    tournament_heading = doc.at_css('h1, h2, .tournament-name')
    if tournament_heading
      return tournament_heading.text.strip
    end
    
    'Chess Tournament' # Default fallback
  end

  def find_results_table(doc)
    # Look for the main results table with player data
    # The table typically has headers like "Rd.Bo", "Name", "Club/City", "Pts", "Res."
    
    tables = doc.css('table')
    
    tables.find do |table|
      headers = table.css('th, td').map(&:text).map(&:strip)
      # Check if this looks like a results table
      headers.any? { |h| h.include?('Rd.Bo') || h.include?('Name') || h.include?('Pts') }
    end
  end

  def parse_table_rows(table)
    players = []
    
    # Skip header row and parse data rows
    rows = table.css('tr')[1..-1] || []
    
    rows.each_with_index do |row, index|
      cells = row.css('td')
      next if cells.empty?
      
      begin
        player = parse_player_row(cells, index + 1)
        players << player if player
      rescue StandardError => e
        @logger.warn("Error parsing row #{index + 1}: #{e.message}")
        next
      end
    end
    
    players
  end

  def parse_player_row(cells, row_number)
    # Expected cell structure based on the HTML sample:
    # [0] - Rd.Bo (round/board number)
    # [1] - SNo (starting number)
    # [2] - Name
    # [3] - Club/City
    # [4] - Pts (points)
    # [5] - Res. (result)
    
    return nil if cells.size < 4
    
    # Extract board number (first cell)
    board_number = cells[0]&.text&.strip
    
    # Extract player name (usually in the 3rd cell)
    player_name = cells[2]&.text&.strip
    
    # Extract club/city (usually in the 4th cell)
    club_city = cells[3]&.text&.strip
    
    # Extract points (usually in the 5th cell)
    points_text = cells[4]&.text&.strip
    points = parse_points(points_text)
    
    # Extract result (usually in the 6th cell)
    result = cells[5]&.text&.strip
    
    # Skip if essential data is missing
    return nil if player_name.nil? || player_name.empty?
    
    Player.new(
      board_number: board_number,
      player_name: player_name,
      club_city: club_city,
      points: points,
      result: result,
      opponent: nil # Not available in this table format
    )
  end

  def parse_points(points_text)
    return nil if points_text.nil? || points_text.empty?
    
    # Handle various point formats (e.g., "3,5", "3.5", "3")
    points_text.gsub(',', '.').to_f
  rescue StandardError
    nil
  end

  def generate_table_hash(players)
    # Create a hash of the table data for change detection
    table_data = players.map do |player|
      {
        board: player.board_number,
        name: player.player_name,
        club: player.club_city,
        points: player.points,
        result: player.result
      }
    end
    
    table_data.hash
  end
end
