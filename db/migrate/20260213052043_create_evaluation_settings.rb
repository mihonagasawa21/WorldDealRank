class CreateEvaluationSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :evaluation_settings do |t|
      t.integer :top_n, null: false, default: 5
      t.boolean :include_level2, null: false, default: false

      t.decimal :weight_cost, precision: 10, scale: 4, null: false, default: 1.0
      t.decimal :bonus_level1, precision: 10, scale: 4, null: false, default: 10.0
      t.decimal :penalty_level2, precision: 10, scale: 4, null: false, default: 20.0

      t.integer :stale_fx_days, null: false, default: 7
      t.decimal :stale_fx_penalty, precision: 10, scale: 4, null: false, default: 10.0

      t.integer :stale_calc_hours, null: false, default: 24
      t.decimal :stale_calc_penalty, precision: 10, scale: 4, null: false, default: 10.0

      t.decimal :grade_a_min, precision: 10, scale: 4, null: false, default: 60.0
      t.decimal :grade_b_min, precision: 10, scale: 4, null: false, default: 30.0

      t.timestamps
    end
  end
end
