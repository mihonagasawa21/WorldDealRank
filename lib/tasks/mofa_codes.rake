namespace :mofa do
  desc "Overwrite countries.mofa_country_code by name_ja (with exceptions)"
  task import_country_codes_by_name_ja: :environment do
    norm = ->(s) do
      s.to_s
       .tr("　", " ")
       .gsub(/\s+/, " ")
       .strip
    end

    namespace :mofa do
    desc "Hard set MOFA code for USA only (JPN is ignored)"
    task hard_set_usa_code: :environment do
        usa_code = "0047" # アメリカ合衆国／米国（本土）

        updated = 0
        Country.where(iso3: "USA").find_each do |c|
        next if c.mofa_country_code == usa_code
        c.update!(mofa_country_code: usa_code)
        updated += 1
        end

        puts "done. updated=#{updated} USA=#{usa_code}"
    end
    end

    # 例外対応（ここに追加していく）
    EXCEPTIONS = {
      "アメリカ合衆国／米国" => "アメリカ合衆国",
      "日本" => "日本国"
    }

    mofa_rows = Mofa::CountryMasterFetcher.new.fetch_rows

    name_to_code = {}
    mofa_rows.each do |r|
      name = norm.call(r[:name_ja])
      code = r[:mofa_country_code].to_s.gsub(/\D/, "").rjust(4, "0")
      next if name.empty? || code.empty?
      name_to_code[name] = code
    end

    updated = 0
    missing = []

   Country.find_each do |c|
    raw_name = norm.call(c.name_ja)

    lookup_name =
    if raw_name.start_with?("アメリカ合衆国／米国")
        "アメリカ合衆国"
    elsif raw_name == "日本"
        "日本国"
    else
        raw_name
    end
    
    lookup_name =
    if c.iso3 == "USA"
        "アメリカ合衆国"
    elsif c.iso3 == "JPN"
        "日本国"
    else
        norm.call(c.name_ja)
    end

      code = name_to_code[lookup_name]

       if code.nil?
            missing << [c.iso3, c.name_ja]
            next
        end

        next if c.mofa_country_code == code
        c.update!(mofa_country_code: code)
        updated += 1
        end

    puts "done. updated=#{updated} missing=#{missing.size}"
    missing.first(50).each { |iso3, name_ja| puts "#{iso3}\t#{name_ja}" }
  end
end