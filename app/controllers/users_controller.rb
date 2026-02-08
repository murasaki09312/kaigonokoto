class UsersController < ApplicationController
  def index
    authorize User, :index?, policy_class: UsersPolicy
    users = policy_scope(User, policy_scope_class: UsersPolicy::Scope)

    render json: { users: users.map { |user| user_response(user) } }, status: :ok
  end

  def create
    authorize User, :create?, policy_class: UsersPolicy
    user = current_tenant.users.new(user_params)

    if user.save
      render json: { user: user_response(user) }, status: :created
    else
      render_validation_error(user)
    end
  end

  def show
    user = current_tenant.users.find(params[:id])
    authorize user, :show?, policy_class: UsersPolicy

    render json: { user: user_response(user) }, status: :ok
  end

  def update
    user = current_tenant.users.find(params[:id])
    authorize user, :update?, policy_class: UsersPolicy

    if user.update(update_user_params)
      render json: { user: user_response(user) }, status: :ok
    else
      render_validation_error(user)
    end
  end

  private

  def user_params
    params.permit(:name, :email, :password)
  end

  def update_user_params
    attrs = user_params
    attrs.delete(:password) if attrs[:password].blank?
    attrs
  end
end
