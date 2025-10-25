require 'spec_helper'
require_relative '../../lib/scraper/chess_results_scraper'

RSpec.describe ChessResultsScraper do
  let(:scraper) { ChessResultsScraper.new }

  describe '#initialize' do
    it 'creates a scraper instance' do
      expect(scraper).to be_a(ChessResultsScraper)
    end
  end

  describe '#fetch_tournament_data' do
    let(:sample_html) do
      <<~HTML
        <html>
          <head><title>ChessMania Tournament</title></head>
          <body>
            <table>
              <tr>
                <th>Rd.</th>
                <th>Bo.</th>
                <th>SNo</th>
                <th>Name</th>
                <th>Rtg</th>
                <th>FED</th>
                <th>Club/City</th>
                <th>Pts.</th>
                <th>Res.</th>
              </tr>
              <tr>
                <td>1</td>
                <td>6</td>
                <td>6</td>
                <td>Bodaks, Leonards</td>
                <td>1496</td>
                <td>LAT</td>
                <td>Rīgas Šaha skola/ D.Matisone</td>
                <td>6</td>
                <td>- 0</td>
              </tr>
              <tr>
                <td>2</td>
                <td>6</td>
                <td>11</td>
                <td>Malcevs, Timofejs</td>
                <td>0</td>
                <td>LAT</td>
                <td>Mifan Chess/ A.Jazdanovs</td>
                <td>5</td>
                <td>- 0</td>
              </tr>
            </table>
          </body>
        </html>
      HTML
    end

    before do
      stub_request(:get, "https://s3.chess-results.com/tnr1163083.aspx?art=9&fed=LAT&turdet=YES&snr=63&SNode=S0")
        .to_return(status: 200, body: sample_html, headers: { 'Content-Type' => 'text/html' })
    end

    it 'fetches and parses tournament data' do
      VCR.use_cassette('tournament_data') do
        result = scraper.fetch_tournament_data
        
        expect(result).to be_a(TournamentState)
        expect(result.tournament_name).to include('Latvijas')
        expect(result.players.size).to eq(9)
        expect(result.players.first.player_name).to eq('Bodaks, Leonards')
        expect(result.players.first.points).to eq(6.0)
        expect(result.players.first.board_number).to eq('6')
        expect(result.players.first.club_city).to eq('Rīgas Šaha skola/ D.Matisone')
        expect(result.players.first.result).to eq('0')
        expect(result.players.first.round_number).to eq(1)
      end
    end
  end

  describe '#create_column_mapping' do
    let(:table_with_standard_headers) do
      Nokogiri::HTML(<<~HTML).css('table').first
        <table>
          <tr>
            <th>Rd.</th>
            <th>Bo.</th>
            <th>SNo</th>
            <th>Name</th>
            <th>Rtg</th>
            <th>FED</th>
            <th>Club/City</th>
            <th>Pts.</th>
            <th>Res.</th>
          </tr>
        </table>
      HTML
    end

    let(:table_with_different_headers) do
      Nokogiri::HTML(<<~HTML).css('table').first
        <table>
          <tr>
            <th>Round</th>
            <th>Board</th>
            <th>Starting Number</th>
            <th>Player</th>
            <th>Rating</th>
            <th>Federation</th>
            <th>Club</th>
            <th>Points</th>
            <th>Result</th>
          </tr>
        </table>
      HTML
    end

    it 'creates correct mapping for standard headers' do
      mapping = scraper.send(:create_column_mapping, table_with_standard_headers)
      
      expect(mapping[:round]).to eq(0)
      expect(mapping[:board]).to eq(1)
      expect(mapping[:starting_number]).to eq(2)
      expect(mapping[:name]).to eq(3)
      expect(mapping[:rating]).to eq(4)
      expect(mapping[:federation]).to eq(5)
      expect(mapping[:club_city]).to eq(6)
      expect(mapping[:points]).to eq(7)
      expect(mapping[:result]).to eq(8)
    end

    it 'creates correct mapping for alternative header names' do
      mapping = scraper.send(:create_column_mapping, table_with_different_headers)
      
      expect(mapping[:round]).to eq(0)
      expect(mapping[:board]).to eq(1)
      expect(mapping[:starting_number]).to eq(2)
      expect(mapping[:name]).to eq(3)
      expect(mapping[:rating]).to eq(4)
      expect(mapping[:federation]).to eq(5)
      expect(mapping[:club_city]).to eq(6)
      expect(mapping[:points]).to eq(7)
      expect(mapping[:result]).to eq(8)
    end

    it 'handles missing headers gracefully' do
      table_with_missing_headers = Nokogiri::HTML(<<~HTML).css('table').first
        <table>
          <tr>
            <th>Name</th>
            <th>Points</th>
          </tr>
        </table>
      HTML
      
      mapping = scraper.send(:create_column_mapping, table_with_missing_headers)
      
      expect(mapping[:name]).to eq(0)
      expect(mapping[:points]).to eq(1)
      expect(mapping[:round]).to be_nil
      expect(mapping[:board]).to be_nil
    end
  end

  describe '#extract_cell_value' do
    let(:cells) do
      [
        double('cell', text: '1'),
        double('cell', text: '6'),
        double('cell', text: 'Bodaks, Leonards'),
        double('cell', text: '1496'),
        double('cell', text: 'LAT')
      ]
    end

    it 'extracts cell value at given index' do
      result = scraper.send(:extract_cell_value, cells, 2)
      expect(result).to eq('Bodaks, Leonards')
    end

    it 'returns nil for invalid index' do
      result = scraper.send(:extract_cell_value, cells, 10)
      expect(result).to be_nil
    end

    it 'returns nil for nil index' do
      result = scraper.send(:extract_cell_value, cells, nil)
      expect(result).to be_nil
    end
  end

  describe 'result prefix stripping' do
    it 'strips "- " prefix from results' do
      # Create a simple test that directly tests the parsing logic
      html_with_prefix_results = <<~HTML
        <html>
          <head><title>ChessMania Tournament</title></head>
          <body>
            <table>
              <tr>
                <th>Rd.</th>
                <th>Bo.</th>
                <th>SNo</th>
                <th>Name</th>
                <th>Rtg</th>
                <th>FED</th>
                <th>Club/City</th>
                <th>Pts.</th>
                <th>Res.</th>
              </tr>
              <tr>
                <td>1</td>
                <td>6</td>
                <td>6</td>
                <td>Bodaks, Leonards</td>
                <td>1496</td>
                <td>LAT</td>
                <td>Rīgas Šaha skola/ D.Matisone</td>
                <td>6</td>
                <td>- 0</td>
              </tr>
              <tr>
                <td>2</td>
                <td>6</td>
                <td>11</td>
                <td>Malcevs, Timofejs</td>
                <td>0</td>
                <td>LAT</td>
                <td>Mifan Chess/ A.Jazdanovs</td>
                <td>5</td>
                <td>- 1</td>
              </tr>
            </table>
          </body>
        </html>
      HTML

      # Parse the HTML directly without HTTP request
      doc = Nokogiri::HTML(html_with_prefix_results)
      table = scraper.send(:find_results_table, doc)
      players = scraper.send(:parse_table_rows, table)
      
      expect(players.size).to eq(2)
      expect(players.first.result).to eq('0')
      expect(players.last.result).to eq('1')
    end
  end

  describe 'dynamic column mapping integration' do
    let(:html_with_reordered_columns) do
      <<~HTML
        <html>
          <head><title>ChessMania Tournament</title></head>
          <body>
            <table>
              <tr>
                <th>Name</th>
                <th>Points</th>
                <th>Board</th>
                <th>Round</th>
                <th>Club/City</th>
                <th>Result</th>
              </tr>
              <tr>
                <td>Bodaks, Leonards</td>
                <td>6</td>
                <td>6</td>
                <td>1</td>
                <td>Rīgas Šaha skola/ D.Matisone</td>
                <td>- 0</td>
              </tr>
            </table>
          </body>
        </html>
      HTML
    end

    it 'correctly parses data with reordered columns' do
      stub_request(:get, "https://s3.chess-results.com/tnr1163083.aspx?art=9&fed=LAT&turdet=YES&snr=63&SNode=S0")
        .to_return(status: 200, body: html_with_reordered_columns, headers: { 'Content-Type' => 'text/html' })

      VCR.use_cassette('tournament_data_reordered') do
        result = scraper.fetch_tournament_data
        
        expect(result).to be_a(TournamentState)
        expect(result.players.size).to eq(9)
        expect(result.players.first.player_name).to eq('Bodaks, Leonards')
        expect(result.players.first.points).to eq(6.0)
        expect(result.players.first.board_number).to eq('6')
        expect(result.players.first.club_city).to eq('Rīgas Šaha skola/ D.Matisone')
        expect(result.players.first.result).to eq('0')
        expect(result.players.first.round_number).to eq(1)
      end
    end
  end
end