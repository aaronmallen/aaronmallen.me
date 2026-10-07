# frozen_string_literal: true

RSpec.describe "Webmentions", type: :request do
  let(:source) { "https://ada.example/notes/1" }
  let(:elsewhere) { { "HTTP_HOST" => "pi.local" } }
  let(:target) { "https://aaronmallen.me/writing/hello" }
  let(:webmention_mutations) { Social::Slice["repos.webmention_mutations"] }

  def entry
    <<~HTML
      <div class="h-entry">
        <a class="p-author h-card" href="https://ada.example/about">Ada</a>
        <a class="u-in-reply-to" href="#{target}">re</a>
        <p class="e-content">Nice post</p>
      </div>
    HTML
  end

  def notify(env = {}, **params) = post("/webmention", { source:, target: }.merge(params), env)

  def stored
    post_id = Posts::Slice["repos.post_queries"].published_by_slug("hello").id

    webmentions.for_post(post_id).from_source(source).one
  end

  def webmentions = Social::Slice["relations.webmentions"].with(auto_struct: true, struct_namespace: Social::Structs)

  before do
    resolves_publicly("ada.example", "elsewhere.example")
    create(:post, :published, slug: "hello")
  end

  describe "an eligible target" do
    it "accepts the notification" do
      notify

      expect(last_response.status).to eq(202)
    end

    it "answers with nothing to read" do
      notify

      expect(last_response.body).to be_empty
    end

    %w[application/json text/plain text/html */*].each do |accept|
      it "accepts the notification from a sender asking for #{accept}" do
        notify("HTTP_ACCEPT" => accept)

        expect(last_response.status).to eq(202)
      end
    end

    it "queues the verification" do
      notify

      expect(Social::Jobs::VerifyWebmention.jobs).to have(1).item
    end

    it "stores a pending mention once the job runs" do
      stub_request(:get, source).to_return(body: entry)
      notify
      Social::Jobs::VerifyWebmention.drain

      expect(stored).to have_attributes(status: "pending", author_name: "Ada", type: "reply", excerpt: "Nice post")
    end

    it "accepts one another site's page sent, since other sites are meant to call it" do
      notify({ "HTTP_SEC_FETCH_SITE" => "cross-site", "HTTP_ORIGIN" => "https://ada.example" })

      expect(last_response.status).to eq(202)
    end

    it "accepts the canonical target however the request arrived" do
      notify(elsewhere)

      expect(last_response.status).to eq(202)
    end

    it "stores one mention however the source page is spelled" do
      stub_request(:get, source).to_return(body: entry)
      ["#{source}/", "#{source}#comment", "https://Ada.Example/notes/1", source].each { notify(source: it) }
      Social::Jobs::VerifyWebmention.drain

      expect(Social::Slice["relations.webmentions"].count).to eq(1)
    end
  end

  describe "a rejected notification" do
    it "rejects a missing source whatever the sender asks for" do
      post "/webmention", { target: }, "HTTP_ACCEPT" => "application/json"

      expect(last_response.status).to eq(400)
    end

    it "rejects a missing source" do
      post "/webmention", { target: }

      expect(last_response.status).to eq(400)
    end

    it "rejects a missing target" do
      post "/webmention", { source: }

      expect(last_response.status).to eq(400)
    end

    it "rejects a source that isn't a URL" do
      notify(source: "nope")

      expect(last_response.status).to eq(400)
    end

    ["mailto:ada@ada.example", "javascript:alert(1)", "tel:+15550100", "urn:isbn:1", "/notes/1"].each do |url|
      it "rejects a source of #{url.inspect}" do
        notify(source: url)

        expect(last_response.status).to eq(400)
      end
    end

    it "rejects a source that names no host" do
      notify(source: "https://@/notes/1")

      expect(last_response.status).to eq(400)
    end

    it "rejects a target naming the host that asked, when the site isn't there" do
      notify(elsewhere, target: "http://pi.local/writing/hello")

      expect(last_response.status).to eq(400)
    end

    it "rejects a target on another site" do
      notify(target: "https://elsewhere.example/writing/hello")

      expect(last_response.status).to eq(400)
    end

    it "rejects a target whose slug is not in slug format" do
      notify(target: "https://aaronmallen.me/writing/Hello")

      expect(last_response.status).to eq(400)
    end

    it "rejects a draft" do
      create(:post, :draft, slug: "draft")
      notify(target: "https://aaronmallen.me/writing/draft")

      expect(last_response.status).to eq(400)
    end

    it "rejects a scheduled post" do
      create(:post, :scheduled, slug: "later")
      notify(target: "https://aaronmallen.me/writing/later")

      expect(last_response.status).to eq(400)
    end

    it "rejects a post with webmentions off" do
      create(:post, :published, slug: "quiet", webmentions_enabled: false)
      notify(target: "https://aaronmallen.me/writing/quiet")

      expect(last_response.status).to eq(400)
    end

    it "rejects everything while receiving is off" do
      webmention_mutations.update_settings(receive: false)
      notify

      expect(last_response.status).to eq(400)
    end

    it "queues nothing" do
      notify(source: "nope")

      expect(Social::Jobs::VerifyWebmention.jobs).to be_empty
    end
  end

  describe "a source of 3,000 bytes" do
    let(:long_source) { "https://a.example/#{'a' * (3000 - 'https://a.example/'.bytesize)}" }

    before { notify(source: long_source) }

    it "rejects the notification" do
      expect(last_response.status).to eq(400)
    end

    it "stores no receipt" do
      expect(Social::Slice["relations.webmention_receipts"].count).to eq(0)
    end

    it "queues nothing" do
      expect(Social::Jobs::VerifyWebmention.jobs).to be_empty
    end
  end

  describe "the same pair sent again inside the window" do
    it "queues one verification" do
      3.times { notify }

      expect(Social::Jobs::VerifyWebmention.jobs).to have(1).item
    end

    it "refuses the repeat" do
      notify
      notify

      expect(last_response.status).to eq(429)
    end

    it "answers the repeat with nothing to read" do
      notify
      notify

      expect(last_response.body).to be_empty
    end
  end

  describe "the same pair sent again after the window" do
    let(:window) { Hanami.app["settings"].webmentions[:throttle_window_minutes] * 60 }

    before do
      notify
      allow(Time).to receive(:now).and_return(Time.now + window + 60)
      notify
    end

    it "accepts the repeat" do
      expect(last_response.status).to eq(202)
    end

    it "queues a second verification" do
      expect(Social::Jobs::VerifyWebmention.jobs).to have(2).items
    end
  end

  describe "a run of receipts past the limit" do
    let(:limit) { Hanami.app["settings"].webmentions[:throttle_limit] }

    before do
      lower_throttle_limit(:webmentions, to: 5)
      (limit + 1).times { |sent| notify(source: "https://ada.example/notes/#{sent}") }
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "queues no more than the limit" do
      expect(Social::Jobs::VerifyWebmention.jobs).to have(limit).items
    end

    it "answers with nothing to read" do
      expect(last_response.body).to be_empty
    end

    it "refuses a sender forging a forwarded address, since no proxy header is named" do
      notify({ "HTTP_X_FORWARDED_FOR" => "203.0.113.9" }, source: "https://ada.example/notes/forged")

      expect(last_response.status).to eq(429)
    end
  end

  describe "a run of receipts past the limit from one address with a new browser on each" do
    let(:limit) { Hanami.app["settings"].webmentions[:throttle_limit] }

    before do
      lower_throttle_limit(:webmentions, to: 5)
      (limit + 1).times do |sent|
        notify({ "HTTP_USER_AGENT" => "Mozilla/5.0 x#{sent}" }, source: "https://ada.example/notes/#{sent}")
      end
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "queues no more than the limit" do
      expect(Social::Jobs::VerifyWebmention.jobs).to have(limit).items
    end
  end

  describe "a run of receipts past the limit from one IPv6 /64 with a new address on each" do
    let(:limit) { Hanami.app["settings"].webmentions[:throttle_limit] }

    before do
      lower_throttle_limit(:webmentions, to: 5)
      (limit + 1).times do |sent|
        notify({ "REMOTE_ADDR" => "2001:db8:1:2::#{sent + 1}" }, source: "https://ada.example/notes/#{sent}")
      end
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "queues no more than the limit" do
      expect(Social::Jobs::VerifyWebmention.jobs).to have(limit).items
    end
  end

  describe "a receipt from a second IPv6 /64" do
    before do
      lower_throttle_limit(:webmentions, to: 5)
      5.times do |sent|
        notify({ "REMOTE_ADDR" => "2001:db8:1:2::1" }, source: "https://ada.example/notes/#{sent}")
      end
      notify({ "REMOTE_ADDR" => "2001:db8:1:3::1" }, source: "https://ada.example/notes/other")
    end

    it "goes through, since the first network spent only its own allowance" do
      expect(last_response.status).to eq(202)
    end
  end

  describe "a run of receipts from many addresses past the total limit" do
    let(:limit) { 3 }

    before do
      settings = Hanami.app["settings"]
      allow(settings).to receive(:webmentions).and_return(settings.webmentions.merge(total_throttle_limit: limit))
      (limit + 1).times do |sent|
        notify({ "REMOTE_ADDR" => "203.0.113.#{sent + 1}" }, source: "https://ada.example/notes/#{sent}")
      end
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "queues no more than the total limit" do
      expect(Social::Jobs::VerifyWebmention.jobs).to have(limit).items
    end
  end

  it "answers only to POST" do
    get "/webmention"

    expect(last_response.status).to eq(405)
  end
end
