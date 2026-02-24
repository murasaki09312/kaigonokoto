class InvoicePolicy < ApplicationPolicy
  def index?
    allowed?("invoices:read")
  end

  def show?
    allowed?("invoices:read") && same_tenant_record?
  end

  def generate?
    allowed?("invoices:manage")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("invoices:read")

      scope.where(tenant_id: user.tenant_id)
    end
  end

  private

  def same_tenant_record?
    return true unless record.is_a?(Invoice)

    record.tenant_id == user.tenant_id
  end
end
