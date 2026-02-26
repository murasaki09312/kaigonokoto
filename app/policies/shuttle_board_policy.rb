class ShuttleBoardPolicy < ApplicationPolicy
  def index?
    allowed?("shuttles:read")
  end

  def update_leg?
    allowed?("shuttles:operate") || allowed?("shuttles:manage")
  end

  def manage_schedule?
    allowed?("shuttles:manage")
  end
end
