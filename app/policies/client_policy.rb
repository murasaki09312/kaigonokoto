class ClientPolicy < ApplicationPolicy
  def index?
    allowed?("clients:read")
  end

  def show?
    allowed?("clients:read") && same_tenant_record?
  end

  def create?
    allowed?("clients:manage")
  end

  def update?
    allowed?("clients:manage") && same_tenant_record?
  end

  def destroy?
    allowed?("clients:manage") && same_tenant_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("clients:read")

      scope.where(tenant_id: user.tenant_id)
    end
  end

  private

  def same_tenant_record?
    return true unless record.is_a?(Client)

    record.tenant_id == user.tenant_id
  end
end
