class UsersPolicy < ApplicationPolicy
  def index?
    allowed?("users:read")
  end

  def show?
    allowed?("users:read") && same_tenant_record?
  end

  def create?
    allowed?("users:manage")
  end

  def update?
    allowed?("users:manage") && same_tenant_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("users:read")

      scope.where(tenant_id: user.tenant_id)
    end
  end

  private

  def same_tenant_record?
    return true unless record.is_a?(User)

    record.tenant_id == user.tenant_id
  end
end
