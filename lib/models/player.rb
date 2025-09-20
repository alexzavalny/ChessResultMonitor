# Player data model for chess tournament
class Player
  attr_accessor :board_number, :player_name, :club_city, :points, :result, :opponent, :fide_id, :rating

  def initialize(board_number: nil, player_name: nil, club_city: nil, points: nil, result: nil, opponent: nil, fide_id: nil, rating: nil)
    @board_number = board_number
    @player_name = player_name
    @club_city = club_city
    @points = points
    @result = result
    @opponent = opponent
    @fide_id = fide_id
    @rating = rating
  end

  def to_hash
    {
      board_number: @board_number,
      player_name: @player_name,
      club_city: @club_city,
      points: @points,
      result: @result,
      opponent: @opponent,
      fide_id: @fide_id,
      rating: @rating
    }
  end

  def to_s
    "#{@board_number}. #{@player_name} (#{@club_city}) - #{@points} pts"
  end

  def ==(other)
    return false unless other.is_a?(Player)
    
    @board_number == other.board_number &&
    @player_name == other.player_name &&
    @club_city == other.club_city &&
    @points == other.points &&
    @result == other.result &&
    @opponent == other.opponent
  end

  def hash
    [@board_number, @player_name, @club_city, @points, @result, @opponent].hash
  end

  def eql?(other)
    self == other
  end
end
