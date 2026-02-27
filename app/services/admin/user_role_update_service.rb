module Admin
  class UserRoleUpdateService
    MANAGEABLE_ROLE_NAMES = %w[admin staff driver].freeze

    def initialize(tenant:, actor_user:, target_user:, role_names:)
      @tenant = tenant
      @actor_user = actor_user
      @target_user = target_user
      @role_names = role_names
    end

    def call
      normalized_role_names = normalize_role_names!
      ensure_role_catalog!(normalized_role_names)

      ActiveRecord::Base.transaction do
        @target_user.lock!
        ensure_target_in_tenant!
        prevent_self_lockout!(normalized_role_names)

        roles = fetch_roles!(normalized_role_names)
        @target_user.roles = roles
      end

      @target_user.reload
    end

    private

    def normalize_role_names!
      role_names = Array(@role_names)
        .map { |name| name.to_s.strip }
        .reject(&:blank?)
        .uniq

      raise_validation!("role_names must include at least one role") if role_names.empty?
      raise_validation!("role_names must include exactly one role") if role_names.size > 1

      disallowed = role_names - MANAGEABLE_ROLE_NAMES
      raise_validation!("role_names include unsupported role(s): #{disallowed.join(', ')}") if disallowed.any?

      role_names
    end

    def fetch_roles!(role_names)
      roles = Role.where(name: role_names).to_a
      missing_role_names = role_names - roles.map(&:name)
      raise_validation!("role not found: #{missing_role_names.join(', ')}") if missing_role_names.any?

      roles
    end

    def ensure_role_catalog!(role_names)
      return unless role_names.include?("driver")

      ::Admin::RoleCatalogService.ensure_driver_role!
    end

    def ensure_target_in_tenant!
      return if @target_user.tenant_id == @tenant.id

      raise ActiveRecord::RecordNotFound, "Not Found"
    end

    def prevent_self_lockout!(role_names)
      return unless @target_user.id == @actor_user.id
      return if role_names.include?("admin")

      raise_validation!("You cannot remove your own admin role")
    end

    def raise_validation!(message)
      @target_user.errors.add(:base, message)
      raise ActiveRecord::RecordInvalid, @target_user
    end
  end
end
