module Admin
  class CostIndexController < BaseController
    def refresh
      before_final = Country.where.not(final_index: nil).count
      before_calc  = Country.where.not(calculated_at: nil).count

      Rails.logger.info "[ADMIN COST] refresh start"
      Rails.logger.info "[ADMIN COST] before final_index=#{before_final} calculated_at=#{before_calc}"

      run_rake_task!("cost_index:refresh_all")

      after_final = Country.where.not(final_index: nil).count
      after_calc  = Country.where.not(calculated_at: nil).count

      Rails.logger.info "[ADMIN COST] after final_index=#{after_final} calculated_at=#{after_calc}"

      load_cost_index_debug_data

      if after_final > before_final || after_calc > before_calc
        flash.now[:notice] = "本番データ更新を実行しました"
      else
        flash.now[:alert] = "更新処理は走りましたが、件数は増えていません"
      end

      render :index
    rescue => e
      Rails.logger.error "[ADMIN COST] refresh error #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(20).join("\n")
      load_cost_index_debug_data rescue nil
      flash.now[:alert] = "更新中にエラーが発生しました: #{e.class} #{e.message}"
      render :index, status: :unprocessable_entity
    end
  end
end