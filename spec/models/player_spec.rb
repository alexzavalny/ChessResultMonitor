require 'spec_helper'
require_relative '../../lib/models/player'

RSpec.describe Player do
  let(:player) do
    Player.new(
      board_number: "1",
      player_name: "John Doe",
      club_city: "Chess Club",
      points: 3.5,
      result: "1-0",
      opponent: "Jane Smith"
    )
  end

  describe '#initialize' do
    it 'creates a player with all attributes' do
      expect(player.board_number).to eq("1")
      expect(player.player_name).to eq("John Doe")
      expect(player.club_city).to eq("Chess Club")
      expect(player.points).to eq(3.5)
      expect(player.result).to eq("1-0")
      expect(player.opponent).to eq("Jane Smith")
    end
  end

  describe '#to_hash' do
    it 'converts player to hash' do
      hash = player.to_hash
      expect(hash[:board_number]).to eq("1")
      expect(hash[:player_name]).to eq("John Doe")
      expect(hash[:club_city]).to eq("Chess Club")
      expect(hash[:points]).to eq(3.5)
      expect(hash[:result]).to eq("1-0")
      expect(hash[:opponent]).to eq("Jane Smith")
    end
  end

  describe '#to_s' do
    it 'returns formatted string representation' do
      expect(player.to_s).to eq("1. John Doe (Chess Club) - 3.5 pts")
    end
  end

  describe '#==' do
    let(:same_player) do
      Player.new(
        board_number: "1",
        player_name: "John Doe",
        club_city: "Chess Club",
        points: 3.5,
        result: "1-0",
        opponent: "Jane Smith"
      )
    end

    let(:different_player) do
      Player.new(
        board_number: "2",
        player_name: "Jane Smith",
        club_city: "Other Club",
        points: 2.0,
        result: "0-1",
        opponent: "John Doe"
      )
    end

    it 'returns true for identical players' do
      expect(player).to eq(same_player)
    end

    it 'returns false for different players' do
      expect(player).not_to eq(different_player)
    end
  end

  describe '#hash' do
    it 'generates consistent hash for identical players' do
      player1 = Player.new(board_number: "1", player_name: "John", club_city: "Club", points: 3.0, result: "1-0", opponent: "Jane")
      player2 = Player.new(board_number: "1", player_name: "John", club_city: "Club", points: 3.0, result: "1-0", opponent: "Jane")
      
      expect(player1.hash).to eq(player2.hash)
    end
  end
end
