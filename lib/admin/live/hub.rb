# frozen_string_literal: true

require "sequel"

module Admin
  module Live
    class Hub
      APPLICATION_NAME = "admin_live_hub"
      CATCH_UP = "*"
      CHANNEL = "admin_changes"
      HEAD = [
        "HTTP/1.1 200 OK\r\n",
        "Content-Type: text/event-stream\r\n",
        "Cache-Control: no-cache\r\n",
        "X-Robots-Tag: #{Admin::Slice::ROBOTS}\r\n",
        "\r\n",
        "retry: 2000\n\n",
      ].join.freeze
      HEARTBEAT = ": heartbeat\n\n"
      HEARTBEAT_SECONDS = 30
      READY_SECONDS = 5
      RETRY_SECONDS = 2
      TICK_SECONDS = 1

      def initialize(
        url:, reporter:, heartbeat_seconds: HEARTBEAT_SECONDS, retry_seconds: RETRY_SECONDS, tick_seconds: TICK_SECONDS
      )
        @heartbeat_seconds = heartbeat_seconds
        @lock = Monitor.new
        @ready = @lock.new_cond
        @reporter = reporter
        @retry_seconds = retry_seconds
        @streams = []
        @tick_seconds = tick_seconds
        @url = url
      end

      def empty? = @lock.synchronize { @streams.empty? }

      def open(socket)
        start
        @lock.synchronize { @streams << socket if deliver(socket, HEAD) }
      end

      def stop
        listener = @lock.synchronize { @listener.tap { @stopping = true } }
        listener&.join
        @lock.synchronize { @streams.each { close(it) }.clear }
      end

      private

      def beat
        throw :stop if @stopping
        return if monotonic - @beaten_at < @heartbeat_seconds

        broadcast(HEARTBEAT)
      end

      def broadcast(message)
        @lock.synchronize do
          @beaten_at = monotonic
          @streams.select! { deliver(it, message) }
        end
      end

      def close(socket)
        socket.close unless socket.closed?
      rescue IOError, SystemCallError
        nil
      end

      def connect
        db = Sequel.connect(@url, driver_options: { application_name: APPLICATION_NAME }, keep_reference: false,
                                  max_connections: 1)
        yield db
      ensure
        db&.disconnect
      end

      def deliver(socket, message)
        return true if socket.write_nonblock(message, exception: false) == message.bytesize

        close(socket)
        false
      rescue IOError, SystemCallError
        close(socket)
        false
      end

      def event(table) = "event: change\ndata: #{table}\n\n"

      def listen(db)
        options = { after_listen: ->(_) { listening }, loop: ->(_) { beat }, timeout: @tick_seconds }

        db.listen(CHANNEL, **options) { |*, table| broadcast(event(table)) }
      end

      def listening
        @lock.synchronize do
          broadcast(event(CATCH_UP)) if @listened
          @beaten_at = monotonic
          @listened = @listening = true
          @reported = false
          @ready.broadcast
        end
      end

      def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      def report(error)
        @lock.synchronize do
          @listening = false
          @reporter.notify(error) unless @reported
          @reported = true
        end
      end

      def run
        until @stopping
          begin
            connect { listen(it) }
          rescue StandardError => e
            report(e)
            sleep(@retry_seconds) unless @stopping
          end
        end
      end

      def start
        @lock.synchronize do
          @listener = Thread.new { run }.tap { it.name = APPLICATION_NAME } unless @listener&.alive?
          @ready.wait(READY_SECONDS) unless @listening
        end
      end
    end
  end
end
