require 'httparty'
require 'nokogiri'
require 'logger'
require_relative '../models/player'
require_relative '../models/tournament_state'
require_relative '../../config/tournament_config'

# Web scraper for chess-results.com
class ChessResultsScraper
  include HTTParty
  
  def initialize
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::DEBUG
  end

  def fetch_tournament_data(tournament_url = TOURNAMENT_URL)
    @logger.info("Fetching tournament data from #{tournament_url}")
    
    retries = 0
    begin
      response = HTTParty.get(tournament_url, {
        headers: HTTP_HEADERS,
        timeout: REQUEST_TIMEOUT
      })
      
      if response.success?
        parse_tournament_data(response.body)
      else
        raise "HTTP request failed with status #{response.code}: #{response.message}"
      end
    rescue Timeout::Error, Net::ReadTimeout => e
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
    # The table typically has headers like "Rd.", "Bo.", "Name", "Club/City", "Pts", "Res."
    
    tables = doc.css('table')
    @logger.debug("Found #{tables.length} tables in the document")
    
    tables.each_with_index do |table, index|
      # Get the first row to check for headers
      first_row = table.css('tr').first
      next if first_row.nil?
      
      headers = first_row.css('th, td').map(&:text).map(&:strip)
      @logger.debug("Table #{index + 1} headers: #{headers.first(10).join(', ')}")
      
      # Skip tables with empty or very few headers
      next if headers.empty? || headers.all?(&:empty?) || headers.length < 5
      
      # Look for a table that has the specific headers we expect in a clean format
      # Check if this looks like a results table with the specific headers we expect
      if headers.any? { |h| h.include?('Rd.') } && 
         headers.any? { |h| h.include?('Bo.') } && 
         headers.any? { |h| h.include?('Name') } && 
         headers.any? { |h| h.include?('Pts.') }
        
        # Additional check: make sure the headers are not too long (indicating metadata)
        if headers.length <= 15 && headers.none? { |h| h.length > 50 }
          @logger.debug("Found results table at index #{index + 1}")
          return table
        end
      end
    end
    
    @logger.warn("No results table found with expected headers")
    nil
  end

  def create_column_mapping(table)
    # Extract header row to create dynamic column mapping
    header_row = table.css('tr').first
    return {} if header_row.nil?
    
    headers = header_row.css('th, td').map(&:text).map(&:strip)
    @logger.debug("Creating column mapping from headers: #{headers.join(', ')}")
    
    column_mapping = {}
    
    headers.each_with_index do |header, index|
      header_lower = header.downcase
      
      # Map various possible header names to our standard field names
      case header_lower
      when /^rd\.?$/, /round/
        column_mapping[:round] = index
      when /^bo\.?$/, /board/
        column_mapping[:board] = index
      when /^sno/, /starting.*number/, /no\.?$/
        column_mapping[:starting_number] = index
      when /^name$/, /player/
        column_mapping[:name] = index
      when /^rtg/, /rating/
        column_mapping[:rating] = index
      when /^fed/, /federation/, /country/
        column_mapping[:federation] = index
      when /^club/, /city/, /club\/city/
        column_mapping[:club_city] = index
      when /^pts\.?$/, /points/, /score/
        column_mapping[:points] = index
      when /^res\.?$/, /result/
        column_mapping[:result] = index
      end
    end
    
    @logger.debug("Column mapping created: #{column_mapping}")
    column_mapping
  end

  def parse_table_rows(table)
    players = []
    
    # Create column mapping from table headers
    column_mapping = create_column_mapping(table)
    
    # Skip header row and parse data rows
    rows = table.css('tr')[1..-1] || []
    @logger.debug("Found #{rows.length} data rows to parse")
    
    rows.each_with_index do |row, index|
      cells = row.css('td')
      @logger.debug("Row #{index + 1}: #{cells.length} cells - #{cells.map(&:text).map(&:strip).join(' | ')}")
      
      next if cells.empty?
      
      # Only process rows that look like actual player data (11 cells with proper structure)
      # Skip tournament metadata rows (usually 2 cells or very long single cells)
      if cells.length < 8 || cells.length > 15
        @logger.debug("Skipped row #{index + 1} - wrong number of cells (#{cells.length})")
        next
      end
      
      # Check if this looks like a player row (should have numeric first cell for round number)
      first_cell = cells[0]&.text&.strip
      if first_cell.nil? || first_cell.empty? || !first_cell.match?(/^\d+$/)
        @logger.debug("Skipped row #{index + 1} - doesn't start with round number")
        next
      end
      
      begin
        player = parse_player_row(cells, index + 1, column_mapping)
        if player
          players << player
          @logger.debug("Successfully parsed player: #{player.player_name}")
        else
          @logger.debug("Skipped row #{index + 1} - no valid player data")
        end
      rescue StandardError => e
        @logger.warn("Error parsing row #{index + 1}: #{e.message}")
        @logger.debug("Row content: #{cells.map(&:text).map(&:strip).join(' | ')}")
        next
      end
    end
    
    @logger.debug("Total players parsed: #{players.length}")
    players
  end

  def parse_player_row(cells, row_number, column_mapping)
    # Use dynamic column mapping instead of hardcoded indices
    return nil if cells.size < 6
    
    # Extract data using column mapping
    board_number = extract_cell_value(cells, column_mapping[:board])
    player_name = extract_cell_value(cells, column_mapping[:name])
    club_city = extract_cell_value(cells, column_mapping[:club_city])
    points_text = extract_cell_value(cells, column_mapping[:points])
    result = extract_cell_value(cells, column_mapping[:result])
    round_number = extract_cell_value(cells, column_mapping[:round])
    
    # Strip "- " prefix from result if present
    result = result&.gsub(/^-\s*/, '') if result
    
    # Parse points
    points = parse_points(points_text)
    
    # Skip if essential data is missing
    return nil if player_name.nil? || player_name.empty?
    
    @logger.debug("Parsed player: Board=#{board_number}, Name=#{player_name}, Club=#{club_city}, Points=#{points}, Result=#{result}")
    
    Player.new(
      board_number: board_number,
      player_name: player_name,
      club_city: club_city,
      points: points,
      result: result,
      opponent: nil, # Not available in this table format
      round_number: round_number&.to_i
    )
  end

  def extract_cell_value(cells, column_index)
    return nil if column_index.nil? || column_index >= cells.length
    
    cells[column_index]&.text&.strip
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
