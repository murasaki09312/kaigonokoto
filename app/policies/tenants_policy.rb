class TenantsPolicy < ApplicationPolicy
  def index?
    allowed?("tenants:manage")
  end

  def create?
    allowed?("tenants:manage")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("tenants:manage")

      scope.all
    end
  end
end
