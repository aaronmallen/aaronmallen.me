# frozen_string_literal: true

RSpec.describe "A short link on the share host", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }
  let(:browser) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15" }
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination: "https://example.com/talk").value! }

  before { allow(Hanami).to receive(:boot) }

  def fetch(code, agent = browser) = get("/#{code}", {}, "HTTP_HOST" => "shares.localhost", "HTTP_USER_AGENT" => agent)

  def stored = Shares::Slice["relations.short_links"].by_pk(link.id).one

  it "answers 302 to the destination and forbids every cache to keep it", :aggregate_failures do
    fetch(link.code)

    expect(last_response.status).to eq(302)
    expect(last_response.headers["Location"]).to eq("https://example.com/talk")
    expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
  end

  it "sends people to the new place once the link points somewhere new" do
    Shares::Slice["operations.retarget_short_link"].call(link.id, destination: "https://example.org")
    fetch(link.code)

    expect(last_response.headers["Location"]).to eq("https://example.org")
  end

  it "still sends people to a destination the link check marks as failing" do
    resolves_publicly("example.com")
    stub_request(:get, "https://example.com/talk").to_return(status: 404)
    Shares::Slice["operations.check_short_links"].again(link.id)
    fetch(link.code)

    expect(last_response.headers["Location"]).to eq("https://example.com/talk")
  end

  it "still sends a link made under an older, longer code" do
    Shares::Slice["relations.short_codes"].where(code: link.code).update(code: "ab2cd")
    fetch("ab2cd")

    expect(last_response.headers["Location"]).to eq("https://example.com/talk")
  end

  describe "a changed code" do
    let!(:old) { link.code }

    before { Shares::Slice["operations.change_short_link_code"].call(link.id, code: "talk") }

    it "answers 404 for the old code and forbids every cache to keep it", :aggregate_failures do
      fetch(old)

      expect(last_response.status).to eq(404)
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end

    it "sends the new code to the destination" do
      fetch("talk")

      expect(last_response.status).to eq(302)
    end
  end

  it "answers 404 for a deleted link" do
    Shares::Slice["operations.delete_short_link"].call(link.id)
    fetch(link.code)

    expect(last_response.status).to eq(404)
  end

  it "counts a browser click and stamps when", :aggregate_failures do
    expect { fetch(link.code) }.to change { stored[:click_count] }.from(0).to(1)
    expect(stored[:last_clicked_at]).not_to be_nil
  end

  it "counts and reads a browser click in one statement" do
    code = link.code

    expect(counting { fetch(code) }).to contain_exactly(/\AUPDATE "short_links" .* RETURNING "destination"/)
  end

  it "reads a bot's click in one statement" do
    code = link.code

    expect(counting { fetch(code, "curl/8.4.0") }).to contain_exactly(/\ASELECT/)
  end

  {
    "Slack" => "Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)",
    "curl" => "curl/8.4.0",
    "Mastodon" => "http.rb/5.2.0 (Mastodon/4.3.0; +https://mastodon.example/)",
    "Pleroma" => "Pleroma 2.7.0; https://pleroma.example",
    "Akkoma" => "Akkoma 3.13.2; https://akkoma.example",
    "Misskey" => "Misskey/2024.10.1 (https://misskey.example)",
    "Bluesky" => "Mozilla/5.0 (compatible; Cardyb/1.1)",
    "the link check" => "aaronmallen.me link-check (+https://aaronmallen.me)",
    "the link title fetch" => "aaronmallen.me link-title (+https://aaronmallen.me)",
    "the webmention fetch" => "aaronmallen.me webmention (+https://aaronmallen.me)",
    "no user agent" => "",
  }.each do |named, agent|
    it "leaves the count and stamp alone for #{named}", :aggregate_failures do
      fetch(link.code, agent)

      expect(stored[:click_count]).to eq(0)
      expect(stored[:last_clicked_at]).to be_nil
    end
  end

  it "leaves the count alone for a head request" do
    head "/#{link.code}", {}, "HTTP_HOST" => "shares.localhost", "HTTP_USER_AGENT" => browser

    expect(stored[:click_count]).to eq(0)
  end

  it "leaves the blog's host as it was" do
    get "/#{link.code}", {}, "HTTP_HOST" => "aaronmallen.me"

    expect(last_response.status).to eq(404)
  end
end
