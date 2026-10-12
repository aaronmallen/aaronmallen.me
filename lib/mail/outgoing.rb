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
    MIME_TYPE = %r{\A[\w.+-]+/[\w.+-]+\z}
    OCTET_STREAM = "application/octet-stream"
    QUOTED = /["\\\r\n]/
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

    def initialize(from:, to:, subject:, html:, cc: [], bcc: [], in_reply_to: nil, files: [])
      @headers = {
        "From" => from, "To" => to.join(", "), "Cc" => cc.join(", "), "Bcc" => bcc.join(", "),
        "Subject" => encoded(subject.to_s), "In-Reply-To" => in_reply_to, "References" => in_reply_to,
      }
      @html = html
      @files = files
    end

    def raw = Base64.urlsafe_encode64(message)

    private

    def attachment(file)
      name = encoded(file.fetch(:filename).gsub(QUOTED, "_"))
      type = MIME_TYPE.match?(file[:type].to_s) ? file[:type] : OCTET_STREAM

      [
        "Content-Type: #{type}; name=\"#{name}\"", "Content-Disposition: attachment; filename=\"#{name}\"",
        *base64(file.fetch(:data)),
      ].join(BREAK)
    end

    def base64(data) = ["Content-Transfer-Encoding: base64", "", [data].pack("m").gsub("\n", BREAK)]

    def body
      text = multipart("alternative", [["text/plain", self.class.text(@html)], ["text/html", @html]].map { part(*it) })
      return text if @files.empty?

      multipart("mixed", [text.join(BREAK), *@files.map { attachment(it) }])
    end

    def encoded(text) = text.ascii_only? ? text : "=?UTF-8?B?#{Base64.strict_encode64(text)}?="

    def header_lines
      @headers.filter_map { |name, value| "#{name}: #{value.gsub(LINE, ' ')}" unless value.to_s.empty? }
    end

    def message = [*header_lines, "MIME-Version: 1.0", *body].join(BREAK)

    def multipart(kind, parts)
      boundary = "mail-#{SecureRandom.hex(12)}"

      [
        "Content-Type: multipart/#{kind}; boundary=\"#{boundary}\"", "",
        *parts.flat_map { ["--#{boundary}", it] }, "--#{boundary}--", "",
      ]
    end

    def part(type, text) = ["Content-Type: #{type}; charset=\"UTF-8\"", *base64(text)].join(BREAK)
  end
end
