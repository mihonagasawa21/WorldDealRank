# frozen_string_literal: true

require "faraday"
require "roo"
require "tempfile"

module Popularity
  class MofaResidentFetcher
    DEFAULT_PATH = Rails.root.join("data", "resident.xlsx").to_s

    def self.refresh_all
      new.refresh_all
    end

    def refresh_all
      data = fetch
      rows = data[:rows]

      raise "resident xlsx parsed 0 rows source=#{data[:source_url]}" if rows.empty?

      name_index = build_name_index

      matched = 0
      updated = 0
      unmatched = []

      rows.each do |r|
        name = r[:name].to_s
        cnt  = r[:count].to_i
        next if name.strip.empty?
        next if cnt <= 0

        targets = find_targets(name_index, name)
        if targets.empty?
          unmatched << name
          next
        end

        matched += 1
        targets.each do |c|
          c.jp_resident_count = cnt

          c.jp_resident_year  = data[:year]  if data[:year]
          c.jp_resident_month = data[:month] if data[:month]
          c.jp_resident_day   = data[:day]   if data[:day]

          if c.respond_to?(:jp_resident_source_url=) && data[:source_url].present?
            c.jp_resident_source_url = data[:source_url]
          end

          c.save!(validate: false)
          updated += 1
        rescue StandardError
          next
        end
      end

      {
        source_url: data[:source_url],
        total_rows: rows.size,
        matched: matched,
        updated: updated,
        unmatched_names: unmatched.uniq.sort
      }
    end
    
    def self.fetch(...)
      new.fetch(...)
    end

    def fetch
      path = ENV["MOFA_RESIDENT_XLSX_PATH"].to_s.strip
      url  = ENV["MOFA_RESIDENT_XLSX_URL"].to_s.strip

      if path.empty? && File.exist?(DEFAULT_PATH)
        path = DEFAULT_PATH
      end

      if path.present?
        raise "resident xlsx file not found path=#{path}" unless File.exist?(path)
        book = Roo::Excelx.new(path)
        meta = extract_meta(book)
        rows = extract_rows(book)
        return meta.merge(rows: rows, source_url: path)
      end

      if url.present?
        book = download_book(url)
        meta = extract_meta(book)
        rows = extract_rows(book)
        return meta.merge(rows: rows, source_url: url)
      end

      raise "resident import needs MOFA_RESIDENT_XLSX_PATH or MOFA_RESIDENT_XLSX_URL (and data/resident.xlsx not found)"
    end

    private

    def download_book(url)
      resp = Faraday.get(url) do |req|
        req.headers["User-Agent"] = "Mozilla/5.0"
        req.headers["Accept"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      end

      raise "resident xlsx download failed status=#{resp.status}" unless resp.status.to_i == 200
      body = resp.body
      raise "resident xlsx empty body" if body.nil? || body.bytesize == 0
      raise "resident xlsx not xlsx" unless body.byteslice(0, 2) == "PK"

      file = Tempfile.new(["resident", ".xlsx"])
      file.binmode
      file.write(body)
      file.flush

      Roo::Excelx.new(file.path)
    ensure
      if file
        file.close
        file.unlink
      end
    end

    def extract_meta(book)
      sheet =
        if book.sheets.include?("表紙")
          book.sheet("表紙")
        else
          book.sheet(book.sheets.first)
        end

      text = []
      max_r = [sheet.last_row.to_i, 60].min
      1.upto(max_r) do |r|
        row = sheet.row(r)
        row.each { |v| text << v.to_s if v.present? }
      end

      joined = text.join(" ")
      joined = joined.tr("０１２３４５６７８９", "0123456789")
      m = joined.match(/(\d{4})年[^\d]{0,20}(\d{1,2})月[^\d]{0,20}(\d{1,2})日\s*現在/)
      return { year: nil, month: nil, day: nil } unless m

      { year: m[1].to_i, month: m[2].to_i, day: m[3].to_i }
    rescue StandardError
      { year: nil, month: nil, day: nil }
    end

    def extract_rows(book)
      if book.sheets.include?("一覧表")
        rows = extract_from_sheet(book.sheet("一覧表"))
        return rows unless rows.empty?
      end

      out = []
      book.sheets.each do |name|
        out.concat(extract_from_sheet(book.sheet(name)))
      end
      out
    end

    def extract_from_sheet(sheet)
      header = detect_header(sheet)
      return [] if header.nil?

      name_col  = header[:name_col]
      total_col = header[:total_col]
      lt_col    = header[:lt_col]
      pr_col    = header[:pr_col]
      start_row = header[:start_row]

      out = []
      last = sheet.last_row.to_i

      start_row.upto(last) do |r|
        row = sheet.row(r)
        name = row[name_col].to_s.strip
        break if name.empty?

        next if skip_row_name?(name)

        total = total_col ? cell_int(row[total_col]) : nil
        if total.nil?
          lt = lt_col ? cell_int(row[lt_col]) : nil
          pr = pr_col ? cell_int(row[pr_col]) : nil
          total = (lt.to_i + pr.to_i) if lt || pr
        end
        next if total.nil? || total <= 0

        out << { name: name, count: total }
      end

      out
    rescue StandardError
      []
    end

    def detect_header(sheet)
      max_scan = [sheet.last_row.to_i, 120].min

      1.upto(max_scan - 1) do |r|
        row1 = sheet.row(r)
        row2 = sheet.row(r + 1)

        n1 = row1.map { |v| normalize_header(v) }
        n2 = row2.map { |v| normalize_header(v) }

        name_col =
          n1.index { |c| c.include?("国") && c.include?("地域") } ||
          n1.index { |c| c.include?("国(地域)") } ||
          n1.index { |c| c == "国" } ||
          n1.index { |c| c.include?("地域") }

        next if name_col.nil?

        total_col = nil
        (0...[n1.size, n2.size].min).each do |i|
          next if n1[i].include?("成人") || n2[i].include?("成人")
          if n1[i].include?("全体集計") && n2[i].include?("合計")
            total_col = i
            break
          end
        end

        (0...[n1.size, n2.size].min).each do |i|
          next if n1[i].include?("成人") || n2[i].include?("成人")
          if total_col.nil? && (n2[i].include?("合計") && (n1[i].include?("総数") || n1[i].include?("全体") || n1[i].include?("全体集計")))
            total_col = i
          end
        end

        lt_col = nil
        pr_col = nil
        (0...[n1.size, n2.size].min).each do |i|
          next if n1[i].include?("成人") || n2[i].include?("成人")
          if lt_col.nil? && (n1[i].include?("長期") && n2[i].include?("合計"))
            lt_col = i
          end
          if pr_col.nil? && (n1[i].include?("永住") && n2[i].include?("合計"))
            pr_col = i
          end
        end

        if total_col.nil? && lt_col.nil? && pr_col.nil?
          next
        end

        return { name_col: name_col, total_col: total_col, lt_col: lt_col, pr_col: pr_col, start_row: r + 2 }
      end

      nil
    end

    def skip_row_name?(name)
      n = name.to_s.strip
      return true if n.empty?
      return true if n == "計" || n == "合計" || n == "総計" || n == "世界" || n == "総数"
      return true if n.include?("参考")
      return true if n.match?(/\A[ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ]/)
      false
    end

    def normalize_header(v)
      s = v.to_s
      s = s.tr("　", " ")
      s = s.gsub(/[[:space:]]+/, "")
      s = s.tr("（）", "()")
      s.downcase
    end

    def build_name_index
      h = Hash.new { |hh, k| hh[k] = [] }
      Country.find_each do |c|
        h[norm(c.name_ja)] << c if c.name_ja.present?
        h[norm(c.name_en)] << c if c.name_en.present?
        h[norm(c.iso3)]    << c if c.iso3.present?
      end
      h
    end

    def find_targets(index, name)
      key = norm(name)
      return [] if key.empty?
      return index[key] if index.key?(key) && index[key].any?

      hits = []
      index.each do |k, arr|
        next if k.empty?
        if k.include?(key) || key.include?(k)
          hits.concat(arr)
        end
      end
      hits.uniq
    end

    def norm(s)
      s.to_s.strip
       .tr("　", " ")
       .gsub(/\s+/, "")
       .tr("（）", "()")
       .gsub(/（.*?）/, "")
       .gsub(/\(.*?\)/, "")
    end

    def cell_int(v)
      return nil if v.nil?

      if v.is_a?(Numeric)
        i = v.to_i
        return nil if i <= 0
        return i
      end

      s = v.to_s.strip
      return nil if s.empty?
      return nil if s.include?("非公表") || s == "-" || s == "－"

      s = s.gsub(",", "")
      return nil unless s.match?(/\A\d+\z/)

      i = s.to_i
      return nil if i <= 0
      i
    end
  end
end
