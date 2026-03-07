# frozen_string_literal: true

require "faraday"
require "roo"
require "tempfile"

module Mofa
  class CountryMasterFetcher
    DEFAULT_URL = "https://www.ezairyu.mofa.go.jp/html/opendata/support/country.xlsx"

    def initialize(url: ENV.fetch("MOFA_COUNTRY_XLSX_URL", DEFAULT_URL))
      @url = url
    end

    def fetch_rows
      resp = Faraday.get(@url)
      raise "country.xlsx download failed status=#{resp.status}" unless resp.status.to_i == 200

      body = resp.body
      raise "country.xlsx empty body" if body.nil? || body.bytesize == 0

      head2 = body.byteslice(0, 2)
      raise "country.xlsx is not xlsx (head=#{head2.inspect})" unless head2 == "PK"

      file = Tempfile.new(["country", ".xlsx"])
      file.binmode
      file.write(body)
      file.flush

      book = Roo::Excelx.new(file.path)

      sheet, header = detect_sheet_and_header(book)
      raise "country.xlsx parse returned 0 rows (header not detected)" if sheet.nil? || header.nil?

      start_row = header[:start_row].to_i
      last_row = sheet.last_row.to_i

      # safety check: code_colが連番(No列)を掴んでいないか判定
      sample_codes = []
      start_row.upto([start_row + 30, last_row].min) do |r|
        v = sheet.row(r)[header[:code_col]]
        code = normalize_code(v)
        sample_codes << code unless code.empty?
      end

      # 0001〜みたいな連番が多数なら誤検出
      if sample_codes.size >= 10
        small = sample_codes.count { |c| c.to_i <= 250 } # 0208とかを拾うのを止める
        if small >= (sample_codes.size * 0.6)
          raise "country.xlsx code_col seems wrong (sequential numbers detected). sample=#{sample_codes.first(15).inspect}"
        end
      end

      rows = []
      start_row.upto(last_row) do |r|
        values = sheet.row(r)

        code = normalize_code(cell_value(values, header[:code_col]))
        next if code.empty?

        name_ja = cell_value(values, header[:name_ja_col]).to_s.strip
        next if name_ja.empty?

        name_en =
          if header[:name_en_col].nil?
            ""
          else
            cell_value(values, header[:name_en_col]).to_s.strip
          end

        rows << { mofa_country_code: code, name_ja: name_ja, name_en: name_en }
      end

      rows.uniq { |h| h[:mofa_country_code] }
    ensure
      if file
        file.close
        file.unlink
      end
    end

    def upsert_countries
      rows = fetch_rows
      raise "country.xlsx parse returned 0 rows" if rows.empty?

      rows.each do |h|
        c = Country.find_or_initialize_by(mofa_country_code: h[:mofa_country_code])
        c.name_ja = h[:name_ja]
        c.name_en = h[:name_en] if h[:name_en].present?
        c.last_error = nil if c.last_error.to_s.start_with?("country_master")
        c.save!(validate: false)
      rescue StandardError => e
        c.last_error = "country_master保存失敗: #{e.class} #{e.message}"
        c.save(validate: false) rescue nil
      end
    end

    private

    def detect_sheet_and_header(book)
      book.sheets.each do |sheet_name|
        s = book.sheet(sheet_name)
        header = detect_header_two_rows(s)
        header ||= guess_header_by_data(s)
        return [s, header] if header
      end

      s = book.sheet(0)
      header = detect_header_two_rows(s)
      header ||= guess_header_by_data(s)
      [s, header]
    rescue StandardError
      [nil, nil]
    end

    def detect_header_two_rows(sheet)
      last_row = sheet.last_row.to_i
      max_scan = [last_row, 80].min

      1.upto(max_scan) do |r|
        row1 = sheet.row(r)
        row2 = (r + 1 <= last_row) ? sheet.row(r + 1) : []
        merged = merge_headers(row1, row2)

        code_col = find_code_col(merged)
        next if code_col.nil?

        name_ja_col = find_name_ja_col(merged)
        next if name_ja_col.nil?

        start_row = r + 2
        next if start_row > last_row

        name_en_col = find_name_en_col(merged)
        if name_en_col.nil?
          name_en_col = infer_english_col(sheet, start_row, name_ja_col)
        end

        return {
          code_col: code_col,
          name_ja_col: name_ja_col,
          name_en_col: name_en_col,
          start_row: start_row
        }
      end

      nil
    end

    def merge_headers(row1, row2)
      max_len = [row1.length, row2.length].max
      out = []
      0.upto(max_len - 1) do |i|
        a = normalize_header(row1[i])
        b = normalize_header(row2[i])
        out << (a + b)
      end
      out
    end

    def find_code_col(norm_row)
      norm_row.each_with_index do |cell, i|
        next if cell.empty?

        # 「国コード」系の見出しだけを許可（No/連番を除外）
        # 例: "国または地域コード", "国コード", "countrycode"
        hit =
          cell.include?("コード") &&
          (cell.include?("国") || cell.include?("country")) &&
          !cell.include?("no") &&
          !cell.include?("番号") &&
          !cell.include?("連番")

        next unless hit

        return i
      end
      nil
    end

    def find_name_ja_col(norm_row)
      norm_row.each_with_index do |cell, i|
        next if cell.empty?
        return i if cell.include?("日本語")
        return i if cell.include?("和文")
        return i if (cell.include?("国") || cell.include?("地域")) && cell.include?("名") && cell.include?("日本")
      end

      norm_row.each_with_index do |cell, i|
        next if cell.empty?
        return i if (cell.include?("国") || cell.include?("地域")) && cell.include?("名")
      end

      nil
    end

    def find_name_en_col(norm_row)
      norm_row.each_with_index do |cell, i|
        next if cell.empty?
        return i if cell.include?("英語")
        return i if cell.include?("英文")
        return i if cell.include?("英名")
        return i if cell.include?("english")
      end
      nil
    end

    def infer_english_col(sheet, start_row, name_ja_col)
      last_row = sheet.last_row.to_i
      to_row = [start_row + 250, last_row].min

      max_cols = 0
      start_row.upto(to_row) do |r|
        len = sheet.row(r).length
        max_cols = len if len > max_cols
      end
      return nil if max_cols == 0

      best_i = nil
      best_n = 0

      (name_ja_col + 1).upto(max_cols - 1) do |i|
        n = 0
        start_row.upto(to_row) do |r|
          s = sheet.row(r)[i].to_s.strip
          next if s.empty?
          n += 1 if s.match?(/[A-Za-z]/)
        end
        if n > best_n
          best_n = n
          best_i = i
        end
      end

      return nil if best_n < 10
      best_i
    rescue StandardError
      nil
    end

    def guess_header_by_data(sheet)
      last_row = sheet.last_row.to_i
      max_row = [last_row, 250].min
      return nil if max_row <= 1

      max_cols = 0
      1.upto(max_row) do |r|
        len = sheet.row(r).length
        max_cols = len if len > max_cols
      end
      return nil if max_cols <= 0

      code_col = guess_code_col(sheet, max_row, max_cols)
      return nil if code_col.nil?

      name_ja_col = guess_name_ja_col(sheet, max_row, max_cols, code_col)
      return nil if name_ja_col.nil?

      name_en_col = guess_name_en_col(sheet, max_row, max_cols, name_ja_col)

      start_row = guess_start_row(sheet, max_row, code_col, name_ja_col)
      return nil if start_row.nil?

      { code_col: code_col, name_ja_col: name_ja_col, name_en_col: name_en_col, start_row: start_row }
    end

    def guess_code_col(sheet, max_row, max_cols)
      best_i = nil
      best_n = 0

      0.upto(max_cols - 1) do |i|
        n = 0
        1.upto(max_row) do |r|
          v = sheet.row(r)[i]
          code = normalize_code(v)
          n += 1 if code.length == 4
        end
        if n > best_n
          best_n = n
          best_i = i
        end
      end

      return nil if best_n < 10
      best_i
    end

    def guess_name_ja_col(sheet, max_row, max_cols, code_col)
      best_i = nil
      best_n = 0

      (code_col + 1).upto(max_cols - 1) do |i|
        n = 0
        1.upto(max_row) do |r|
          s = sheet.row(r)[i].to_s.strip
          next if s.empty?
          n += 1 if s.match?(/[一-龠ぁ-んァ-ヶ]/)
        end
        if n > best_n
          best_n = n
          best_i = i
        end
      end

      return nil if best_n < 10
      best_i
    end

    def guess_name_en_col(sheet, max_row, max_cols, name_ja_col)
      best_i = nil
      best_n = 0

      (name_ja_col + 1).upto(max_cols - 1) do |i|
        n = 0
        1.upto(max_row) do |r|
          s = sheet.row(r)[i].to_s.strip
          next if s.empty?
          n += 1 if s.match?(/[A-Za-z]/)
        end
        if n > best_n
          best_n = n
          best_i = i
        end
      end

      return nil if best_n < 10
      best_i
    end

    def guess_start_row(sheet, max_row, code_col, name_ja_col)
      1.upto(max_row) do |r|
        row = sheet.row(r)
        code = normalize_code(row[code_col])
        next if code.empty?
        ja = row[name_ja_col].to_s.strip
        next if ja.empty?
        return r
      end
      nil
    end

    def normalize_header(v)
      s = v.to_s
      s = s.tr("　", " ")
      s = s.gsub(/[[:space:]]+/, "")
      s = s.tr("（）", "()")
      s.downcase
    end

    def cell_value(values, col)
      return nil if col.nil?
      values[col]
    rescue StandardError
      nil
    end

    def normalize_code(v)
      return "" if v.nil?

      s = v.is_a?(Numeric) ? v.to_i.to_s : v.to_s
      s = s.tr("　", " ")
      s = s.gsub(/[[:space:]]+/, "")
      digits = s.scan(/\d+/).join
      return "" if digits.empty?

      format("%04d", digits.to_i)
    end
  end
end
