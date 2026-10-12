# frozen_string_literal: true

require "base64"
require "cgi"
require "sanitize"
require "securerandom"

module Mail
  class Outgoing
    BREAK = "\r\n"
    EDITOR = Sanitize::Config.freeze_config(
      elements: %w[a b blockquote br code div em i li ol p pre s strike strong u ul],
      attributes: { "a" => %w[href] },
      protocols: { "a" => { "href" => %w[http https mailto] } },
      remove_contents: %w[script style],
    )
    LINE = /[\r\n]+/
    TEXT = Sanitize::Config.freeze_config(
      Sanitize::Config.merge(
        Sanitize::Config::DEFAULT,
        whitespace_elements: Sanitize::Config::DEFAULT[:whitespace_elements].transform_values do
          { before: "\n", after: "\n" }
        end,
      ),
    )

    def self.clean(html) = Sanitize.fragment(html.to_s, EDITOR)

    def self.from_text(text)
      CGI.escapeHTML(text.to_s.strip).split(/(?:\r?\n){2,}/).map { "<p>#{it.gsub(/\r?\n/, '<br>')}</p>" }.join
    end

    def self.text(html) = CGI.unescapeHTML(Sanitize.fragment(html.to_s, TEXT)).gsub(/\n\s*\n\s*/, "\n\n").strip

    def initialize(from:, to:, subject:, html:, cc: [], bcc: [], in_reply_to: nil)
      @headers = {
        "From" => from, "To" => to.join(", "), "Cc" => cc.join(", "), "Bcc" => bcc.join(", "),
        "Subject" => encoded(subject), "In-Reply-To" => in_reply_to, "References" => in_reply_to,
      }
      @html = html
    end

    def raw = Base64.urlsafe_encode64(message)

    private

    def encoded(text) = text.ascii_only? ? text : "=?UTF-8?B?#{Base64.strict_encode64(text)}?="

    def header_lines
      @headers.filter_map { |name, value| "#{name}: #{value.gsub(LINE, ' ')}" unless value.to_s.empty? }
    end

    def message
      boundary = "mail-#{SecureRandom.hex(12)}"
      parts = [["text/plain", self.class.text(@html)], ["text/html", @html]].map { part(boundary, *it) }

      [
        *header_lines, "MIME-Version: 1.0", "Content-Type: multipart/alternative; boundary=\"#{boundary}\"", "",
        *parts, "--#{boundary}--", "",
      ].join(BREAK)
    end

    def part(boundary, type, body)
      [
        "--#{boundary}", "Content-Type: #{type}; charset=\"UTF-8\"", "Content-Transfer-Encoding: base64", "",
        [body].pack("m").gsub("\n", BREAK),
      ].join(BREAK)
    end
  end
end
