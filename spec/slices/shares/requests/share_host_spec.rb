# frozen_string_literal: true

RSpec.describe "The share host", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }
  let(:bytes) { "0123456789" }

  before do
    allow(Hanami).to receive(:boot)
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
    stub_request(:head, %r{\A#{share_store_url}/})
  end

  def disposition = last_response.headers["Content-Disposition"]

  def fetch(path, **env) = get(path, {}, { "HTTP_HOST" => "shares.localhost" }.merge(env))

  def share(filename = "notes.txt", type = "text/plain") = upload_share(bytes, filename, type).value!

  def stored_as(type)
    file = share("photo.png", "image/png")
    Shares::Slice["relations.shares"].by_pk(file.id).update(content_type: type)
    Shares::Slice["repos.share_queries"].find(file.id)
  end

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

  it "still serves a share under a 5-letter code", :aggregate_failures do
    file = Shares::Slice["operations.change_share_code"].call(share.id, code: "abcde").value!
    stub_object(file)
    fetch("/abcde")

    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq(bytes)
  end

  it "waits 300 seconds for the store to answer" do
    expect(Shares::Slice["share_store.client"].instance_variable_get(:@connection).config.http_read_timeout).to eq(300)
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

  it "downloads a stored type that only begins with an inline type" do
    file = stored_as("image/png, text/html")
    stub_object(file)
    fetch("/#{file.code}")

    expect(disposition).to eq(%(attachment; filename="photo.png"; filename*=UTF-8''photo.png))
  end

  it "keeps a filename outside ASCII in the encoded name and swaps it in the plain one" do
    file = share("café \"menu\".zip", "application/zip")
    stub_object(file)
    fetch("/#{file.code}")

    expect(disposition).to eq(%(attachment; filename="caf_ _menu_.zip"; filename*=UTF-8''caf%C3%A9%20%22menu%22.zip))
  end

  it "sandboxes the file and lets it load nothing" do
    file = share("page.html", "text/html")
    stub_object(file)
    fetch("/#{file.code}")

    expect(last_response.headers["Content-Security-Policy"]).to start_with("sandbox; default-src 'none';")
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

  describe "a share whose object is missing" do
    let(:file) { share }

    before do
      stub_request(:head, share_store_url(file.key)).to_return(status: 404)
      fetch("/#{file.code}", "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Safari/605.1.15")
    end

    it "answers 404 and asks the store for no body", :aggregate_failures do
      expect(last_response.status).to eq(404)
      expect(a_request(:get, share_store_url(file.key))).not_to have_been_made
    end

    it "counts no download" do
      expect(Shares::Slice["relations.shares"].by_pk(file.id).one[:download_count]).to eq(0)
    end
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

  describe "past the cap on transfers in flight", :commits do
    let(:gate) { Queue.new }
    let(:group) { Shares::Slice["operations.upload_share_group"].call([share_upload(bytes, "a.txt", "text/plain")]).value! }
    let(:transfers) { [] }

    def download = "/#{group.code}/#{group.share_group_files.first.id}"

    def free = transfers.size.times { gate << true }

    def limit = Hanami.app.settings.web_threads - 2

    before do
      group
      started = Queue.new
      store = instance_double(ObjectStore::Client, configured?: true, exists?: true)
      allow(store).to receive(:stream) do |*, &chunk|
        started << true
        gate.pop(timeout: 5)
        chunk.call(bytes)
      end
      replace_component("share_store.client", store)
      app
      limit.times { transfers << Thread.new { Rack::MockRequest.new(app).get(download, "HTTP_HOST" => "shares.localhost") } }
      Timeout.timeout(5) { limit.times { started.pop } }
    end

    after do
      free
      transfers.each(&:join)
    end

    it "answers a download with 503 and Retry-After at once", :aggregate_failures do
      fetch(download)

      expect(last_response.status).to eq(503)
      expect(last_response.headers["Retry-After"]).to eq("10")
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end

    it "answers a range request with 503" do
      fetch(download, "HTTP_RANGE" => "bytes=2-5")

      expect(last_response.status).to eq(503)
    end

    it "answers a zip with 503" do
      fetch("/#{group.code}.zip")

      expect(last_response.status).to eq(503)
    end

    it "still serves the group's page" do
      fetch("/#{group.code}")

      expect(last_response.status).to eq(200)
    end

    it "still serves a blog page" do
      get "/about", {}, "HTTP_HOST" => "aaronmallen.me"

      expect(last_response.status).to eq(200)
    end

    it "lets the transfers in flight finish and frees their places", :aggregate_failures do
      free
      expect(transfers.map { it.value.status }).to all(eq(200))

      gate << true
      fetch(download)
      expect(last_response.status).to eq(200)
    end
  end

  describe "a group's code" do
    let(:browser) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15" }
    let(:page) { Capybara.string(last_response.body) }
    let(:group) do
      uploads = [
        share_upload(bytes, "beach.jpg", "image/jpeg"), share_upload(bytes, "dunes.png", "image/png"),
        share_upload(bytes, "notes.txt", "text/plain"), share_upload(bytes, "paper.pdf", "application/pdf"),
      ]
      Shares::Slice["operations.upload_share_group"].call(uploads).value!
    end

    def file(name) = group.share_group_files.find { it.filename == name }

    def file_downloads(name) = Shares::Slice["relations.share_group_files"].by_pk(file(name).id).one[:download_count]

    def name_group(name) = Shares::Slice["operations.name_share_group"].call(group.id, { name: }).value!

    def rename(file, filename) = Shares::Slice["operations.rename_share_file"].call(file.id, { filename: }).value!

    def views = Shares::Slice["relations.share_groups"].by_pk(group.id).one[:view_count]

    describe "a name" do
      it "titles the page", :aggregate_failures do
        name_group("Beach trip")
        fetch("/#{group.code}")

        expect(page).to have_css("h1", exact_text: "Beach trip")
        expect(page.find("title", visible: :all).text(:all)).to start_with("Beach trip |")
      end

      it "falls back to the plain title when left blank" do
        name_group("Beach trip")
        name_group(" ")
        fetch("/#{group.code}")

        expect(page).to have_css("h1", exact_text: Shares::GroupPage::TITLE)
      end
    end

    it "lists a renamed file under its new name at the same link" do
      rename(file("notes.txt"), "todo.txt")
      fetch("/#{group.code}")

      expect(page).to have_link("todo.txt", href: "/#{group.code}/#{file('notes.txt').id}")
    end

    it "downloads a renamed file under its new name" do
      rename(file("notes.txt"), "todo.txt")
      stub_request(:get, share_store_url(file("notes.txt").key)).to_return(body: bytes)
      fetch("/#{group.code}/#{file('notes.txt').id}")

      expect(disposition).to include('filename="todo.txt"')
    end

    describe "the page" do
      before do
        Shares::Slice["relations.share_group_files"].by_pk(file("beach.jpg").id).update(alt_text: "A wide beach")
        fetch("/#{group.code}")
      end

      it "answers with an HTML page no cache keeps", :aggregate_failures do
        expect(last_response.status).to eq(200)
        expect(last_response.headers["Content-Type"]).to eq("text/html; charset=utf-8")
        expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
      end

      it "loads nothing from another host" do
        expect(last_response.headers["Content-Security-Policy"]).to start_with("default-src 'none'")
      end

      it "shows the images in a carousel" do
        expect(page.all(".carousel img").map { it[:src] })
          .to eq(%w[beach.jpg dunes.png].map { "/#{group.code}/#{file(it).id}?preview" })
      end

      it "names each image by its alt text, or its filename when it has none" do
        expect(page.all(".carousel img").map { it[:alt] }).to eq(["A wide beach", "dunes.png"])
      end

      it "links each image to its file" do
        expect(page.all(".carousel a").map { it[:href] })
          .to eq(%w[beach.jpg dunes.png].map { "/#{group.code}/#{file(it).id}" })
      end

      it "lists the other files with a link to each" do
        expect(page.all(".files a").map { [it.text, it[:href]] }).to eq(
          %w[notes.txt paper.pdf].map { [it, "/#{group.code}/#{file(it).id}"] },
        )
      end
    end

    it "answers a head request for the page with no body", :aggregate_failures do
      head "/#{group.code}", {}, "HTTP_HOST" => "shares.localhost"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to be_empty
    end

    describe "a file's link" do
      before { stub_request(:get, share_store_url(file("paper.pdf").key)).to_return(body: bytes) }

      it "returns the file's bytes inline by its type", :aggregate_failures do
        fetch("/#{group.code}/#{file('paper.pdf').id}")

        expect(last_response.body).to eq(bytes)
        expect(last_response.headers["Content-Type"]).to eq("application/pdf")
        expect(disposition).to eq(%(inline; filename="paper.pdf"; filename*=UTF-8''paper.pdf))
      end

      it "forbids every cache to keep the file" do
        fetch("/#{group.code}/#{file('paper.pdf').id}")

        expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
      end

      it "returns 206 for a range" do
        stub_request(:get, share_store_url(file("paper.pdf").key))
          .with(headers: { "Range" => "bytes=2-5" }).to_return(body: "2345")
        fetch("/#{group.code}/#{file('paper.pdf').id}", "HTTP_RANGE" => "bytes=2-5")

        expect(last_response.status).to eq(206)
      end

      it "counts a download against that file alone", :aggregate_failures do
        expect { fetch("/#{group.code}/#{file('paper.pdf').id}", "HTTP_USER_AGENT" => browser) }
          .to change { file_downloads("paper.pdf") }.by(1)
        expect(file_downloads("notes.txt")).to eq(0)
        expect(views).to eq(0)
      end

      it "skips a range probe" do
        expect do
          fetch("/#{group.code}/#{file('paper.pdf').id}", "HTTP_USER_AGENT" => browser, "HTTP_RANGE" => "bytes=0-1")
        end
          .not_to(change { file_downloads("paper.pdf") })
      end

      it "skips the page's preview" do
        expect { fetch("/#{group.code}/#{file('paper.pdf').id}?preview", "HTTP_USER_AGENT" => browser) }
          .not_to(change { file_downloads("paper.pdf") })
      end

      it "skips a bot" do
        expect { fetch("/#{group.code}/#{file('paper.pdf').id}", "HTTP_USER_AGENT" => "curl/8.4.0") }
          .not_to(change { file_downloads("paper.pdf") })
      end
    end

    describe "the view count" do
      it "rises by one for a browser" do
        expect { fetch("/#{group.code}", "HTTP_USER_AGENT" => browser) }.to change { views }.from(0).to(1)
      end

      it "stays put for a bot" do
        expect { fetch("/#{group.code}", "HTTP_USER_AGENT" => "Slackbot-LinkExpanding 1.0") }.not_to(change { views })
      end

      it "stays put for a head request" do
        expect { head "/#{group.code}", {}, "HTTP_HOST" => "shares.localhost", "HTTP_USER_AGENT" => browser }
          .not_to(change { views })
      end

      it "stays put for a preview" do
        expect { fetch("/#{group.code}?preview", "HTTP_USER_AGENT" => browser) }.not_to(change { views })
      end
    end

    describe "the zip" do
      def unzip(body)
        io = StringIO.new(body)
        ZipKit::FileReader.read_zip_structure(io:).to_h do |entry|
          [entry.filename, entry.extractor_from(io).extract]
        end
      end

      def zip_downloads = Shares::Slice["relations.share_groups"].by_pk(group.id).one[:zip_download_count]

      before do
        group.share_group_files.each do |file|
          stub_request(:get, share_store_url(file.key)).to_return(body: file.filename)
        end
      end

      it "has a download all button on the page" do
        fetch("/#{group.code}")

        expect(page).to have_link("Download all", href: "/#{group.code}.zip")
      end

      it "holds every file under its own name", :aggregate_failures do
        fetch("/#{group.code}.zip")

        expect(last_response.status).to eq(200)
        expect(unzip(last_response.body)).to eq(%w[beach.jpg dunes.png notes.txt paper.pdf].to_h { [it, it] })
      end

      it "downloads as an attachment no cache keeps", :aggregate_failures do
        fetch("/#{group.code}.zip")

        expect(last_response.headers["Content-Type"]).to eq("application/zip")
        expect(disposition).to eq(%(attachment; filename="#{group.code}.zip"; filename*=UTF-8''#{group.code}.zip))
        expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
      end

      it "downloads a named group under its name" do
        name_group("Beach trip")
        fetch("/#{group.code}.zip")

        expect(disposition).to eq(%(attachment; filename="Beach trip.zip"; filename*=UTF-8''Beach%20trip.zip))
      end

      it "holds a renamed file under its new name" do
        rename(file("notes.txt"), "todo.txt")
        fetch("/#{group.code}.zip")

        expect(unzip(last_response.body).keys).to eq(%w[beach.jpg dunes.png todo.txt paper.pdf])
      end

      it "gives a second file of the same name a name of its own" do
        Shares::Slice["relations.share_group_files"].by_pk(file("dunes.png").id).update(filename: "beach.jpg")
        fetch("/#{group.code}.zip")

        expect(unzip(last_response.body).keys).to eq(["beach.jpg", "beach (1).jpg", "notes.txt", "paper.pdf"])
      end

      it "writes a stored name with a folder part as a bare name" do
        files = Shares::Slice["relations.share_group_files"]
        { "beach.jpg" => "../../beach.jpg", "dunes.png" => "/tmp/dunes.png", "notes.txt" => ".." }
          .each { |from, to| files.by_pk(file(from).id).update(filename: to) }
        fetch("/#{group.code}.zip")

        expect(unzip(last_response.body).keys).to eq([".._.._beach.jpg", "_tmp_dunes.png", "__", "paper.pdf"])
      end

      it "writes nothing to the bucket" do
        group
        WebMock::RequestRegistry.instance.reset!
        fetch("/#{group.code}.zip")

        expect(a_request(:put, %r{\A#{share_store_url}/})).not_to have_been_made
      end

      it "counts a browser download against the zip alone", :aggregate_failures do
        expect { fetch("/#{group.code}.zip", "HTTP_USER_AGENT" => browser) }.to change { zip_downloads }.from(0).to(1)
        expect(views).to eq(0)
        expect(file_downloads("notes.txt")).to eq(0)
      end

      it "skips a bot" do
        expect { fetch("/#{group.code}.zip", "HTTP_USER_AGENT" => "curl/8.4.0") }.not_to(change { zip_downloads })
      end

      it "answers a head request with no body and no count", :aggregate_failures do
        expect { head "/#{group.code}.zip", {}, "HTTP_HOST" => "shares.localhost", "HTTP_USER_AGENT" => browser }
          .not_to(change { zip_downloads })
        expect(last_response.body).to be_empty
      end

      it "answers 404 under a single share's code" do
        fetch("/#{upload_share.value!.code}.zip")

        expect(last_response.status).to eq(404)
      end

      it "answers 503 when the share store is not configured" do
        group
        connect_share_store(access_key: nil)
        fetch("/#{group.code}.zip")

        expect(last_response.status).to eq(503)
      end
    end

    it "answers 404 for an id outside the group" do
      fetch("/#{group.code}/#{group.share_group_files.map(&:id).max + 1}")

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a group's file under a single share's code" do
      fetch("/#{upload_share.value!.code}/#{file('notes.txt').id}")

      expect(last_response.status).to eq(404)
    end

    %w[/0 /01 /x /1/2].each do |suffix|
      it "answers 404 for #{suffix} under the code" do
        fetch("/#{group.code}#{suffix}")

        expect(last_response.status).to eq(404)
      end
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
    file = share.tap { Shares::Slice["relations.short_codes"].where(code: it.code).update(code: "zzq") }
    get "/zzq", {}, "HTTP_HOST" => "aaronmallen.me"

    expect(last_response.status).to eq(404)
    expect(last_response.headers["Cache-Control"]).not_to eq("private, no-store")
    expect(a_request(:get, share_store_url(file.key))).not_to have_been_made
  end

  describe "a forwarded host header" do
    { "HTTP_X_FORWARDED_HOST" => "shares.localhost",
      "HTTP_FORWARDED" => "host=shares.localhost" }.each do |header, value|
      it "gives the blog's answer to a request for the blog's host under #{header}", :aggregate_failures do
        file = share
        get "/#{file.code}", {}, "HTTP_HOST" => "aaronmallen.me", header => value

        expect(last_response.headers["Cache-Control"]).not_to eq("private, no-store")
        expect(a_request(:get, share_store_url(file.key))).not_to have_been_made
      end
    end

    it "still serves a known code on the share host" do
      file = share
      stub_object(file)
      fetch("/#{file.code}", "HTTP_X_FORWARDED_HOST" => "aaronmallen.me", "HTTP_FORWARDED" => "host=aaronmallen.me")

      expect(last_response.body).to eq(bytes)
    end

    it "still answers 404 for an unknown code on the share host without letting a cache keep it", :aggregate_failures do
      fetch("/zzzzz", "HTTP_X_FORWARDED_HOST" => "aaronmallen.me", "HTTP_FORWARDED" => "host=aaronmallen.me")

      expect(last_response.status).to eq(404)
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end
  end

  describe "a file that moves between a share and a group" do
    let(:first) { share("one.txt") }
    let(:second) { share("two.txt") }
    let(:group) { Shares::Slice["operations.group_shares"].call([first.id, second.id]).value! }

    def count_of(id) = Shares::Slice["relations.share_group_files"].by_pk(id).one[:download_count]

    def download(path)
      fetch(path,
            "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15")
    end

    def ungroup(id) = Shares::Slice["operations.ungroup_share_file"].call(group.id, id).value!

    before do
      stub_object(first)
      stub_object(second)
      Shares::Slice["relations.share_group_files"].by_pk(first.id).update(download_count: 4)
    end

    it "answers 404 under a share's old code once it joins a group" do
      old = first.code
      group
      fetch("/#{old}")

      expect(last_response.status).to eq(404)
    end

    it "frees the old code for a short link", :aggregate_failures do
      old = first.code
      group
      link = Shares::Slice["operations.create_short_link"].call(destination: "https://example.com", code: old)

      expect(link).to be_success
      expect(link.value!.code).to eq(old)
    end

    it "serves the file under the group's code and its id, with its downloads kept", :aggregate_failures do
      download("/#{group.code}/#{first.id}")

      expect(last_response.body).to eq(bytes)
      expect(count_of(first.id)).to eq(5)
    end

    it "keeps each group file's link and downloads when another file leaves", :aggregate_failures do
      ungroup(second.id)
      download("/#{group.code}/#{first.id}")

      expect(last_response.body).to eq(bytes)
      expect(count_of(first.id)).to eq(5)
    end

    it "serves a file pulled out of a group under its own new code, with its downloads kept", :aggregate_failures do
      moved = ungroup(first.id)
      download("/#{moved.code}")

      expect(last_response.body).to eq(bytes)
      expect(count_of(first.id)).to eq(5)
    end

    it "answers 404 for a pulled out file under the group's code" do
      ungroup(first.id)
      fetch("/#{group.code}/#{first.id}")

      expect(last_response.status).to eq(404)
    end

    it "keeps a group file's link when shares join its group" do
      third = share("three.txt")
      Shares::Slice["operations.add_shares_to_group"].call(group.id, [third.id])
      fetch("/#{group.code}/#{first.id}")

      expect(last_response.body).to eq(bytes)
    end
  end

  it "knows the share host with a port on it" do
    fetch("/zzzzz", "HTTP_HOST" => "shares.localhost:3000")

    expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
  end

  it "serves the blog on its own host" do
    get "/about", {}, "HTTP_HOST" => "aaronmallen.me"

    expect(last_response.status).to eq(200)
  end
end
