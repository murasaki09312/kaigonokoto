module Billing
  class AreaGradeResolver
    TOKYO_23_WARDS = %w[
      千代田区
      中央区
      港区
      新宿区
      文京区
      台東区
      墨田区
      江東区
      品川区
      目黒区
      大田区
      世田谷区
      渋谷区
      中野区
      杉並区
      豊島区
      北区
      荒川区
      板橋区
      練馬区
      足立区
      葛飾区
      江戸川区
    ].freeze

    CITY_TO_GRADE_CODE = TOKYO_23_WARDS.to_h { |city| [ city, :grade_1 ] }.freeze

    def self.supported_cities
      CITY_TO_GRADE_CODE.keys
    end

    def resolve(city_name:)
      city = city_name.to_s.strip
      raise ArgumentError, "city_name is required" if city.blank?

      grade_code = CITY_TO_GRADE_CODE[city]
      raise ArgumentError, "unsupported city_name: #{city_name}" if grade_code.nil?

      Billing::AreaGrade.new(code: grade_code)
    end
  end
end
