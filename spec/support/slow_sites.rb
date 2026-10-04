# frozen_string_literal: true

require "socket"

module SlowSites
  def elapsed(*errors)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  rescue *errors
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  def serve(path = "/notes/1", &)
    server = TCPServer.new("127.0.0.1", 0)
    slow_sites << [server, Thread.new { loop { answer(server.accept, &) } }]
    "http://127.0.0.1:#{server.addr[1]}#{path}"
  end

  def shorten_webmention_budget(budget)
    stub_const("Social::Webmentions::Client::BLOCKED_RANGES", [])
    stub_const("Social::Webmentions::Client::BUDGET", budget)
    stub_const("Social::Webmentions::Client::PORTS", 1..65_535)
    stub_const("Social::Webmentions::Client::SPECIAL", [])
    allow(Socket).to receive(:getifaddrs).and_return([])
  end

  def stop_slow_sites
    slow_sites.each do |server, thread|
      thread.kill.join
      server.close
    end
  end

  def trickle(opening, every:, path: "/notes/1")
    serve(path) do |socket|
      socket.write(opening)

      loop do
        socket.write("x")
        sleep(every)
      end
    end
  end

  private

  def answer(socket)
    socket.gets("\r\n\r\n")
    yield socket
  rescue IOError, SystemCallError
    nil
  ensure
    socket.close
  end

  def slow_sites = @slow_sites ||= []
end

RSpec.configure do |config|
  config.include SlowSites
  config.after { stop_slow_sites }
end
