# frozen_string_literal: true

RSpec.describe Blog::Providers::HTTPProvider do
  def url_for(base, path)
    connection = described_class.build(Hanami.app.settings).call(url: base) { nil }

    connection.build_exclusive_url(path).to_s
  end

  it "keeps the base URL's path for a path that starts at the root" do
    expect(url_for("http://stub.localhost/github/api", "/repos/a/b")).to eq("http://stub.localhost/github/api/repos/a/b")
  end

  it "keeps the base URL's path for a relative path" do
    expect(url_for("http://stub.localhost/github/api", "repos/a/b")).to eq("http://stub.localhost/github/api/repos/a/b")
  end

  it "reaches the same URL as before for a base URL with no path" do
    expect(url_for("https://api.github.com", "/repos/a/b")).to eq("https://api.github.com/repos/a/b")
  end

  it "leaves a full URL alone" do
    expect(url_for("http://stub.localhost/github/api", "https://example.com/x")).to eq("https://example.com/x")
  end

  it "keeps a path that starts with two slashes on the base host" do
    expect(URI(url_for("https://api.github.com", "//evil.example/x")).host).to eq("api.github.com")
  end
end
