module Admin
  class UserRolePolicy < ApplicationPolicy
    def index?
      allowed?("users:manage")
    end

    def update_roles?
      allowed?("users:manage") && same_tenant_record?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless user&.allowed?("users:manage")

        scope.where(tenant_id: user.tenant_id)
      end
    end

    private

    def same_tenant_record?
      return true unless record.is_a?(User)

      record.tenant_id == user.tenant_id
    end
  end
end
