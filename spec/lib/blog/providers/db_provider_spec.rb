# frozen_string_literal: true

RSpec.describe Blog::Providers::DBProvider do
  describe ".database_url" do
    def credentials(**database)
      url = described_class.database_url({ host: "localhost", name: "blog", port: 5432, **database })
      db = Sequel.connect(url, keep_reference: false, test: false)

      db.opts.slice(:user, :password)
    ensure
      db&.disconnect
    end

    it "hands libpq no user or password when neither is set" do
      expect(credentials).to eq(user: nil, password: nil)
    end

    it "hands libpq the user alone" do
      expect(credentials(user: "blog")).to eq(user: "blog", password: nil)
    end

    it "hands libpq the user and password, escaped on the way" do
      expect(credentials(password: "p@ss:w/rd", user: "b log")).to eq(user: "b log", password: "p@ss:w/rd")
    end

    it "hands libpq a blank user with the password, so libpq falls back to the OS user" do
      expect(credentials(password: "p@ss", user: nil)).to eq(user: "", password: "p@ss")
    end
  end
end
