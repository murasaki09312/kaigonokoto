module Api
  module V1
    module Admin
      class UsersController < ApplicationController
        def index
          authorize User, :index?, policy_class: ::Admin::UserRolePolicy
          ::Admin::RoleCatalogService.ensure_driver_role!

          users = policy_scope(User, policy_scope_class: ::Admin::UserRolePolicy::Scope)
            .includes(:roles)
            .order(:id)

          render json: {
            users: users.map { |user| admin_user_response(user) },
            role_options: role_options_response,
            meta: {
              current_user_id: current_user.id,
              can_manage_roles: true
            }
          }, status: :ok
        end

        def update_roles
          user = current_tenant.users.includes(:roles).find(params[:id])
          authorize user, :update_roles?, policy_class: ::Admin::UserRolePolicy
          ::Admin::RoleCatalogService.ensure_driver_role!

          updated_user = ::Admin::UserRoleUpdateService.new(
            tenant: current_tenant,
            actor_user: current_user,
            target_user: user,
            role_names: update_roles_params.fetch(:role_names)
          ).call

          render json: { user: admin_user_response(updated_user) }, status: :ok
        rescue ActiveRecord::RecordInvalid => exception
          render_validation_error(exception.record)
        end

        private

        def update_roles_params
          params.permit(role_names: [])
        end

        def admin_user_response(user)
          role_names = user.roles.map(&:name).sort

          user_response(user).merge(
            roles: user.roles.sort_by(&:name).map { |role| role_response(role) },
            role_names: role_names,
            is_self: user.id == current_user.id
          )
        end

        def role_options_response
          Role.where(name: ::Admin::UserRoleUpdateService::MANAGEABLE_ROLE_NAMES)
            .order(:name)
            .map { |role| role_response(role) }
        end

        def role_response(role)
          {
            id: role.id,
            name: role.name,
            label: role_label(role.name)
          }
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
    end
  end
end
