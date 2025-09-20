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
                <th>Rd.Bo</th>
                <th>SNo</th>
                <th>Name</th>
                <th>Club/City</th>
                <th>Pts</th>
                <th>Res.</th>
              </tr>
              <tr>
                <td>1</td>
                <td>1</td>
                <td>John Doe</td>
                <td>Chess Club</td>
                <td>3,5</td>
                <td>1-0</td>
              </tr>
              <tr>
                <td>2</td>
                <td>2</td>
                <td>Jane Smith</td>
                <td>Other Club</td>
                <td>2,0</td>
                <td>0-1</td>
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
        expect(result.tournament_name).to include('ChessMania')
        expect(result.players.size).to eq(2)
        expect(result.players.first.player_name).to eq('John Doe')
        expect(result.players.first.points).to eq(3.5)
      end
    end
  end
end
