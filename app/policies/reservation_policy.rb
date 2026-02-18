class ReservationPolicy < ApplicationPolicy
  def index?
    allowed?("reservations:read")
  end

  def show?
    allowed?("reservations:read") && same_tenant_record?
  end

  def create?
    allowed?("reservations:manage")
  end

  def update?
    allowed?("reservations:manage") && same_tenant_record?
  end

  def destroy?
    allowed?("reservations:manage") && same_tenant_record?
  end

  def generate?
    allowed?("reservations:manage")
  end

  def override_capacity?
    allowed?("reservations:override_capacity") || allowed?("tenants:manage")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("reservations:read")

      scope.where(tenant_id: user.tenant_id)
    end
  end

  private

  def same_tenant_record?
    return true unless record.is_a?(Reservation)

    record.tenant_id == user.tenant_id
  end
end
