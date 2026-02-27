class FacilitySettingPolicy < ApplicationPolicy
  def show?
    allowed?("tenants:manage")
  end

  def update?
    allowed?("tenants:manage")
  end
end
