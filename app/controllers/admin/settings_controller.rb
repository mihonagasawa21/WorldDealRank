module Admin
  class SettingsController < BaseController
    def edit
      @setting = EvaluationSetting.current
    end

    def update
      @setting = EvaluationSetting.current
      if @setting.update(setting_params)
        redirect_to edit_admin_setting_path, notice: "保存しました"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def setting_params
      params.require(:evaluation_setting).permit(
        :top_n,
        :include_level2,
        :weight_cost,
        :bonus_level1,
        :penalty_level2,
        :stale_fx_days,
        :stale_fx_penalty,
        :stale_calc_hours,
        :stale_calc_penalty,
        :grade_a_min,
        :grade_b_min
      )
    end
  end
end
