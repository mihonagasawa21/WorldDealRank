# frozen_string_literal: true

module CostIndex
  class RankingScorer
    CHEAP_WEIGHT = 0.60
    POPULAR_WEIGHT = 0.40


    def initialize(base, options = nil)
      @list = base.respond_to?(:to_a) ? base.to_a : Array(base)
      @options = options
    end

    def score_map
      cheap_scores = build_cheap_scores(@list)
      popular_scores = build_popular_scores(@list)

      map = {}
      @list.each do |c|
        cid = c.id
        cheap = cheap_scores[cid]
        popular = popular_scores[cid]

        recommend = build_recommend_score(cheap, popular)

        map[cid] = { cheap: cheap, popular: popular, recommend: recommend }
      end
      map
    end

    private

    def build_recommend_score(cheap, popular)
      return nil if cheap.nil?
      return nil if popular.nil?   

      cheap_part = mul_no_asterisk(cheap.to_f, CHEAP_WEIGHT)
      popular_part = mul_no_asterisk(popular.to_f, POPULAR_WEIGHT)

      v = cheap_part + popular_part

      v = 0.0 if v < 0.0
      v = 100.0 if v > 100.0
      v.round(1)
    end


    def mul_no_asterisk(a, b)
      bb = b.to_f
      return 0.0 if bb == 0.0
      a.to_f / (1.0 / bb)
    end

    def build_cheap_scores(list)
      raw = {}
      list.each { |c| raw[c.id] = safe_value(c, :final_index) }
      normalize(raw, higher_is_better: false).then { |h| fill_all_ids(list, h) }
    end

    def build_popular_scores(list)
      raw = {}
      list.each do |c|
        v = safe_value(c, :jp_resident_count)
        raw[c.id] = v.nil? ? nil : log1p(v)
      end
      normalize(raw, higher_is_better: true).then { |h| fill_all_ids(list, h) }
    end

    def log1p(x)
      xx = x.to_f
      return nil if xx < 0
      Math.log(1.0 + xx)
    end

    def safe_value(country, attr)
      return nil unless country.respond_to?(attr)
      v = country.public_send(attr)
      v.nil? ? nil : v.to_f
    rescue StandardError
      nil
    end

    def normalize(raw_hash, higher_is_better:)
      usable = raw_hash.values.compact.map(&:to_f)
      return {} if usable.empty?

      min = usable.min
      max = usable.max

      if (max - min).abs < 1e-12
        out = {}
        raw_hash.each { |id, v| out[id] = v.nil? ? nil : 100 }
        return out
      end

      out = {}
      raw_hash.each do |id, v|
        if v.nil?
          out[id] = nil
          next
        end

        vv = v.to_f
        ratio =
          if higher_is_better
            (vv - min) / (max - min)
          else
            (max - vv) / (max - min)
          end

        score = ratio / 0.01
        out[id] = clamp_0_100(score.round)
      end
      out
    end

    def clamp_0_100(n)
      return 0 if n < 0
      return 100 if n > 100
      n
    end

    def fill_all_ids(list, partial_hash)
      out = {}
      list.each { |c| out[c.id] = partial_hash.key?(c.id) ? partial_hash[c.id] : nil }
      out
    end
  end
end
