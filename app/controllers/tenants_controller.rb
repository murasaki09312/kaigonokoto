class TenantsController < ApplicationController
  def index
    authorize :tenants, :index?, policy_class: TenantsPolicy
    tenants = policy_scope(Tenant, policy_scope_class: TenantsPolicy::Scope)

    render json: { tenants: tenants.map { |tenant| tenant_response(tenant) } }, status: :ok
  end

  def create
    authorize :tenants, :create?, policy_class: TenantsPolicy
    tenant = Tenant.new(tenant_params)

    if tenant.save
      render json: { tenant: tenant_response(tenant) }, status: :created
    else
      render_validation_error(tenant)
    end
  end

  private

  def tenant_params
    params.permit(:name, :slug)
  end
end
