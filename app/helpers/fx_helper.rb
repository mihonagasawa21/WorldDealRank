module FxHelper
  CURRENCY_JA = {
    "JPY" => "日本円",
    "USD" => "米ドル",
    "EUR" => "ユーロ",
    "GBP" => "英ポンド",
    "AUD" => "豪ドル",
    "CAD" => "カナダドル",
    "CHF" => "スイスフラン",
    "CNY" => "中国人民元",
    "KRW" => "韓国ウォン",
    "HKD" => "香港ドル",
    "SGD" => "シンガポールドル",
    "THB" => "タイバーツ",
    "TWD" => "台湾ドル",
    "INR" => "インドルピー",
    "IDR" => "インドネシアルピア",
    "MYR" => "マレーシアリンギット",
    "PHP" => "フィリピンペソ",
    "VND" => "ベトナムドン"
  }.freeze

  def currency_ja(iso)
    iso = iso.to_s
    name = CURRENCY_JA[iso]
    name ? "#{name}（#{iso}）" : iso
  end
end