module Api
  module V1
    module Dashboard
      class HandoffsController < ApplicationController
        def index
          authorize :dashboard_handoff, :index?, policy_class: DashboardHandoffPolicy

          result = ::Dashboard::HandoffFeedQuery.new(tenant: current_tenant).call

          render json: {
            handoffs: result.handoffs,
            meta: result.meta
          }, status: :ok
        end
      end
    end
  end
end
