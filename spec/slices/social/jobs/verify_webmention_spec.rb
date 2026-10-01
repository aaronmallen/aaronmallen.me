# frozen_string_literal: true

require "socket"

RSpec.describe Social::Jobs::VerifyWebmention do
  subject(:job) { described_class.new }

  let(:post) { create(:post, :published, slug: "hello") }
  let(:source) { "https://ada.example/notes/1" }
  let(:target) { "https://aaronmallen.me/writing/hello" }

  before { resolves_publicly("ada.example", "brid.gy", "evil.example", "grace.example", "mirror.example") }

  def entry(body: %(<a href="#{target}">read</a>), author: nil)
    card = author && %(<a class="p-author h-card" href="#{author}">Ada</a>)

    %(<div class="h-entry">#{card}#{body}</div>)
  end

  def family = "👩‍👩‍👧‍👦"

  def interface(address, netmask = nil)
    instance_double(Socket::Ifaddr, addr: address && Addrinfo.ip(address), netmask: netmask && Addrinfo.ip(netmask))
  end

  def link = %(<a href="#{target}">read</a>)

  def long_name_entry
    %(<div class="h-entry"><a class="p-author h-card" href="https://ada.example/about">#{'Ada' * 300}</a>
      <a href="#{target}">read</a></div>)
  end

  def stored(url = source) = webmentions.for_post(post.id).from_source(url).one

  def stub_source(html, url: source, **response) = stub_request(:get, url).to_return(body: html, **response)

  def verify(source: self.source, post_id: post.id) = job.perform(source, target, post_id)

  def verify_page(html, **response)
    stub_source(html, **response)
    verify
  end

  def verify_retrying
    verify
  rescue described_class::SourceUnreachable
    nil
  end

  def webmention_repo = Social::Slice["repos.webmention_repo"]

  def webmentions = Social::Slice["relations.webmentions"].with(auto_struct: true, struct_namespace: Social::Structs)

  describe "a source that links to the target" do
    it "stores a pending mention of the post, received now" do
      verify_page(entry)

      expect(stored).to have_attributes(status: "pending", source_url: source, post_id: post.id,
                                        received_at: be_within(60).of(Time.now))
    end

    it "stores the author, the type and the excerpt" do
      verify_page(entry(body: %(<a class="u-in-reply-to" href="#{target}">re</a><p class="e-content">Nice</p>),
                        author: "https://ada.example/about"))

      expect(stored).to have_attributes(author_name: "Ada", author_url: "https://ada.example/about",
                                        type: "reply", excerpt: "Nice")
    end

    it "stores the author URL normalized, and takes the author domain from it" do
      verify_page(entry(author: "https://Ada.Example/about/#bio"))

      expect(stored).to have_attributes(author_url: "https://ada.example/about", author_domain: "ada.example")
    end

    it "resolves relative markup against where a redirect landed" do
      stub_request(:get, source).to_return(status: 301, headers: { "Location" => "https://mirror.example/notes/one" })
      stub_source(entry(author: "/about"), url: "https://mirror.example/notes/one")
      verify

      expect(stored.author_url).to eq("https://mirror.example/about")
    end

    it "follows a relative redirect and stores the mention under the source it was sent" do
      stub_request(:get, source).to_return(status: 302, headers: { "Location" => "/notes/one" })
      stub_source(entry, url: "https://ada.example/notes/one")
      verify

      expect(stored.source_url).to eq(source)
    end
  end

  describe "the link to the target" do
    {
      "a relative link" => %(<a href="/writing/hello">read</a>),
      "a link with a fragment" => %(<a href="https://aaronmallen.me/writing/hello#intro">read</a>),
      "a link with a trailing slash" => %(<a href="https://aaronmallen.me/writing/hello/">read</a>),
      "a link tag in the head" => %(<link rel="related" href="https://aaronmallen.me/writing/hello">),
      "a link under another case" => %(<a href="https://AaronMallen.me/writing/hello">read</a>),
    }.each do |what, html|
      it "finds #{what}" do
        stub_request(:get, "https://aaronmallen.me/notes/1").to_return(body: html)
        resolves_publicly("aaronmallen.me")
        verify(source: "https://aaronmallen.me/notes/1")

        expect(stored("https://aaronmallen.me/notes/1")).not_to be_nil
      end
    end

    {
      "links somewhere else" => %(<a href="https://aaronmallen.me/writing/other">read</a>),
      "only names the target in text" => "<p>https://aaronmallen.me/writing/hello</p>",
      "is empty" => "",
      "holds an href that isn't a URL" => %(<a href="http://[bad">read</a>),
      "holds a mail link" => %(<a href="mailto:ada@example.com">write</a>),
      "holds a link with an empty href" => %(<a href="">read</a>),
    }.each do |what, html|
      it "stores nothing when the page #{what}" do
        verify_page(html)

        expect(stored).to be_nil
      end
    end

    it "removes the mention it stored before once the link is gone" do
      verify_page(entry)
      verify_page("<p>the link is gone</p>")

      expect(stored).to be_nil
    end

    it "reads no further than the first megabyte" do
      verify_page("#{'x' * Social::Webmentions::Client::MAX_BODY}#{entry}")

      expect(stored).to be_nil
    end

    it "reads a page the limit cuts through the middle of a character" do
      verify_page("#{entry}#{'☃' * 400_000}")

      expect(stored).not_to be_nil
    end
  end

  describe "the type" do
    hello = "https://aaronmallen.me/writing/hello"
    link = %(<a href="#{hello}">read</a>)

    {
      "a reply" => [%(<a class="u-in-reply-to" href="#{hello}">re</a>), "reply"],
      "a like" => [%(<a class="u-like-of" href="#{hello}">x</a>), "like"],
      "a repost" => [%(<a class="u-repost-of" href="#{hello}">x</a>), "repost"],
      "a property on a data element" => [%(<data class="u-like-of" value="#{hello}"></data>#{link}), "like"],
      "a property on another page" =>
        [%(<a class="u-like-of" href="https://aaronmallen.me/writing/other">x</a>#{link}), "mention"],
      "a plain link" => [link, "mention"],
    }.each do |what, (body, type)|
      it "reads #{what} as a #{type}" do
        verify_page(entry(body:))

        expect(stored.type).to eq(type)
      end
    end
  end

  describe "the author" do
    def name_card(name) = %(<div class="p-author h-card"><span class="p-name">#{name}</span></div>#{link})

    it "reads a nested p-name and u-url" do
      verify_page(entry(body: %(<div class="p-author h-card"><a class="u-url" href="https://ada.example/about">
        <span class="p-name">Ada</span></a></div>#{link})))

      expect(stored).to have_attributes(author_name: "Ada", author_url: "https://ada.example/about")
    end

    it "reads the real author from a Bridgy page, not the sender" do
      bridgy = "https://brid.gy/like/mastodon/1"
      card = %(<div class="p-author h-card"><a class="u-url" href="https://mastodon.social/@ada">Ada</a></div>)
      stub_source(entry(body: "#{card}#{link}"), url: bridgy)
      verify(source: bridgy)

      expect(stored(bridgy)).to have_attributes(author_name: "Ada", author_url: "https://mastodon.social/@ada")
    end

    it "falls back to a rel=author link" do
      verify_page(%(<a rel="author" href="https://ada.example/about">Ada</a>#{link}))

      expect(stored).to have_attributes(author_name: "Ada", author_url: "https://ada.example/about")
    end

    it "falls back to the source site with no author markup" do
      verify_page(link)

      expect(stored).to have_attributes(author_name: nil, author_url: "https://ada.example/")
    end

    it "falls back to the source site when the card carries no URL" do
      verify_page(entry(body: %(<span class="p-author h-card">Ada</span>#{link})))

      expect(stored).to have_attributes(author_name: "Ada", author_url: "https://ada.example/")
    end

    it "keeps no name when the card holds only whitespace" do
      verify_page(entry(body: %(<a class="p-author h-card" href="https://ada.example/about">  </a>#{link})))

      expect(stored).to have_attributes(author_name: nil, author_url: "https://ada.example/about")
    end

    it "squeezes the whitespace out of the name" do
      verify_page(entry(body: name_card("  Ada\n  Lovelace ")))

      expect(stored.author_name).to eq("Ada Lovelace")
    end

    it "cuts a long name down to the limit and marks it" do
      verify_page(long_name_entry)

      expect(stored.author_name).to have_attributes(length: Social::Webmentions::Source::EXCERPT_LIMIT)
        .and(end_with("…"))
    end

    it "keeps a family emoji whole where it cuts the name" do
      verify_page(entry(body: name_card("#{'a' * 498}#{family}xy")))

      expect(stored.author_name).to eq("#{'a' * 498}#{family}…")
    end
  end

  describe "the excerpt" do
    {
      "reads the e-content of the entry" => [%(<div class="e-content">A <b>fine</b> post</div>), "A fine post"],
      "prefers the summary over the content" =>
        [%(<p class="p-summary">Short</p><div class="e-content">Long</div>), "Short"],
      "keeps none with no content markup" => ["", nil],
      "keeps none when the content is only whitespace" => [%(<div class="e-content">   </div>), nil],
    }.each do |what, (body, excerpt)|
      it what do
        verify_page(entry(body: "#{body}#{link}"))

        expect(stored.excerpt).to eq(excerpt)
      end
    end

    it "reads content outside an h-entry" do
      verify_page(%(<div class="e-content">Loose</div>#{link}))

      expect(stored.excerpt).to eq("Loose")
    end

    it "keeps none for a like" do
      verify_page(entry(body: %(<a class="u-like-of" href="#{target}">x</a><div class="e-content">liked</div>)))

      expect(stored.excerpt).to be_nil
    end

    it "cuts a long excerpt down to the limit and marks it" do
      verify_page(entry(body: %(<div class="e-content">#{'word ' * 300}</div>#{link})))

      expect(stored.excerpt).to have_attributes(length: be <= Social::Webmentions::Source::EXCERPT_LIMIT)
        .and(end_with("…"))
    end

    it "keeps a family emoji whole where it cuts the excerpt" do
      verify_page(entry(body: %(<div class="e-content">#{'a' * 498}#{family}xy</div>#{link})))

      expect(stored.excerpt).to eq("#{'a' * 498}#{family}…")
    end
  end

  describe "a source that is gone" do
    [404, 410].each do |status|
      it "removes the mention it stored before a #{status}" do
        verify_page(entry)
        verify_page("gone", status:)

        expect(stored).to be_nil
      end
    end
  end

  describe "a source that can't be read" do
    {
      "breaks" => ->(url) { stub_request(:get, url).to_return(status: 500) },
      "times out" => ->(url) { stub_request(:get, url).to_timeout },
      "refuses the connection" => ->(url) { stub_request(:get, url).to_raise(Faraday::ConnectionFailed) },
      "names a host the resolver can't answer for" => ->(url) { unresolvable(URI(url).host) },
      "names a host the resolver answers for with nothing" => ->(url) { resolves(URI(url).host) },
      "redirects without naming where" =>
        ->(url) { stub_request(:get, url).to_return(status: 302, headers: { "Location" => "" }) },
      "redirects in a loop" => lambda { |url|
        stub_request(:get, url).to_return(status: 302, headers: { "Location" => url })
      },
      "redirects to somewhere that isn't a URL" =>
        ->(url) { stub_request(:get, url).to_return(status: 302, headers: { "Location" => "http://[" }) },
      "declares a body over the limit" => lambda { |url|
        stub_request(:get, url).to_return(headers: { "Content-Length" => Social::Webmentions::Client::MAX_BODY + 1 },
                                          body: "x")
      },
    }.each do |what, stub|
      it "raises so Sidekiq tries again when the source #{what}" do
        instance_exec(source, &stub)

        expect { verify }.to raise_error(described_class::SourceUnreachable)
      end
    end

    it "keeps the mention it stored before" do
      verify_page(entry)
      stub_request(:get, source).to_timeout
      verify_retrying

      expect(stored).not_to be_nil
    end
  end

  describe "a source the client refuses to reach" do
    unparsable = "http://exa mple.com"
    kept_inside = %w[
      http://127.0.0.1/admin http://10.0.0.5/admin http://192.168.1.1/admin http://172.16.0.1/admin
      http://169.254.169.254/latest/meta-data http://[::1]/admin http://[fd00::1]/admin http://0.0.0.0/admin
      http://100.64.0.1/admin http://[64:ff9b::7f00:1]/admin http://[2002:7f00:1::1]/admin
      http://[::ffff:127.0.0.1]/admin http://localhost/admin http://box.local/admin http://metadata.internal/admin
      http://2130706433/admin http://0x7f000001/admin https:///notes/1 ftp://ada.example/note http://ada.example:6379/
    ]

    [*kept_inside, unparsable].each do |refused|
      it "finishes quietly and sends nothing to #{refused}", :aggregate_failures do
        expect { verify(source: refused) }.not_to raise_error
        expect(a_request(:any, /./)).not_to have_been_made
      end
    end

    {
      "a name that resolves to a private address" => ["10.1.2.3"],
      "a name with one private address among public ones" => [Resolver::PUBLIC, "10.1.2.3"],
      "a scoped link-local address" => ["fe80::1%1"],
    }.each do |what, addresses|
      it "sends nothing to #{what}" do
        resolves("ada.example", *addresses)
        verify

        expect(a_request(:get, source)).not_to have_been_made
      end
    end

    it "sends nothing to an address it cannot read as an IP" do
      resolves_raw("ada.example", "not-an-ip")
      verify

      expect(a_request(:get, source)).not_to have_been_made
    end

    it "follows no redirect to a private address" do
      stub_request(:get, source).to_return(status: 302, headers: { "Location" => "http://127.0.0.1/admin" })
      verify

      expect(a_request(:get, "http://127.0.0.1/admin")).not_to have_been_made
    end

    it "follows no redirect to a port that is not a web port" do
      stub_request(:get, source).to_return(status: 302, headers: { "Location" => "http://ada.example:6379/" })
      verify

      expect(a_request(:get, "http://ada.example:6379/")).not_to have_been_made
    end

    it "reads a source on port 80 named outright" do
      stub_source(entry, url: "http://ada.example/notes/1")
      verify(source: "http://ada.example:80/notes/1")

      expect(stored("http://ada.example:80/notes/1")).not_to be_nil
    end

    it "reads a source on port 443 named outright" do
      stub_source(entry)
      verify(source: "https://ada.example:443/notes/1")

      expect(stored("https://ada.example:443/notes/1")).not_to be_nil
    end

    it "keeps the mention it stored before" do
      verify_page(entry)
      resolves("ada.example", "10.1.2.3")
      verify

      expect(stored).not_to be_nil
    end
  end

  describe "the machine's own network" do
    def neighbour = "https://nas.example/notes/1"

    before do
      allow(Socket).to receive(:getifaddrs).and_return(
        [
          interface("2600:1700:abcd:1::10", "ffff:ffff:ffff:ffff::"),
          interface("203.0.113.10", "255.255.255.0"),
          interface("fe80::1%1", "ffff:ffff:ffff:ffff::"),
          interface("198.51.100.7"),
          interface(nil),
        ],
      )
    end

    {
      "the machine's own IPv6 address" => "2600:1700:abcd:1::10",
      "an on-link global IPv6 address" => "2600:1700:abcd:1::20",
      "an on-link IPv4 address" => "203.0.113.20",
      "the address of an interface with no netmask" => "198.51.100.7",
    }.each do |name, address|
      it "sends nothing to #{name}" do
        resolves("nas.example", address)
        verify(source: neighbour)

        expect(a_request(:get, neighbour)).not_to have_been_made
      end
    end

    {
      "outside the prefixes the machine carries" => "2600:1700:abcd:2::20",
      "beside one only the machine holds" => "198.51.100.8",
    }.each do |name, address|
      it "reads an address #{name}" do
        resolves("nas.example", address)
        stub_source(entry, url: neighbour)
        verify(source: neighbour)

        expect(stored(neighbour)).not_to be_nil
      end
    end
  end

  describe "the time it takes" do
    def answer(socket)
      socket.gets("\r\n\r\n")
      yield socket
    rescue IOError, SystemCallError
      nil
    ensure
      socket.close
    end

    def budget = 0.5

    before do
      stub_const("Social::Webmentions::Client::BLOCKED_RANGES", [])
      stub_const("Social::Webmentions::Client::BUDGET", budget)
      stub_const("Social::Webmentions::Client::PORTS", 1..65_535)
      allow(Socket).to receive(:getifaddrs).and_return([])
    end

    after do
      servers.each do |server, thread|
        thread.kill.join
        server.close
      end
    end

    def elapsed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
    rescue described_class::SourceUnreachable
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    def serve(&)
      server = TCPServer.new("127.0.0.1", 0)
      servers << [server, Thread.new { loop { answer(server.accept, &) } }]
      "http://127.0.0.1:#{server.addr[1]}/notes/1"
    end

    def servers = @servers ||= []

    def trickle(opening)
      serve do |socket|
        socket.write(opening)

        loop do
          socket.write("x")
          sleep(budget / 10)
        end
      end
    end

    it "gives up within the budget on a body that trickles in" do
      expect(elapsed { verify(source: trickle("HTTP/1.1 200 OK\r\n\r\n")) }).to be < budget * 2
    end

    it "gives up within the budget on headers that trickle in" do
      expect(elapsed { verify(source: trickle("HTTP/1.1 200 OK\r\nX-Slow: ")) }).to be < budget * 2
    end

    it "counts every redirect against the one budget" do
      slow = serve do |socket|
        sleep(budget * 0.4)
        socket.write("HTTP/1.1 302 Found\r\nLocation: /notes/1\r\nContent-Length: 0\r\n\r\n")
      end

      expect { verify(source: slow) }.to raise_error(described_class::SourceUnreachable)
    end
  end

  describe "a second send from the same source" do
    def resend(text) = verify_page(entry(body: %(<a href="#{target}">read</a><p class="e-content">#{text}</p>)))

    before { resend("First") }

    it "updates the one mention rather than storing another", :aggregate_failures do
      resend("Second")

      expect(stored.excerpt).to eq("Second")
      expect(webmentions.count).to eq(1)
    end

    it "leaves a mention already marked as spam alone" do
      webmention_repo.mark_spam(stored.id)
      resend("Second")

      expect(stored.status).to eq("spam")
    end

    it "leaves a mention already ignored alone when the text changed" do
      webmention_repo.ignore(stored.id)
      resend("Second")

      expect(stored).to have_attributes(status: "ignored", excerpt: "Second")
    end

    it "leaves a mention already approved alone when it says the same thing" do
      webmention_repo.approve(stored.id)
      resend("First")

      expect(stored.status).to eq("approved")
    end

    it "leaves a mention already approved alone when an overlong name comes back the same" do
      verify_page(long_name_entry)
      webmention_repo.approve(stored.id)
      verify

      expect(stored.status).to eq("approved")
    end

    it "sends a mention already approved back to pending when the text changed" do
      webmention_repo.approve(stored.id)
      resend("Second")

      expect(stored).to have_attributes(status: "pending", excerpt: "Second")
    end

    it "sends a mention already approved back to pending when the author changed" do
      webmention_repo.approve(stored.id)
      verify_page(entry(body: %(<a href="#{target}">read</a><p class="e-content">First</p>),
                        author: "https://ada.example/about"))

      expect(stored.status).to eq("pending")
    end
  end

  describe "auto-approve" do
    before do
      create(:webmention, :approved, post: create(:post, :published), author_url: "https://ada.example/about")
    end

    {
      "an author I approved before" => "https://ada.example/about",
      "that author under another case" => "https://ADA.Example/about",
      "that author with a trailing slash" => "https://ada.example/about/",
    }.each do |what, author|
      it "approves a mention from #{what}" do
        verify_page(entry(author:))

        expect(stored.status).to eq("approved")
      end
    end

    {
      "a new host" => ["https://grace.example/notes/1", "https://grace.example/about"],
      "another host claiming an author on a known host" => ["https://evil.example/note", "https://ada.example/about"],
      "a known host claiming an author elsewhere" => ["https://ada.example/notes/1", "https://grace.example/about"],
      "another author on a known host" => ["https://ada.example/notes/2", "https://ada.example/~grace"],
      "a page naming no author when only a page on its host is known" => ["https://ada.example/notes/1", nil],
      "a Bridgy page whose author's site is unknown" =>
        ["https://brid.gy/like/mastodon/1", "https://mastodon.social/@ada"],
    }.each do |what, (from, author)|
      it "leaves a mention from #{what} waiting" do
        stub_source(entry(author:), url: from)
        verify(source: from)

        expect(stored(from).status).to eq("pending")
      end
    end

    it "approves a mention whose page names no author once that site itself is known" do
      create(:webmention, :approved, post: create(:post, :published), author_url: "https://ada.example/")
      verify_page(entry)

      expect(stored.status).to eq("approved")
    end

    it "leaves a known author waiting once that author has been marked spam as well" do
      create(:webmention, :spam, post: create(:post, :published), author_url: "https://ada.example/about")
      verify_page(entry(author: "https://ada.example/about"))

      expect(stored.status).to eq("pending")
    end

    it "leaves an author waiting whose only mention has been ignored" do
      create(:webmention, :ignored, post: create(:post, :published), author_url: "https://grace.example/about")
      stub_source(entry(author: "https://grace.example/about"), url: "https://grace.example/notes/1")
      verify(source: "https://grace.example/notes/1")

      expect(stored("https://grace.example/notes/1").status).to eq("pending")
    end

    it "still approves a known author once one of their mentions has been ignored" do
      create(:webmention, :ignored, post: create(:post, :published), author_url: "https://ada.example/about")
      verify_page(entry(author: "https://ada.example/about"))

      expect(stored.status).to eq("approved")
    end

    it "leaves a known author waiting once auto-approve is off" do
      webmention_repo.update_settings(auto_approve_known_authors: false)
      verify_page(entry(author: "https://ada.example/about"))

      expect(stored.status).to eq("pending")
    end
  end

  describe "a target that stopped being eligible" do
    {
      "went back to draft" => { status: "draft", published_at: nil },
      "turned webmentions off" => { webmentions_enabled: false },
    }.each do |what, change|
      it "fetches nothing once the post #{what}", :aggregate_failures do
        Posts::Slice["repos.post_repo"].update(post.id, **change)
        stub_source(entry)
        verify

        expect(a_request(:get, source)).not_to have_been_made
        expect(stored).to be_nil
      end
    end

    it "fetches nothing for a post that is gone" do
      verify(post_id: 0)

      expect(a_request(:get, source)).not_to have_been_made
    end
  end

  describe "the settings" do
    it "fetches nothing once receiving is off" do
      webmention_repo.update_settings(receive: false)
      verify

      expect(a_request(:get, source)).not_to have_been_made
    end

    it "fetches nothing from Bridgy once Bridgy is off" do
      webmention_repo.update_settings(accept_bridgy: false)
      verify(source: "https://brid.gy/like/mastodon/1")

      expect(a_request(:get, "https://brid.gy/like/mastodon/1")).not_to have_been_made
    end

    it "still reads another source once Bridgy is off" do
      webmention_repo.update_settings(accept_bridgy: false)
      verify_page(entry)

      expect(stored).not_to be_nil
    end
  end
end
