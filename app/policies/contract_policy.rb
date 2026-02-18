class ContractPolicy < ApplicationPolicy
  def index?
    allowed?("contracts:read")
  end

  def show?
    allowed?("contracts:read") && same_tenant_record?
  end

  def create?
    allowed?("contracts:manage")
  end

  def update?
    allowed?("contracts:manage") && same_tenant_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("contracts:read")

      scope.where(tenant_id: user.tenant_id)
    end
  end

  private

  def same_tenant_record?
    return true unless record.is_a?(Contract)

    record.tenant_id == user.tenant_id
  end
end
