# frozen_string_literal: true

RSpec.describe Google::Client do
  let(:url) { "https://www.googleapis.com/example/items" }

  def pages(**) = Hanami.app["google.client"].pages(url, rows: "items", account: "aaron@example.com", **)

  def stub_page(token, items, next_token, **fields)
    body = google_health_json({ items:, nextPageToken: next_token, **fields }.compact)
    stub = stub_request(:get, url)
    (token ? stub.with(query: hash_including("pageToken" => token)) : stub).to_return(body)
  end

  before { connect_google }

  it "joins the rows from every page and keeps the last page's fields" do
    stub_page(nil, [1], "two", historyId: "1")
    stub_page("two", [2], nil, historyId: "2")

    expect(pages.values_at("items", "historyId")).to eq([[1, 2], "2"])
  end

  it "stops at the page cap when Google keeps sending tokens" do
    stub_request(:get, /\A#{url}/o)
      .to_return { |request| google_health_json({ items: [1], nextPageToken: "#{request.uri.query}+" }) }

    expect(pages.fetch("items").size).to eq(Google::Paging::MAX_PAGES)
  end

  it "stops when Google sends the same token again" do
    stub_page(nil, [1], "loop")
    stub_page("loop", [2], "loop")

    expect(pages.fetch("items")).to eq([1, 2])
  end

  it "sends the token under the name the API takes" do
    stub_page(nil, [1], "two")
    stub_request(:get, "#{url}?page_token=two").to_return(google_health_json({ items: [2] }))

    expect(pages(token_param: :page_token).fetch("items")).to eq([1, 2])
  end
end
