module Admin
  class CostIndexController < BaseController
    def index
    end

    def refresh
      CostIndex::RefreshAll.call
      redirect_to admin_cost_index_path, notice: "コスト指数を更新しました。"
    rescue => e
      redirect_to admin_cost_index_path, alert: "更新に失敗しました: #{e.message}"
    end
  end
end