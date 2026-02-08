class ClientsController < ApplicationController
  def index
    authorize Client, :index?, policy_class: ClientPolicy
    clients = policy_scope(Client, policy_scope_class: ClientPolicy::Scope)
    clients = clients.order(updated_at: :desc)
    clients = apply_status_filter(clients)
    clients = apply_search_filter(clients)

    render json: {
      clients: clients.map { |client| client_response(client) },
      meta: { total: clients.size }
    }, status: :ok
  end

  def show
    client = current_tenant.clients.find(params[:id])
    authorize client, :show?, policy_class: ClientPolicy

    render json: { client: client_response(client) }, status: :ok
  end

  def create
    authorize Client, :create?, policy_class: ClientPolicy
    client = current_tenant.clients.new(client_params)

    if client.save
      render json: { client: client_response(client) }, status: :created
    else
      render_validation_error(client)
    end
  end

  def update
    client = current_tenant.clients.find(params[:id])
    authorize client, :update?, policy_class: ClientPolicy

    if client.update(client_params)
      render json: { client: client_response(client) }, status: :ok
    else
      render_validation_error(client)
    end
  end

  def destroy
    client = current_tenant.clients.find(params[:id])
    authorize client, :destroy?, policy_class: ClientPolicy
    client.destroy!

    head :no_content
  end

  private

  def client_params
    params.permit(
      :name,
      :kana,
      :birth_date,
      :gender,
      :phone,
      :address,
      :emergency_contact_name,
      :emergency_contact_phone,
      :notes,
      :status
    )
  end

  def apply_search_filter(relation)
    query = params[:q].to_s.strip
    return relation if query.blank?

    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    relation.where(
      "clients.name ILIKE :q OR clients.kana ILIKE :q OR clients.phone ILIKE :q",
      q: like_query
    )
  end

  def apply_status_filter(relation)
    status = params[:status].to_s
    return relation unless Client.statuses.key?(status)

    relation.where(status: Client.statuses.fetch(status))
  end
end
