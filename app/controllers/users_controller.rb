class UsersController < ApplicationController
  def index
    authorize User, :index?, policy_class: UsersPolicy
    users = policy_scope(User, policy_scope_class: UsersPolicy::Scope)
      .includes(:roles)
      .order(:id)

    render json: { users: users.map { |user| user_with_roles_response(user) } }, status: :ok
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

  def user_with_roles_response(user)
    roles = user.roles.sort_by(&:name)

    user_response(user).merge(
      role_names: roles.map(&:name),
      roles: roles.map do |role|
        {
          id: role.id,
          name: role.name,
          label: role_label(role.name)
        }
      end
    )
  end

  def role_label(role_name)
    case role_name
    when "admin" then "管理者"
    when "staff" then "一般スタッフ"
    when "driver" then "送迎ドライバー"
    else role_name
    end
  end
end
