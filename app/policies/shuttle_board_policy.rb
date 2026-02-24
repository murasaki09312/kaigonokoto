class ShuttleBoardPolicy < ApplicationPolicy
  def index?
    allowed?("shuttles:read")
  end
end
