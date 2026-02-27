require "rails_helper"

RSpec.describe Billing::AreaGradeResolver do
  describe ".supported_cities" do
    it "includes all tokyo 23 wards" do
      expect(described_class.supported_cities.size).to eq(23)
      expect(described_class.supported_cities).to include("目黒区", "江戸川区")
    end
  end

  describe "#resolve" do
    it "resolves tokyo 23 ward to grade_1" do
      resolver = described_class.new
      grade = resolver.resolve(city_name: "目黒区")

      expect(grade).to be_a(Billing::AreaGrade)
      expect(grade.code).to eq(:grade_1)
      expect(grade.unit_price).to eq(BigDecimal("10.90"))
    end

    it "raises for undefined city_name" do
      resolver = described_class.new

      expect { resolver.resolve(city_name: "調布市") }
        .to raise_error(ArgumentError, /unsupported city_name/)
    end
  end
end
