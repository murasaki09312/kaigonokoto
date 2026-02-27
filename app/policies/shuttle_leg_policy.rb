class ShuttleLegPolicy < ApplicationPolicy
  def upsert?
    (allowed?("shuttles:operate") || allowed?("shuttles:manage")) && same_tenant_record?
  end

  private

  def same_tenant_record?
    tenant_id = case record
    when ShuttleLeg
      record.tenant_id
    when Reservation
      record.tenant_id
    else
      nil
    end

    tenant_id == user.tenant_id
  end
end
