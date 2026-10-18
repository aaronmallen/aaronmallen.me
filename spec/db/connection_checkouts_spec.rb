# frozen_string_literal: true

RSpec.describe "Database connection checkouts", :commits, type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }

  let(:job) do
    stub_const("Spec::QueryingJob", Class.new(Blog::Job) do
      def perform
        posts = Posts::Slice["db.rom"].relations[:posts]
        3.times { posts.count }
      end
    end)
  end

  def count_validations = allow(db).to receive(:valid_connection?).and_call_original

  it "validates one connection for a whole request", type: :request do
    create(:post, :published, slug: "hello")
    count_validations
    get "/writing/hello"

    expect(db).to have_received(:valid_connection?).once
  end

  context "when Puma writes the timing row after the reply", type: :request do
    def rows = Performance::Slice["db.rom"].relations[:performance_requests].to_a

    before do
      serve_like_puma
      count_validations
      get "/"
    end

    after { reply }

    it "keeps the request's connection until the response finishes" do
      db.get(1)

      expect(db).to have_received(:valid_connection?).once
    end

    it "validates one connection for the request and its row" do
      reply

      expect(db).to have_received(:valid_connection?).once
    end

    it "writes the row" do
      reply

      expect(rows).to contain_exactly(include(route: "/", verb: "GET"))
    end

    it "gives the connection back once the response finishes" do
      reply
      db.get(1)

      expect(db).to have_received(:valid_connection?).twice
    end
  end

  context "when the owner opens the admin event stream", type: :request do
    let(:hub) do
      url = Blog::Providers::DBProvider.database_url(Hanami.app["settings"].database)
      Admin::Live::Hub.new(url:, reporter: instance_double(Honeybadger::Agent, notify: nil))
    end
    let(:sockets) { UNIXSocket.pair }

    before do
      replace_component("live.hub", hub)
      serve_like_puma
      sign_in_to_admin
      stream = sockets.first
      get "/admin/events", {}, "HTTP_ACCEPT" => "text/event-stream", Rack::RACK_HIJACK => -> { stream }
      reply
      count_validations
    end

    after do
      hub.stop
      sockets.each(&:close)
    end

    it "keeps the stream open" do
      expect(sockets.last.read_nonblock(1024)).to start_with("HTTP/1.1 200 OK")
    end

    it "gives the connection back once the handler returns" do
      db.get(1)

      expect(db).to have_received(:valid_connection?).once
    end
  end

  context "when a Sidekiq job runs" do
    before { Sidekiq::Testing.server_middleware { it.add Blog::JobConnection, -> { db } } }

    after { Sidekiq::Testing.server_middleware { it.remove Blog::JobConnection } }

    it "validates one connection for the whole job" do
      count_validations
      job.perform_async
      job.drain

      expect(db).to have_received(:valid_connection?).once
    end
  end
end
