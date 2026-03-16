module Admin
  class CountriesController < BaseController
    def index
      @countries = Country.order(:mofa_country_code)
    end

    def edit
      @country = Country.find(params[:id])
    end

    def update
      @country = Country.find(params[:id])
      if @country.update(country_params)
        redirect_to admin_countries_path, notice: "保存しました"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def country_params
      params.require(:country).permit(
        :iso2,
        :iso3,
        :currency_code,
        :name_en,
        :photo_url
      )
    end
  end
end
