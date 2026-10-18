# frozen_string_literal: true

RSpec.describe Shares::Jobs::FetchShortLinkTitle do
  let(:destination) { "https://ada.example/talk" }
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination:).value! }

  before { resolves_publicly("ada.example") }

  def fetch(id = link.id) = described_class.new.perform(id)

  def html(head)
    { body: "<html><head>#{head}</head><body>hi</body></html>", headers: { "Content-Type" => "text/html" } }
  end

  def stored = Shares::Slice["repos.short_link_queries"].find(link.id).title

  def title_after(response)
    stub_request(:get, destination).to_return(response)
    fetch
    stored
  end

  it "takes the og:title before the title" do
    head = %(<title>Plain</title><meta property="og:title" content=" Open\n Graph ">)

    expect(title_after(html(head))).to eq("Open Graph")
  end

  it "takes the title when there is no og:title" do
    expect(title_after(html(%(<meta property="og:title" content=" "><title>\n  My   talk \t</title>)))).to eq("My talk")
  end

  it "drops control characters and caps the length", :aggregate_failures do
    title = title_after(html("<title>bad\u0007bell #{'word ' * 100}</title>"))

    expect(title).to start_with("bad bell word")
    expect(title).to end_with("word…")
    expect(title.length).to be <= 200
  end

  it "reads a page whose content type names HTML in capitals with a charset" do
    page = { body: "<title>Loud</title>", headers: { "Content-Type" => "TEXT/HTML; charset=utf-8" } }

    expect(title_after(page)).to eq("Loud")
  end

  {
    "an error status" => { status: 500, body: "<title>Oops</title>", headers: { "Content-Type" => "text/html" } },
    "a page that is not HTML" => { body: "<title>Not a page</title>", headers: { "Content-Type" => "text/plain" } },
    "a page with no title" => { body: "<p>hi</p>", headers: { "Content-Type" => "text/html" } },
  }.each do |name, response|
    it "leaves the title blank for #{name}" do
      expect(title_after(response)).to be_nil
    end
  end

  it "leaves the title blank when the page times out" do
    stub_request(:get, destination).to_timeout
    fetch

    expect(stored).to be_nil
  end

  it "never fetches a private or local address", :aggregate_failures do
    resolves("ada.example", "127.0.0.1")
    fetch

    expect(a_request(:get, destination)).not_to have_been_made
    expect(stored).to be_nil
  end

  it "keeps a title I typed while the fetch ran" do
    title_after(lambda do |_request|
      Shares::Slice["operations.set_short_link_title"].call(link.id, { title: "Mine" })
      html("<title>Fetched</title>")
    end)

    expect(stored).to eq("Mine")
  end

  it "fetches nothing for a titled or missing link", :aggregate_failures do
    Shares::Slice["operations.set_short_link_title"].call(link.id, { title: "Mine" })
    fetch
    fetch(0)

    expect(a_request(:get, destination)).not_to have_been_made
    expect(stored).to eq("Mine")
  end

  it "drops a title from a destination the link no longer points at" do
    expect(title_after(lambda do |_request|
      Shares::Slice["operations.retarget_short_link"].call(link.id, { destination: "https://ada.example/new" })
      html("<title>Old</title>")
    end)).to be_nil
  end
end
