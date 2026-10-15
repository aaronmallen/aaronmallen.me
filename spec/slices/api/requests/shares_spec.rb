# frozen_string_literal: true

require "base64"

RSpec.describe "API shares", type: :request do
  let(:stored) { {} }

  def encoded(text) = Base64.strict_encode64(text)

  def file(text, filename, content_type = nil) = { data: encoded(text), filename:, content_type: }.compact

  def group_files = Shares::Slice["relations.share_group_files"].to_a

  def keep_puts
    stub_request(:put, %r{\A#{share_store_url}/}).to_return do |request|
      stored[File.basename(request.uri.path)] = { body: request.body.b, content_type: request.headers["Content-Type"] }
      { status: 200 }
    end
  end

  def make_group(*files) = Shares::Slice["operations.upload_share_group"].call(files).value!

  def make_share(text, filename, type)
    Shares::Slice["operations.upload_share"].call(share_upload(text, filename, type)).value!
  end

  def shares = Shares::Slice["relations.shares"].to_a

  def status = last_response.status

  before do
    connect_share_store
    keep_puts
  end

  describe "POST /api/v1/shares" do
    let(:answered) { call_api(:post, "/shares", file("hello", "hello.txt", "text/plain")) }

    it "answers 201 with the share and its link" do
      expect([answered, status]).to match([include(
        "id" => shares.first[:id], "url" => "http://shares.localhost/#{answered.fetch('code')}",
        "filename" => "hello.txt", "content_type" => "text/plain", "byte_size" => 5, "download_count" => 0,
        "alt_text" => nil,
      ), 201])
    end

    it "gives the share a 16-letter code" do
      expect(answered.fetch("code")).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]{16}\z/)
    end

    it "stores the file byte for byte" do
      answered

      expect(stored.fetch(shares.first[:key])).to eq(body: "hello", content_type: "text/plain")
    end

    it "calls a file sent with no type an octet stream" do
      expect(call_api(:post, "/shares", file("data", "blob")).fetch("content_type")).to eq("application/octet-stream")
    end

    it "refuses a content type that holds more than one type and stores nothing", :aggregate_failures do
      answered = call_api(:post, "/shares", file("<p>hi</p>", "photo.png", "image/png, text/html"))

      expect([status, answered.fetch("errors")]).to eq([422, { "content_type" => ["is not valid"] }])
      expect(shares).to be_empty
    end

    it "stores the content type in lower case" do
      answered = call_api(:post, "/shares", file("data", "photo.png", "Image/PNG"))

      expect(answered.fetch("content_type")).to eq("image/png")
    end

    it "refuses data that is not base64 and stores nothing", :aggregate_failures do
      answered = call_api(:post, "/shares", { data: "not*base64!", filename: "a.txt" })

      expect([status, answered.fetch("errors")]).to eq([422, { "data" => ["is not base64"] }])
      expect(shares).to be_empty
    end

    it "refuses a blank file name" do
      call_api(:post, "/shares", file("a", " "))

      expect([status, shares]).to eq([422, []])
    end

    it "answers 503 when the store fails and keeps no row", :aggregate_failures do
      stub_request(:put, %r{\A#{share_store_url}/}).to_timeout

      expect(call_api(:post, "/shares", file("a", "a.txt")).fetch("error")).to eq("unavailable")
      expect([status, shares]).to eq([503, []])
    end
  end

  describe "POST /api/v1/share_groups" do
    let(:answered) do
      call_api(:post, "/share_groups", { files: [file("a", "a.txt", "text/plain"), file("%PDF", "b.pdf")] })
    end

    def file_id(filename) = group_files.find { it[:filename] == filename }.fetch(:id)

    def link_of(filename) = "http://shares.localhost/#{answered.fetch('code')}/#{file_id(filename)}"

    it "answers 201 with one link for the group" do
      expect([answered, status]).to match([include(
        "url" => "http://shares.localhost/#{answered.fetch('code')}", "view_count" => 0, "zip_download_count" => 0,
      ), 201])
    end

    it "gives the group a 16-letter code" do
      expect(answered.fetch("code")).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]{16}\z/)
    end

    it "answers with each file and its own link" do
      expect(answered.fetch("files").map { it.values_at("filename", "byte_size", "url") })
        .to contain_exactly(["a.txt", 1, link_of("a.txt")], ["b.pdf", 4, link_of("b.pdf")])
    end

    it "makes a group, not single shares" do
      answered

      expect([group_files.size, shares]).to eq([2, []])
    end

    it "refuses an empty list" do
      call_api(:post, "/share_groups", { files: [] })

      expect([status, group_files]).to eq([422, []])
    end

    it "refuses a file that is not base64 and stores nothing", :aggregate_failures do
      call_api(:post, "/share_groups", { files: [file("a", "a.txt"), { data: "nope!", filename: "b.txt" }] })

      expect(status).to eq(422)
      expect(stored).to be_empty
    end

    it "names the field that fails a check" do
      answered = call_api(:post, "/share_groups", { files: [file("a", " ")] })

      expect([status, answered.fetch("errors")]).to eq([422, { "files" => ["filename is empty"] }])
    end
  end

  describe "GET /api/v1/shares" do
    def filenames(query) = call_api(:get, "/shares", query).fetch("shares").map { it["filename"] }

    before do
      make_share("png", "photo.png", "image/png")
      make_share("text", "notes.txt", "text/plain")
    end

    it "lists shares newest first with their counts" do
      answered = call_api(:get, "/shares")

      expect(answered).to include("count" => 2, "partial" => false)
        .and(include("shares" => [include("filename" => "notes.txt"),
                                  include("filename" => "photo.png", "download_count" => 0)]))
    end

    it "keeps only images under the images filter" do
      expect(filenames(filter: "images")).to eq(["photo.png"])
    end

    it "finds shares by their words" do
      expect(filenames(query: "notes")).to eq(["notes.txt"])
    end

    it "no longer filters by search" do
      expect(filenames(search: "notes")).to eq(["notes.txt", "photo.png"])
    end

    it "pages the list" do
      lower_page_size(:mcp, to: 1)

      expect(call_api(:get, "/shares").slice("count", "partial", "next_page")).to eq(
        "count" => 2, "partial" => true, "next_page" => 2,
      )
    end
  end

  describe "GET /api/v1/shares/{id}" do
    it "reads one share" do
      share = make_share("text", "notes.txt", "text/plain")

      expect(call_api(:get, "/shares/#{share.id}")).to include("id" => share.id, "code" => share.code)
    end

    it "answers 404 for a share that is not there" do
      expect([call_api(:get, "/shares/999").fetch("message"), status]).to eq(["no share has the ID 999", 404])
    end
  end

  describe "GET /api/v1/share_groups" do
    it "lists groups newest first with their files and counts", :aggregate_failures do
      older = make_group(share_upload("a", "a.txt", "text/plain"))
      newer = make_group(share_upload("b", "b.txt", "text/plain"), share_upload("c", "c.txt", "text/plain"))
      answered = call_api(:get, "/share_groups")

      expect(answered.slice("count", "partial")).to eq("count" => 2, "partial" => false)
      expect(answered.fetch("share_groups").map { [it["id"], it["files"].size] }).to eq([[newer.id, 2], [older.id, 1]])
    end

    it "pages the list" do
      lower_page_size(:mcp, to: 1)
      2.times { make_group(share_upload("a", "a.txt", "text/plain")) }

      expect(call_api(:get, "/share_groups").slice("partial", "next_page")).to eq("partial" => true, "next_page" => 2)
    end
  end

  describe "GET /api/v1/share_groups/{id}" do
    it "reads one group with its files and their counts" do
      group = make_group(share_upload("a", "a.txt", "text/plain"))

      expect(call_api(:get, "/share_groups/#{group.id}")).to include(
        "id" => group.id, "code" => group.code,
        "files" => [include("filename" => "a.txt", "download_count" => 0, "alt_text" => nil)],
      )
    end

    it "answers 404 for a group that is not there" do
      expect([call_api(:get, "/share_groups/999").fetch("message"),
              status]).to eq(["no share group has the ID 999", 404])
    end
  end
end
