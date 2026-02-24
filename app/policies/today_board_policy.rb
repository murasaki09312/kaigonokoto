class TodayBoardPolicy < ApplicationPolicy
  def index?
    allowed?("today_board:read")
  end
end
