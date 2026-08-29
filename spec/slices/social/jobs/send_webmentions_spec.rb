# frozen_string_literal: true

RSpec.describe Social::Jobs::SendWebmentions do
  subject(:job) { described_class.new }

  let(:endpoint) { "https://ada.example/webmention" }
  let(:post_repo) { Posts::Slice["repos.post_repo"] }
  let(:source) { "https://aaronmallen.me/writing/hello" }
  let(:target) { "https://ada.example/notes/1" }

  def body_linking(*urls) = urls.map { "See [a note](#{it})." }.join("\n\n")

  def other = "https://bob.example/post"

  def other_endpoint = "https://bob.example/webmention"

  def post_with(*urls, **attrs) = create(:post, :published, slug: "hello", body: body_linking(*urls), **attrs)

  def send_for(post) = job.perform(post.id)

  def send_retrying(post)
    send_for(post)
  rescue described_class::EndpointUnreachable
    nil
  end

  def stub_endpoint(url, status: 202) = stub_request(:post, url).to_return(status:)

  def stub_markup(url, body, headers: {}) = stub_request(:get, url).to_return(headers:, body:)

  def stub_page(url, endpoint: nil, status: 200)
    headers = endpoint ? { "Link" => %(<#{endpoint}>; rel="webmention") } : {}
    stub_request(:get, url).to_return(status:, headers:, body: "<p>a note</p>")
  end

  def stub_target(url, endpoint, status: 202)
    stub_page(url, endpoint:)
    stub_endpoint(endpoint, status:)
  end

  def targets_of(post) = post_repo.by_id(post.id).webmention_targets.to_a

  def update_settings(**) = Social::Slice["repos.webmention_repo"].update_settings(**)

  before { resolves_publicly("ada.example", "bob.example") }

  describe "a published post linking to a page with an endpoint" do
    before { stub_target(target, endpoint) }

    it "sends the post and the linked page to the endpoint as a form" do
      send_for(post_with(target))

      expect(a_request(:post, endpoint).with(body: { source:, target: })).to have_been_made
    end

    it "names the site and the job in the user agent and asks for HTML" do
      send_for(post_with(target))

      expect(a_request(:get, target).with(headers: {
                                            "User-Agent" => "aaronmallen.me webmention (+https://aaronmallen.me)",
                                            "Accept" => "text/html, text/*;q=0.9, */*;q=0.8",
                                          })).to have_been_made
    end

    it "sends to every linked page that advertises an endpoint" do
      stub_target(other, other_endpoint)
      send_for(post_with(target, other))

      expect([a_request(:post, endpoint), a_request(:post, other_endpoint)]).to all(have_been_made)
    end

    it "remembers where it sent" do
      post = post_with(target)
      send_for(post)

      expect(targets_of(post)).to eq([target])
    end
  end

  describe "a page with no endpoint" do
    it "still remembers the link" do
      stub_page(target)
      post = post_with(target)
      send_for(post)

      expect(targets_of(post)).to eq([target])
    end

    {
      "can't be read" => ->(url) { stub_request(:get, url).to_timeout },
      "is gone" => ->(url) { stub_request(:get, url).to_return(status: 404) },
      "the resolver can't answer for" => ->(url) { unresolvable(URI(url).host) },
      "sits on a private address" => ->(url) { resolves(URI(url).host, "10.1.2.3") },
    }.each do |what, stub|
      it "skips a page that #{what}" do
        instance_exec(target, &stub)
        post = post_with(target)
        send_for(post)

        expect(targets_of(post)).to eq([target])
      end
    end
  end

  describe "the links it finds in the post" do
    def post_writing(body) = create(:post, :published, slug: "hello", body:)

    it "names a link only once" do
      stub_target(target, endpoint)
      post = post_with(target, target)
      send_for(post)

      expect(targets_of(post)).to eq([target])
    end

    it "drops the fragment from an outside link", :aggregate_failures do
      stub_target(target, endpoint)
      post = post_with("#{target}#part")
      send_for(post)

      expect(targets_of(post)).to eq([target])
      expect(a_request(:post, endpoint).with(body: { source:, target: })).to have_been_made
    end

    {
      "a relative link, which resolves against the post" => "[me](/about)",
      "a link back to this site" => "[other](https://aaronmallen.me/writing/other)",
      "this site under a different case" => "[me](https://AaronMallen.me/about)",
      "a mail link" => "[write](mailto:hello@aaronmallen.me)",
      "a link to a fragment" => "[notes](#notes)",
      "a link that isn't a URL" => "[broken](http://ada.example:port/)",
      "a post without links" => "no links here",
    }.each do |what, body|
      it "sends nothing for #{what}", :aggregate_failures do
        post = post_writing(body)
        send_for(post)

        expect(targets_of(post)).to be_empty
        expect(a_request(:any, /./)).not_to have_been_made
      end
    end
  end

  describe "how it finds the endpoint" do
    def advertised_by(url = target, **page)
      stub_markup(url, page.fetch(:body, ""), headers: page.fetch(:headers, {}))
      stub_request(:post, /ada\.example/).to_return(status: 202)
      send_for(post_with(target))
    end

    def link_header(value) = { headers: { "Link" => value } }

    def markup = "https://ada.example/markup"

    {
      "an unquoted rel" => "<https://ada.example/webmention>; rel=webmention",
      "a rel that lists webmention among others" => %(<https://ada.example/webmention>; rel="me webmention"),
      "a relative endpoint" => %(</webmention>; rel="webmention"),
      "a header with links for other rels first" =>
        %(<https://ada.example/feed>; rel="alternate", <https://ada.example/webmention>; rel="webmention"),
    }.each do |what, header|
      it "takes the endpoint from #{what} in the Link header" do
        advertised_by(**link_header(header))

        expect(a_request(:post, endpoint).with(body: { source:, target: })).to have_been_made
      end
    end

    it "prefers the header over the markup", :aggregate_failures do
      advertised_by(body: %(<link rel="webmention" href="#{markup}">),
                    **link_header(%(<#{endpoint}>; rel="webmention")))

      expect(a_request(:post, endpoint)).to have_been_made
      expect(a_request(:post, markup)).not_to have_been_made
    end

    it "ignores a rel that only contains the word" do
      advertised_by(**link_header(%(<#{endpoint}>; rel="webmentions")))

      expect(a_request(:post, endpoint)).not_to have_been_made
    end

    it "ignores a link in the header with no rel" do
      advertised_by(**link_header("<#{endpoint}>"))

      expect(a_request(:post, endpoint)).not_to have_been_made
    end

    {
      "a link tag" => %(<link rel="webmention" href="https://ada.example/webmention">),
      "an anchor" => %(<a rel="webmention" href="https://ada.example/webmention">wm</a>),
      "the first of several the page advertises" =>
        %(<link rel="webmention" href="/webmention"><a rel="webmention" href="/second">wm</a>),
    }.each do |what, body|
      it "takes the endpoint from #{what} in the markup", :aggregate_failures do
        advertised_by(body:)

        expect(a_request(:post, endpoint).with(body: { source:, target: })).to have_been_made
        expect(a_request(:post, "https://ada.example/second")).not_to have_been_made
      end
    end

    it "resolves a relative endpoint against where the page was read" do
      stub_request(:get, target).to_return(status: 301, headers: { "Location" => "https://ada.example/notes/" })
      advertised_by("https://ada.example/notes/", body: %(<link rel="webmention" href="wm">))

      expect(a_request(:post, "https://ada.example/notes/wm")).to have_been_made
    end

    it "reads an empty href as the page itself" do
      advertised_by(body: %(<link rel="webmention" href="">))

      expect(a_request(:post, target).with(body: { source:, target: })).to have_been_made
    end

    {
      "a page that advertises no endpoint" => "<p>hello</p>",
      "an endpoint that isn't a URL" => %(<link rel="webmention" href="http://exa mple.com/">),
      "a page with an unrelated rel" => %(<link rel="pingback" href="https://ada.example/pingback">),
    }.each do |what, body|
      it "sends nothing for #{what}" do
        advertised_by(body:)

        expect(a_request(:post, /./)).not_to have_been_made
      end
    end
  end

  describe "a post edited since its last send" do
    before do
      stub_target(target, endpoint)
      stub_target(other, other_endpoint)
    end

    it "sends to the links it still has and to a link removed since the last send" do
      send_for(post_with(target, webmention_targets: [other]))

      expect([a_request(:post, endpoint), a_request(:post, other_endpoint)]).to all(have_been_made)
    end

    it "forgets a link once its page has been told" do
      post = post_with(target, webmention_targets: [other])
      send_for(post)

      expect(targets_of(post)).to eq([target])
    end

    it "sends to a page only once when it is both linked and remembered" do
      send_for(post_with(target, webmention_targets: [target]))

      expect(a_request(:post, endpoint)).to have_been_made.once
    end
  end

  describe "an endpoint that refuses the send" do
    it "raises so Sidekiq tries again" do
      stub_target(target, endpoint, status: 500)

      expect { send_for(post_with(target)) }.to raise_error(described_class::EndpointUnreachable)
    end

    it "raises when the endpoint can't be reached" do
      stub_page(target, endpoint:)
      stub_request(:post, endpoint).to_timeout

      expect { send_for(post_with(target)) }.to raise_error(described_class::EndpointUnreachable)
    end

    it "raises when the endpoint sits on a private address", :aggregate_failures do
      stub_page(target, endpoint: "http://127.0.0.1/webmention")

      expect { send_for(post_with(target)) }.to raise_error(described_class::EndpointUnreachable)
      expect(a_request(:post, "http://127.0.0.1/webmention")).not_to have_been_made
    end

    it "remembers nothing, so the next try sends again" do
      stub_target(target, endpoint, status: 500)
      post = post_with(target)
      send_retrying(post)

      expect(targets_of(post)).to be_empty
    end
  end

  describe "posts and settings that send nothing" do
    before { stub_target(target, endpoint) }

    it "sends nothing with the setting off" do
      update_settings(send_on_publish: false)
      send_for(post_with(target))

      expect(a_request(:any, /./)).not_to have_been_made
    end

    {
      "a draft" => :draft,
      "a scheduled post" => :scheduled,
    }.each do |what, trait|
      it "sends nothing for #{what}" do
        send_for(create(:post, trait, body: body_linking(target)))

        expect(a_request(:any, /./)).not_to have_been_made
      end
    end

    it "finishes quietly for a post that doesn't exist" do
      expect { job.perform(0) }.not_to raise_error
    end
  end
end
