class ContractsController < ApplicationController
  before_action :set_client
  before_action :set_contract, only: [ :show, :update ]

  def index
    authorize Contract, :index?, policy_class: ContractPolicy
    as_of = parse_as_of(params[:as_of])
    return if performed?

    contracts = policy_scope(Contract, policy_scope_class: ContractPolicy::Scope)
      .where(client_id: @client.id)
      .recent_first

    render json: {
      contracts: contracts.map { |contract| contract_response(contract) },
      meta: index_meta(contracts, as_of)
    }, status: :ok
  end

  def show
    authorize @contract, :show?, policy_class: ContractPolicy

    render json: { contract: contract_response(@contract) }, status: :ok
  end

  def create
    authorize Contract, :create?, policy_class: ContractPolicy
    contract = current_tenant.contracts.new(contract_params.merge(client: @client))

    ActiveRecord::Base.transaction do
      close_previous_active_contracts!(contract.start_on) if contract.start_on.present?
      contract.save!
    end

    render json: { contract: contract_response(contract) }, status: :created
  rescue ActiveRecord::RecordInvalid => exception
    render_validation_error(exception.record)
  rescue ActiveRecord::StatementInvalid => exception
    return render_period_overlap_error if overlap_constraint_violation?(exception)

    raise
  end

  def update
    authorize @contract, :update?, policy_class: ContractPolicy

    if @contract.update(contract_params)
      render json: { contract: contract_response(@contract) }, status: :ok
    else
      render_validation_error(@contract)
    end
  rescue ActiveRecord::StatementInvalid => exception
    return render_period_overlap_error if overlap_constraint_violation?(exception)

    raise
  end

  private

  def set_client
    @client = current_tenant.clients.find(params[:client_id])
  end

  def set_contract
    @contract = current_tenant.contracts.find_by!(id: params[:id], client_id: @client.id)
  end

  def contract_params
    params.permit(
      :start_on,
      :end_on,
      :service_note,
      :shuttle_required,
      :shuttle_note,
      weekdays: [],
      services: {}
    )
  end

  def close_previous_active_contracts!(new_start_on)
    previous_contracts = current_tenant.contracts
      .where(client_id: @client.id)
      .where("start_on < ? AND COALESCE(end_on, ?) >= ?", new_start_on, Contract::OPEN_ENDED_DATE, new_start_on)

    previous_contracts.find_each do |previous_contract|
      previous_contract.update!(end_on: new_start_on - 1.day)
    end
  end

  def parse_as_of(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    render_error("bad_request", "as_of must be ISO date (YYYY-MM-DD)", :bad_request)
    nil
  end

  def index_meta(contracts, as_of)
    meta = { total: contracts.size }
    return meta unless as_of

    current_contract = contracts.find do |contract|
      contract.start_on <= as_of && (contract.end_on.nil? || contract.end_on >= as_of)
    end

    meta.merge(
      as_of: as_of,
      current_contract_id: current_contract&.id
    )
  end

  def overlap_constraint_violation?(exception)
    cause = exception.cause
    return false if cause.blank?

    is_exclusion_violation = defined?(PG::ExclusionViolation) && cause.is_a?(PG::ExclusionViolation)
    is_exclusion_violation || cause.message.include?("contracts_no_overlapping_periods")
  end

  def render_period_overlap_error
    render_error("validation_error", "Contract period overlaps with existing contracts", :unprocessable_entity)
  end
end
