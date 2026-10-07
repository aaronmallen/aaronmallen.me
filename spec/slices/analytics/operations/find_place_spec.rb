# frozen_string_literal: true

RSpec.describe Analytics::Operations::FindPlace do
  def place_of(address) = described_class.new.call(address)

  before { use_country_database }

  describe "with a database on disk" do
    before { write_country_database }

    it "finds the city and country of an address the database holds" do
      expect(place_of("81.2.69.160")).to have_attributes(city: "London", country: "GB")
    end

    it "finds the country with no city when the database names none" do
      expect(place_of("1.2.3.4")).to have_attributes(city: nil, country: "US")
    end

    it "finds the city with no country when the database names none" do
      expect(place_of("198.51.100.7")).to have_attributes(city: "Nowhere", country: nil)
    end

    it "finds nothing for an address the database doesn't hold" do
      expect(place_of("8.8.8.8")).to have_attributes(city: nil, country: nil)
    end

    it "finds nothing for an address that isn't one" do
      expect(place_of("not an address")).to have_attributes(city: nil, country: nil)
    end
  end

  describe "with no MaxMind key, the way ADR 0009 allows" do
    before { disconnect_maxmind_client }

    it "finds nothing" do
      expect(place_of("81.2.69.160")).to have_attributes(city: nil, country: nil)
    end
  end
end
