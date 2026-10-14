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
