# frozen_string_literal: true

ENV["FERRUM_INTERMITTENT_ATTEMPTS"] ||= "1"

require "axe/configuration"
require "capybara/cuprite"
require_relative "admin_session"
require_relative "features"

module Spec
  module Browser
    WAIT = 5

    class RequestGate
      HOLD_TIMEOUT = 5

      Hold = Data.define(:after, :arrived, :released) do
        def pass
          arrived.push(true)
          released.pop(timeout: HOLD_TIMEOUT)
        end

        def release = released.push(true)

        def wait_for_arrival
          arrived.pop(timeout: HOLD_TIMEOUT) or raise "no request arrived to hold within #{HOLD_TIMEOUT}s"
        end
      end

      def initialize(app)
        @app = app
        reset
      end

      def admit(path) = @refusals.delete(path)

      def answered(path) = @answered[path]

      def call(env)
        env.delete(Blog::RequestTimer::AFTER_REPLY)
        path = env[Rack::PATH_INFO]
        @counts[path] += 1
        return [@refusals[path], {}, []] if @refusals[path]

        hold = @holds.delete(path)
        hold.pass if hold && !hold.after
        @app.call(env).tap do
          hold.pass if hold&.after
          @answered[path] += 1
        end
      end

      def count(path) = @counts[path]

      def hold(path, after: false)
        @holds[path] = Hold.new(after:, arrived: Thread::Queue.new, released: Thread::Queue.new)
      end

      def refuse(path, status) = @refusals[path] = status

      def reset
        @answered = Hash.new(0)
        @counts = Hash.new(0)
        @holds = {}
        @refusals = {}
      end
    end

    def accent_text
      evaluate_script(<<~JS)
        (() => {
          const probe = document.body.appendChild(document.createElement("span"));
          probe.style.color = "var(--color-accent-text)";
          const color = getComputedStyle(probe).color;
          probe.remove();
          return color;
        })()
      JS
    end

    def admin_session_cookie = Spec::AdminSession.cookie

    def answer_confirm(button)
      yield if block_given?
      ask = confirm_ask
      ask.find("[data-confirm-message]").text.tap { ask.find(button).click }
    end

    def axe_breaches
      execute_script(Axe::Configuration.instance.jslib)

      using_wait_time(10) { evaluate_async_script(<<~JS, %w[wcag2a wcag2aa wcag21a wcag21aa wcag22aa]) }
        const done = arguments[arguments.length - 1];
        axe.run(document, { runOnly: { type: 'tag', values: arguments[0] }, rules: { 'color-contrast': { enabled: false } } }).then(({ violations }) => done(
          violations.flatMap(({ id, nodes }) => nodes.map((node) => `${id} at ${node.target.join(' ')}: ${node.failureSummary}`))
        ));
      JS
    end

    def color_of(element) = evaluate_script("getComputedStyle(arguments[0]).color", element)

    def confirm_ask = find("[data-confirm-ask]")

    def confirm_no(&) = answer_confirm("[data-confirm-decline]", &)

    def confirm_yes(&) = answer_confirm("[data-confirm-accept]", &)

    def cookie(name)
      page.driver.cookies[name]&.value
    end

    def emulate_color_scheme(scheme)
      page.driver.browser.page.command(
        "Emulation.setEmulatedMedia",
        features: [{ name: "prefers-color-scheme", value: scheme }],
      )
    end

    def forge_form(action)
      execute_script(<<~JS)
        const form = document.querySelector("form[method='post'][action='#{action}']");
        form.querySelector("input[name='#{Blog::UI::Components::Form::TOKEN_FIELD}']").value = "forged";
        form.submit();
      JS
      assert_selector "h1", text: "Form expired"
    end

    def hear_live(since)
      wait_for(be > since) { evaluate_script("Number(document.documentElement.dataset.liveHeard) || 0") }
    end

    def item(label) = menu.first(".ctx-item", text: label)

    def keep_page = execute_script("window.kept = true")

    def kept_page? = evaluate_script("window.kept === true")

    def menu = find("[data-context-menu]")

    def press(*keys) = page.driver.browser.keyboard.type(*keys)

    def refetch_state = evaluate_script("document.documentElement.dataset.fetch ?? null")

    def request_gate = Capybara.app

    def settle(selector)
      evaluate_async_script(<<~JS, selector)
        const done = arguments[arguments.length - 1];
        Promise.all(document.querySelector(arguments[0]).getAnimations().map((a) => a.finished)).then(() => done(true));
      JS
    end

    def settle_live(since = nil)
      hear_live(since) if since
      wait_for(be_nil) { refetch_state }
    end

    def show(screen)
      screen.respond_to?(:call) ? instance_exec(&screen) : visit(screen)
    end

    def sign_in_to_admin
      page.driver.set_cookie(
        Blog::SessionCookie::KEY,
        admin_session_cookie,
        domain: page.server.host,
        path: Blog::SessionCookie::PATH,
      )
    end

    def wait_for(matcher, &) = using_wait_time(WAIT) { expect(&).to eventually(matcher) }

    def wait_for_answer(path, count = 1) = wait_for(be >= count) { request_gate.answered(path) }

    def wait_for_stream = wait_for_answer("/admin/events")

    def watch_clipboard
      execute_script(<<~JS)
        window.copiedKeys = [];
        Object.defineProperty(navigator, "clipboard", {
          value: { writeText: (text) => { window.copiedKeys.push(text); return Promise.resolve(); } },
        });
      JS
    end
  end
end

RSpec::Matchers.define :eventually do |expected|
  supports_block_expectations

  match do |reader|
    Capybara.current_session.document.synchronize do
      expected.matches?(reader.call) or raise Capybara::ExpectationNotMet
    end
  rescue Capybara::ExpectationNotMet
    false
  end

  failure_message { expected.failure_message }

  description { "eventually #{expected.description}" }
end

Capybara.app = Spec::Browser::RequestGate.new(Capybara.app)
Capybara.javascript_driver = :cuprite
Capybara.server = :puma, { Silent: true }

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(
    app,
    headless: true,
    process_timeout: 30,
    timeout: 10,
    url_allowlist: [%r{\Ahttp://#{Regexp.escape(Capybara.server_host)}:}],
    window_size: [1280, 800],
    browser_options: {
      "blink-settings" => "primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4",
    },
  )
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/(slices/[^/]+/)?browser/}) do |metadata|
    metadata[:browser] = true
    metadata[:js] = true
  end

  config.include Spec::Browser, :browser

  config.before(:each, :browser) do
    Analytics::Slice.start(:geo)
    today
  end

  config.after(:each, :browser) { request_gate.reset }
end
