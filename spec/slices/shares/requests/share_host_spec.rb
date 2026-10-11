# frozen_string_literal: true

RSpec.describe "The share host", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }
  let(:bytes) { "0123456789" }

  before do
    allow(Hanami).to receive(:boot)
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
  end

  def disposition = last_response.headers["Content-Disposition"]

  def fetch(path, **env) = get(path, {}, { "HTTP_HOST" => "shares.localhost" }.merge(env))

  def share(filename = "notes.txt", type = "text/plain") = upload_share(bytes, filename, type).value!

  def stub_object(share, range: nil, body: bytes)
    stub = stub_request(:get, share_store_url(share.key))
    stub = stub.with(headers: { "Range" => range }) if range
    stub.to_return(body:)
  end

  describe "a known code" do
    let(:file) { share }

    before do
      stub_object(file)
      fetch("/#{file.code}")
    end

    it "returns the file's exact bytes", :aggregate_failures do
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(bytes)
      expect(last_response.headers["Content-Length"]).to eq("10")
      expect(last_response.headers["Content-Type"]).to eq("text/plain")
    end

    it "forbids every cache to keep it" do
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end

    it "offers byte ranges" do
      expect(last_response.headers["Accept-Ranges"]).to eq("bytes")
    end
  end

  it "answers a head request with no body", :aggregate_failures do
    file = share
    head "/#{file.code}", {}, "HTTP_HOST" => "shares.localhost"

    expect(last_response.status).to eq(200)
    expect(last_response.body).to be_empty
    expect(a_request(:get, share_store_url(file.key))).not_to have_been_made
  end

  {
    "image/jpeg" => "photo.jpg", "application/pdf" => "paper.pdf", "video/mp4" => "clip.mp4",
    "audio/mpeg" => "song.mp3",
  }.each do |type, filename|
    it "opens #{type} in the browser" do
      file = share(filename, type)
      stub_object(file)
      fetch("/#{file.code}")

      expect(disposition).to eq(%(inline; filename="#{filename}"; filename*=UTF-8''#{filename}))
    end
  end

  {
    "application/zip" => "archive.zip", "text/html" => "page.html", "image/svg+xml" => "logo.svg",
  }.each do |type, filename|
    it "downloads #{type} under its original name" do
      file = share(filename, type)
      stub_object(file)
      fetch("/#{file.code}")

      expect(disposition).to eq(%(attachment; filename="#{filename}"; filename*=UTF-8''#{filename}))
    end
  end

  it "keeps a filename outside ASCII in the encoded name and swaps it in the plain one" do
    file = share("café \"menu\".zip", "application/zip")
    stub_object(file)
    fetch("/#{file.code}")

    expect(disposition).to eq(%(attachment; filename="caf_ _menu_.zip"; filename*=UTF-8''caf%C3%A9%20%22menu%22.zip))
  end

  it "stops the browser sniffing another type" do
    file = share("page.html", "text/html")
    stub_object(file)
    fetch("/#{file.code}")

    expect(last_response.headers["X-Content-Type-Options"]).to eq("nosniff")
  end

  describe "a range request" do
    let(:file) { share("clip.mp4", "video/mp4") }

    before do
      stub_object(file, range: "bytes=2-5", body: "2345")
      fetch("/#{file.code}", "HTTP_RANGE" => "bytes=2-5")
    end

    it "returns 206 with the asked bytes", :aggregate_failures do
      expect(last_response.status).to eq(206)
      expect(last_response.body).to eq("2345")
      expect(last_response.headers["Content-Range"]).to eq("bytes 2-5/10")
      expect(last_response.headers["Content-Length"]).to eq("4")
    end

    it "forbids every cache to keep it" do
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end
  end

  describe "the download count" do
    let(:browser) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15" }
    let(:file) { share("clip.mp4", "video/mp4") }

    def downloads = Shares::Slice["relations.shares"].by_pk(file.id).one[:download_count]

    before { stub_object(file) }

    it "rises by one for a browser download" do
      expect { fetch("/#{file.code}", "HTTP_USER_AGENT" => browser) }.to change { downloads }.from(0).to(1)
    end

    it "rises by one for a range that starts at byte 0" do
      expect { fetch("/#{file.code}", "HTTP_USER_AGENT" => browser, "HTTP_RANGE" => "bytes=0-5") }
        .to change { downloads }.by(1)
    end

    it "rises by one for an open range from byte 0" do
      expect { fetch("/#{file.code}", "HTTP_USER_AGENT" => browser, "HTTP_RANGE" => "bytes=0-") }
        .to change { downloads }.by(1)
    end

    %w[bytes=0-1 bytes=0-0].each do |range|
      it "stays put for Safari's #{range} probe" do
        expect { fetch("/#{file.code}", "HTTP_USER_AGENT" => browser, "HTTP_RANGE" => range) }
          .not_to(change { downloads })
      end
    end

    it "stays put for a range that starts past byte 0" do
      expect { fetch("/#{file.code}", "HTTP_USER_AGENT" => browser, "HTTP_RANGE" => "bytes=2-5") }
        .not_to(change { downloads })
    end

    {
      "Slack" => "Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)",
      "iMessage" => "Mozilla/5.0 (Macintosh) AppleWebKit/601.2.4 facebookexternalhit/1.1 Facebot Twitterbot/1.0",
      "curl" => "curl/8.4.0",
      "no user agent" => "",
    }.each do |named, agent|
      it "stays put for #{named}" do
        expect { fetch("/#{file.code}", "HTTP_USER_AGENT" => agent) }.not_to(change { downloads })
      end
    end

    it "stays put for a head request" do
      expect { head "/#{file.code}", {}, "HTTP_HOST" => "shares.localhost", "HTTP_USER_AGENT" => browser }
        .not_to(change { downloads })
    end

    it "stays put for the admin's thumbnail preview" do
      expect { fetch("/#{file.code}?preview", "HTTP_USER_AGENT" => browser) }.not_to(change { downloads })
    end

    it "stays put for a 404", :aggregate_failures do
      expect { fetch("/#{file.code}x", "HTTP_USER_AGENT" => browser) }.not_to(change { downloads })
      expect(last_response.status).to eq(404)
    end
  end

  it "answers 416 for a range past the end", :aggregate_failures do
    file = share
    fetch("/#{file.code}", "HTTP_RANGE" => "bytes=20-30")

    expect(last_response.status).to eq(416)
    expect(last_response.headers["Content-Range"]).to eq("bytes */10")
  end

  it "answers 503 when the share store is not configured" do
    file = share
    connect_share_store(access_key: nil)
    fetch("/#{file.code}")

    expect(last_response.status).to eq(503)
  end

  describe "an error in the share server" do
    let(:agent) { Hanami.app["honeybadger.agent"] }
    let(:crash) { RuntimeError.new("store down") }

    before do
      queries = instance_double(Shares::Repos::ShareQueries)
      allow(queries).to receive(:by_code).and_raise(crash)
      replace_component("repos.share_queries", queries)
      allow(agent).to receive(:notify)
    end

    it "reaches Honeybadger", :aggregate_failures do
      expect { fetch("/abcde") }.to raise_error(crash)
      expect(agent).to have_received(:notify).with(crash)
    end
  end

  it "answers 404 for a deleted share" do
    file = share
    stub_request(:delete, share_store_url(file.key))
    Shares::Slice["operations.delete_share"].call(file.id)
    fetch("/#{file.code}")

    expect(last_response.status).to eq(404)
  end

  it "answers 404 for a share posted to" do
    file = share
    post "/#{file.code}", {}, "HTTP_HOST" => "shares.localhost"

    expect(last_response.status).to eq(404)
  end

  %w[/ /admin /posts /writing /unknown /favicon.ico /.well-known/oauth-authorization-server].each do |path|
    it "answers 404 for #{path} without letting a cache keep it", :aggregate_failures do
      fetch(path)

      expect(last_response.status).to eq(404)
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end
  end

  it "leaves the blog's host as it was", :aggregate_failures do
    file = share
    get "/#{file.code}", {}, "HTTP_HOST" => "aaronmallen.me"

    expect(last_response.status).to eq(404)
    expect(last_response.headers["Cache-Control"]).not_to eq("private, no-store")
    expect(a_request(:get, share_store_url(file.key))).not_to have_been_made
  end

  it "serves the blog on its own host" do
    get "/about", {}, "HTTP_HOST" => "aaronmallen.me"

    expect(last_response.status).to eq(200)
  end
end
