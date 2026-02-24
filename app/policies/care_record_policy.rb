class CareRecordPolicy < ApplicationPolicy
  def upsert?
    allowed?("care_records:manage") && same_tenant_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("today_board:read")

      scope.where(tenant_id: user.tenant_id)
    end
  end

  private

  def same_tenant_record?
    tenant_id = case record
    when CareRecord
      record.tenant_id
    when Reservation
      record.tenant_id
    else
      nil
    end

    tenant_id == user.tenant_id
  end
end
