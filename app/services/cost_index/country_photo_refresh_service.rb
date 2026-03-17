# frozen_string_literal: true

module CostIndex
  class CountryPhotoRefreshService
    PHOTO_MAP = {
      "THA" => "https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTV8fCVFMyU4MiVCRiVFMyU4MiVBNHxlbnwwfHwwfHx8MA%3D%3D",
      "VNM" => "https://images.unsplash.com/photo-1580835267732-2d232d3d2655?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTJ8fCVFMyU4MyU5QiVFMyU4MyVCQyVFMyU4MyU4MSVFMyU4MyU5RiVFMyU4MyVCM3xlbnwwfHwwfHx8MA%3D%3D",
      "MYS" => "https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8JUUzJTgzJTlFJUUzJTgzJUFDJUUzJTgzJUJDJUUzJTgyJUI3JUUzJTgyJUEyfGVufDB8fDB8fHww",
      "KOR" => "https://images.unsplash.com/photo-1650229382504-b0eb3f9e8386?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTl8fCVFMyU4MiVCRCVFMyU4MiVBNiVFMyU4MyVBQiVFNSVCOCU4MiVFOCVBMSU5N3xlbnwwfHwwfHx8MA%3D%3D",
      "PAK" => "https://images.unsplash.com/flagged/photo-1558113118-e42e558b352a?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTJ8fCVFMyU4MyU5MSVFMyU4MiVBRCVFMyU4MiVCOSVFMyU4MiVCRiVFMyU4MyVCM3xlbnwwfHwwfHx8MA%3D%3D",
      "SGP" => "https://images.unsplash.com/photo-1600664356348-10686526af4f?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NHx8JUUzJTgyJUI3JUUzJTgzJUIzJUUzJTgyJUFDJUUzJTgzJTlEJUUzJTgzJUJDJUUzJTgzJUFCJUU1JUI4JTgyJUU4JUExJTk3fGVufDB8fDB8fHww",
      "POL" => "https://images.unsplash.com/photo-1607427293702-036933bbf746?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTJ8fCVFMyU4MyU5RCVFMyU4MyVCQyVFMyU4MyVBOSVFMyU4MyVCMyVFMyU4MyU4OXxlbnwwfHwwfHx8MA%3D%3D",
      "HUN" => "https://images.unsplash.com/photo-1616432902940-b7a1acbc60b3?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8JUUzJTgzJThGJUUzJTgzJUIzJUUzJTgyJUFDJUUzJTgzJUFBJUUzJTgzJUJDfGVufDB8fDB8fHww",
      "ESP" => "https://images.unsplash.com/photo-1543783207-ec64e4d95325?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8JUUzJTgyJUI5JUUzJTgzJTlBJUUzJTgyJUE0JUUzJTgzJUIzfGVufDB8fDB8fHww",
      "CZE" => "https://images.unsplash.com/photo-1600623471616-8c1966c91ff6?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NHx8JUUzJTgzJTk3JUUzJTgzJUE5JUUzJTgzJThGfGVufDB8fDB8fHww",
      "ITA" => "https://images.unsplash.com/photo-1520175480921-4edfa2983e0f?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8JUUzJTgyJUE0JUUzJTgyJUJGJUUzJTgzJUFBJUUzJTgyJUEyfGVufDB8fDB8fHww",
      "NGA" => "https://images.unsplash.com/photo-1618828665011-0abd973f7bb8?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8JUUzJTgzJUE5JUUzJTgyJUI0JUUzJTgyJUI5fGVufDB8fDB8fHww",
      "FRA" => "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8JUUzJTgzJTk1JUUzJTgzJUE5JUUzJTgzJUIzJUUzJTgyJUI5fGVufDB8fDB8fHww",
      "ARE" => "https://images.unsplash.com/photo-1721977568971-f07e1aa58cf9?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OHx8JUUzJTgyJUEyJUUzJTgzJUE5JUUzJTgzJTk2JUU5JUE2JTk2JUU5JTlFJUI3JUU1JTlCJUJEJUU5JTgwJUEzJUU5JTgyJUE2fGVufDB8fDB8fHww",
      "PRT" => "https://images.unsplash.com/photo-1555881400-74d7acaacd8b?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8JUUzJTgzJTlEJUUzJTgzJUFCJUUzJTgzJTg4JUUzJTgyJUFDJUUzJTgzJUFCfGVufDB8fDB8fHww",
      "DEU" => "https://images.unsplash.com/photo-1528728329032-2972f65dfb3f?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTB8fCVFMyU4MyU5OSVFMyU4MyVBQiVFMyU4MyVBQSVFMyU4MyVCM3xlbnwwfHwwfHx8MA%3D%3D",
      "MNG" => "https://images.unsplash.com/photo-1529002553897-6f5fdc76fa83?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTZ8fCVFMyU4MyVBMiVFMyU4MyVCMyVFMyU4MiVCNCVFMyU4MyVBQnxlbnwwfHwwfHx8MA%3D%3D",
      "ROU" => "https://images.unsplash.com/photo-1456348898220-eb3c574fd338?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTF8fCVFMyU4MyVBQiVFMyU4MyVCQyVFMyU4MyU5RSVFMyU4MyU4QiVFMyU4MiVBMnxlbnwwfHwwfHx8MA%3D%3D",
      "CAN" => "https://images.unsplash.com/photo-1519832979-6fa011b87667?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTR8fCVFMyU4MiVBQiVFMyU4MyU4QSVFMyU4MyU4MHxlbnwwfHwwfHx8MA%3D%3D",
      "GBR" => "https://images.unsplash.com/photo-1486299267070-83823f5448dd?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8JUUzJTgyJUE0JUUzJTgyJUFFJUUzJTgzJUFBJUUzJTgyJUI5fGVufDB8fDB8fHww",
      "AUS" => "https://images.unsplash.com/photo-1485081669829-bacb8c7bb1f3?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8JUUzJTgyJUFBJUUzJTgzJUJDJUUzJTgyJUI5JUUzJTgzJTg4JUUzJTgzJUFBJUUzJTgyJUEyfGVufDB8fDB8fHww",
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