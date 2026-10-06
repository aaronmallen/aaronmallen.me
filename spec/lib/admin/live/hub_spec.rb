# frozen_string_literal: true

require "socket"

RSpec.describe Admin::Live::Hub do
  subject(:hub) do
    described_class.new(url:, reporter: agent, heartbeat_seconds:, retry_seconds: 0.1, tick_seconds: 0.05)
  end

  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:heartbeat_seconds) { 30 }
  let(:pairs) { [] }
  let(:url) { Blog::Providers::DBProvider.database_url(Hanami.app["settings"].database) }

  before { allow(agent).to receive(:notify) }

  after do
    hub.stop
    pairs.flatten.each { it.close unless it.closed? }
  end

  def notify(table)
    Sequel.connect(url, keep_reference: false) { it.notify(described_class::CHANNEL, payload: table) }
  end

  def open_stream
    UNIXSocket.pair.then do |pair|
      pairs << pair
      hub.open(pair.first)
      pair.last
    end
  end

  def read_until(reader, text, seconds: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    (+"").tap do |found|
      until found.include?(text)
        left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        unless left.positive? && reader.wait_readable(left)
          raise "no #{text.inspect} within #{seconds}s in #{found.inspect}"
        end

        found << reader.readpartial(4096)
      end
    end
  end

  def terminate_listener
    Sequel.connect(url, keep_reference: false) do |db|
      listeners = db[:pg_stat_activity].where(application_name: described_class::APPLICATION_NAME)
      listeners.select_map(Sequel.function(:pg_terminate_backend, :pid))
    end
  end

  def wait_for(seconds: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    sleep(0.05) until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  end

  it "answers each stream as an event stream that retries" do
    expect(read_until(open_stream, "retry:")).to start_with("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n")
  end

  it "sends a change to every open stream" do
    readers = Array.new(2) { open_stream }
    notify("messages")

    expect(readers.map { read_until(it, "data: messages\n\n") }).to all(include("event: change\ndata: messages\n\n"))
  end

  describe "with nothing changing" do
    let(:heartbeat_seconds) { 0.2 }

    it "sends a heartbeat" do
      expect(read_until(open_stream, ": heartbeat\n\n")).to include(": heartbeat\n\n")
    end
  end

  it "drops a stream whose reader went away" do
    open_stream.close
    notify("messages")

    wait_for { hub.empty? }

    expect(hub).to be_empty
  end

  it "drops a stream that cannot take a write without blocking" do
    writer, = UNIXSocket.pair.tap { pairs << it }
    nil until writer.write_nonblock("x" * 65_536, exception: false) == :wait_writable
    hub.open(writer)

    expect([hub.empty?, writer.closed?]).to eq([true, true])
  end

  it "tells each stream to catch up when its own connection comes back" do
    reader = open_stream
    terminate_listener

    expect(read_until(reader, "data: *\n\n")).to include("event: change\ndata: *\n\n")
  end

  it "reports a dropped connection" do
    reader = open_stream
    terminate_listener
    read_until(reader, "data: *\n\n")

    expect(agent).to have_received(:notify).with(Sequel::DatabaseDisconnectError).at_least(:once)
  end
end
