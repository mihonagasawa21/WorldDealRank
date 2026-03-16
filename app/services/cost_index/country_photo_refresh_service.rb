# frozen_string_literal: true

module CostIndex
  class CountryPhotoRefreshService
    PHOTO_MAP = {
      "MYS" => "https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=1200&q=80",
      "THA" => "https://images.unsplash.com/photo-1508009603885-50cf7c579365?auto=format&fit=crop&w=1200&q=80",
      "CHN" => "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?auto=format&fit=crop&w=1200&q=80",
      "BRA" => "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=1200&q=80",
      "BGD" => "https://images.unsplash.com/photo-1598514983318-2f64f8f4796c?auto=format&fit=crop&w=1200&q=80",
      "PRY" => "https://images.unsplash.com/photo-1613427954370-4b3f092ff0bb?auto=format&fit=crop&w=1200&q=80",
      "IND" => "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80",
      "SGP" => "https://images.unsplash.com/photo-1508962914676-134849a727f0?auto=format&fit=crop&w=1200&q=80",
      "IDN" => "https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1200&q=80",
      "PHL" => "https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?auto=format&fit=crop&w=1200&q=80",
      "TWN" => "https://images.unsplash.com/photo-1513407030348-c983a97b98d8?auto=format&fit=crop&w=1200&q=80",
      "USA" => "https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1200&q=80",
      "FRA" => "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1200&q=80",
      "ITA" => "https://images.unsplash.com/photo-1529260830199-42c24126f198?auto=format&fit=crop&w=1200&q=80",
      "ESP" => "https://images.unsplash.com/photo-1509840841025-9088ba78a826?auto=format&fit=crop&w=1200&q=80",
      "GBR" => "https://images.unsplash.com/photo-1505761671935-60b3a7427bad?auto=format&fit=crop&w=1200&q=80",
      "AUS" => "https://images.unsplash.com/photo-1506973035872-a4f23ef5f545?auto=format&fit=crop&w=1200&q=80",
      "CAN" => "https://images.unsplash.com/photo-1503614472-8c93d56e92ce?auto=format&fit=crop&w=1200&q=80",
      "DEU" => "https://images.unsplash.com/photo-1467269204594-9661b134dd2b?auto=format&fit=crop&w=1200&q=80",
      "CHE" => "https://images.unsplash.com/photo-1527668752968-14dc70a27c95?auto=format&fit=crop&w=1200&q=80",
      "TUR" => "https://images.unsplash.com/photo-1527838832700-5059252407fa?auto=format&fit=crop&w=1200&q=80",
      "HKG" => "https://images.unsplash.com/photo-1506973035872-a4f23ef5f545?auto=format&fit=crop&w=1200&q=80",
    }.freeze

    def self.call
      updated = 0

      PHOTO_MAP.each do |iso3, url|
        country = Country.find_by(iso3: iso3)
        next unless country

        country.update_columns(photo_url: url)
        updated += 1
      end

      updated
    end
  end
end