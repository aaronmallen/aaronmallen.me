# frozen_string_literal: true

RSpec.describe "The web statement timeout", type: :request do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }

  def statement_timeout(connection = db) = connection.get(Sequel.function(:current_setting, "statement_timeout"))

  it "limits a request's queries to 15 seconds by default" do
    post_queries = instance_double(Posts::Repos::PostQueries)
    allow(post_queries).to receive(:published_page) { raise statement_timeout }
    replace_component("posts.repos.post_queries", post_queries)

    expect { get "/writing" }.to raise_error(RuntimeError, "15s")
  end

  it "cancels a request's query that runs past the limit" do
    allow(Hanami.app["settings"]).to receive(:web_statement_timeout).and_return(0.05)
    post_queries = instance_double(Posts::Repos::PostQueries)
    allow(post_queries).to receive(:published_page) { db.get(Sequel.function(:pg_sleep, 1)) }
    replace_component("posts.repos.post_queries", post_queries)

    expect { get "/writing" }.to raise_error(Sequel::DatabaseError, /statement timeout/)
  end

  it "leaves a new connection unlimited, as migrations open one" do
    timeout = Sequel.connect(db.opts.merge(keep_reference: false)) { statement_timeout(it) }

    expect(timeout).to eq("0")
  end

  context "when a Sidekiq job runs" do
    before do
      db.get(Sequel.function(:set_config, "statement_timeout", "0", false))
      Sidekiq::Testing.server_middleware { it.add Blog::JobConnection, -> { db } }
    end

    after { Sidekiq::Testing.server_middleware { it.remove Blog::JobConnection } }

    let(:timeouts) { [] }

    let(:job) do
      seen = timeouts
      read = method(:statement_timeout)
      stub_const("Spec::TimeoutJob", Class.new(Blog::Job) { define_method(:perform) { seen << read.call } })
    end

    it "leaves the job's queries unlimited" do
      job.perform_async
      job.drain

      expect(timeouts).to eq(["0"])
    end
  end
end
