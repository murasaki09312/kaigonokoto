module Admin
  class RoleCatalogService
    DRIVER_ROLE_NAME = "driver".freeze
    DRIVER_PERMISSION_KEYS = %w[shuttles:read shuttles:operate].freeze

    def self.ensure_driver_role!
      new.ensure_driver_role!
    end

    def ensure_driver_role!
      ActiveRecord::Base.transaction do
        permissions = DRIVER_PERMISSION_KEYS.map { |key| Permission.find_or_create_by!(key: key) }
        driver_role = Role.find_or_create_by!(name: DRIVER_ROLE_NAME)

        missing_permissions = permissions.reject { |permission| driver_role.permission_ids.include?(permission.id) }
        driver_role.permissions << missing_permissions if missing_permissions.any?

        driver_role
      end
    end
  end
end
