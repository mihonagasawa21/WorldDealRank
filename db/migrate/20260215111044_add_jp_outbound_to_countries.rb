# frozen_string_literal: true

class AddJpOutboundColumnsToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :jp_outbound_count, :integer unless column_exists?(:countries, :jp_outbound_count)
    add_column :countries, :jp_outbound_year,  :integer unless column_exists?(:countries, :jp_outbound_year)
    add_column :countries, :jp_outbound_month, :integer unless column_exists?(:countries, :jp_outbound_month)
  end
end
