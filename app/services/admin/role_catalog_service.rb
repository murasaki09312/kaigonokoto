module Admin
  class RoleCatalogService
    DRIVER_ROLE_NAME = "driver".freeze
    DRIVER_PERMISSION_KEYS = %w[shuttles:read shuttles:operate].freeze
    MAX_RETRY_COUNT = 1

    def self.ensure_driver_role!
      new.ensure_driver_role!
    end

    def ensure_driver_role!
      with_record_not_unique_retry do
        ActiveRecord::Base.transaction do
          permissions = DRIVER_PERMISSION_KEYS.map { |key| Permission.find_or_create_by!(key: key) }
          driver_role = Role.find_or_create_by!(name: DRIVER_ROLE_NAME)

          permissions.each do |permission|
            RolePermission.find_or_create_by!(role_id: driver_role.id, permission_id: permission.id)
          end

          driver_role.reload
        end
      end
    end

    private

    def with_record_not_unique_retry
      retries = 0

      begin
        yield
      rescue ActiveRecord::RecordNotUnique
        raise if (retries += 1) > MAX_RETRY_COUNT

        retry
      end
    end
  end
end
