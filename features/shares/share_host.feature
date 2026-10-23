Feature: A single share on the share host
  The share host serves each shared file at its short code, to anyone with the link.

  Background:
    Given the share "notes.txt" of type "text/plain" holding "0123456789"

  Scenario: A share's code returns its exact bytes and no cache keeps them
    When I fetch "/[code of notes.txt]" from the share host
    Then the share host answers 200 with "0123456789"
    And the share host header "Content-Length" is "10"
    And the share host header "Content-Type" is "text/plain"
    And the share host header "Cache-Control" is "private, no-store"
    And the share host header "Accept-Ranges" is "bytes"

  Scenario: Each share opens by its whole code only
    Given the share "second.txt" of type "text/plain" holding "secondfile"
    And the shared file "notes.txt" has the code "abcdefgh"
    And the shared file "second.txt" has the code "abcdefghjk"
    When I fetch "/abcdefgh" from the share host
    Then the share host answers 200 with "0123456789"
    When I fetch "/abcdefghjk" from the share host
    Then the share host answers 200 with "secondfile"
    When I fetch "/abcdefg" from the share host
    Then the share host answers 404
    When I fetch "/abcdefghj" from the share host
    Then the share host answers 404

  Scenario: A share's code is its short code number in base 36
    Given the share "second.txt" of type "text/plain"
    When I fetch "/2" from the share host
    Then the share host answers 200 with "0123456789"

  Scenario: A head request answers with no body and counts no download
    When a browser asks the share host for the head of "/[code of notes.txt]"
    Then the share host answers 200 with nothing
    And the shared file "notes.txt" counts 0 downloads

  Scenario Outline: A share of the type <type> opens <how>
    Given the share "<filename>" of type "<type>"
    When I fetch "/[code of <filename>]" from the share host
    Then the share host header "Content-Disposition" is:
      """
      <how>; filename="<filename>"; filename*=UTF-8''<filename>
      """

    Examples:
      | type            | filename    | how        |
      | image/jpeg      | photo.jpg   | inline     |
      | application/pdf | paper.pdf   | inline     |
      | video/mp4       | clip.mp4    | inline     |
      | audio/mpeg      | song.mp3    | inline     |
      | application/zip | archive.zip | attachment |
      | text/html       | page.html   | attachment |
      | image/svg+xml   | logo.svg    | attachment |

  Scenario: A stored type that only begins with an inline type downloads
    Given the share "photo.png" of type "image/png"
    And the shared file "photo.png" is stored as the type "image/png, text/html"
    When I fetch "/[code of photo.png]" from the share host
    Then the share host header "Content-Disposition" is:
      """
      attachment; filename="photo.png"; filename*=UTF-8''photo.png
      """

  Scenario: A name outside ASCII keeps its letters in the encoded name only
    Given the share 'café "menu".zip' of type "application/zip"
    When I fetch '/[code of café "menu".zip]' from the share host
    Then the share host header "Content-Disposition" is:
      """
      attachment; filename="caf_ _menu_.zip"; filename*=UTF-8''caf%C3%A9%20%22menu%22.zip
      """

  Scenario: A shared page runs in a sandbox and the browser may not guess its type
    Given the share "page.html" of type "text/html" holding "<p>hi</p>"
    When I fetch "/[code of page.html]" from the share host
    Then the share host header "Content-Security-Policy" starts with "sandbox; default-src 'none';"
    And the share host header "X-Content-Type-Options" is "nosniff"

  Scenario: A range request returns the bytes it asks for
    When a browser fetches "/[code of notes.txt]" from the share host with the range "bytes=2-5"
    Then the share host answers 206 with "2345"
    And the share host header "Content-Range" is "bytes 2-5/10"
    And the share host header "Content-Length" is "4"
    And the share host header "Cache-Control" is "private, no-store"
    And the shared file "notes.txt" counts 0 downloads

  Scenario: A range past the end answers 416
    When I fetch "/[code of notes.txt]" from the share host with the header "Range" set to "bytes=20-30"
    Then the share host answers 416
    And the share host header "Content-Range" is "bytes */10"

  Scenario Outline: A browser download counts once, with the range <range>
    When a browser fetches "/[code of notes.txt]" from the share host with the range "<range>"
    Then the shared file "notes.txt" counts 1 download

    Examples:
      | range     |
      | bytes=0-5 |
      | bytes=0-  |

  Scenario: A browser download with no range counts once
    When a browser fetches "/[code of notes.txt]" from the share host
    Then the shared file "notes.txt" counts 1 download

  Scenario Outline: The probe <range> counts no download
    When a browser fetches "/[code of notes.txt]" from the share host with the range "<range>"
    Then the shared file "notes.txt" counts 0 downloads

    Examples:
      | range     |
      | bytes=0-1 |
      | bytes=0-0 |

  Scenario Outline: A fetch by <who> counts no download
    When the agent "<agent>" fetches "/[code of notes.txt]" from the share host
    Then the share host answers 200
    And the shared file "notes.txt" counts 0 downloads

    Examples:
      | who        | agent                                                                                    |
      | Slack      | Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)                               |
      | iMessage   | Mozilla/5.0 (Macintosh) AppleWebKit/601.2.4 facebookexternalhit/1.1 Facebot Twitterbot/1.0 |
      | curl       | curl/8.4.0                                                                               |
      | no browser |                                                                                          |

  Scenario: The admin's thumbnail preview counts no download
    When a browser fetches "/[code of notes.txt]?preview" from the share host
    Then the shared file "notes.txt" counts 0 downloads

  Scenario: A code with more on the end answers 404 and counts no download
    When a browser fetches "/[code of notes.txt]x" from the share host
    Then the share host answers 404
    And the shared file "notes.txt" counts 0 downloads

  Scenario: A share whose stored file is gone answers 404 and counts no download
    Given the share store lost the shared file "notes.txt"
    When a browser fetches "/[code of notes.txt]" from the share host
    Then the share host answers 404
    And the shared file "notes.txt" counts 0 downloads

  Scenario: A deleted share answers 404
    Given an API token
    When I DELETE "/shares/1" through the API
    And I fetch "/1" from the share host
    Then the share host answers 404

  Scenario: Posting to a share answers 404
    When I post to "/[code of notes.txt]" on the share host
    Then the share host answers 404

  Scenario Outline: The share host answers 404 for <path> and no cache keeps it
    When I fetch "<path>" from the share host
    Then the share host answers 404
    And the share host header "Cache-Control" is "private, no-store"

    Examples:
      | path                                    |
      | /                                       |
      | /admin                                  |
      | /posts                                  |
      | /writing                                |
      | /unknown                                |
      | /favicon.ico                            |
      | /.well-known/oauth-authorization-server |

  Scenario: The blog's host does not serve shares
    Given the shared file "notes.txt" has the code "zzqzzqzz"
    When I fetch "/zzqzzqzz" from the blog host
    Then the share host answers 404
    And the share host header "Cache-Control" is not "private, no-store"

  Scenario Outline: A forwarded host header naming the share host leaves the blog's answer as it was, under <header>
    When I fetch "/[code of notes.txt]" from the blog host with the header "<header>" set to "<value>"
    Then the share host header "Cache-Control" is not "private, no-store"

    Examples:
      | header           | value                 |
      | X-Forwarded-Host | shares.localhost      |
      | Forwarded        | host=shares.localhost |

  Scenario: A forwarded host header naming the blog still serves the share host
    When I fetch "/[code of notes.txt]" from the share host with the header "X-Forwarded-Host" set to "aaronmallen.me"
    Then the share host answers 200 with "0123456789"
    When I fetch "/zzzzz" from the share host with the header "Forwarded" set to "host=aaronmallen.me"
    Then the share host answers 404
    And the share host header "Cache-Control" is "private, no-store"

  Scenario: The share host is known with a port on it
    When I fetch "/zzzzz" from the share host with the header "Host" set to "shares.localhost:3000"
    Then the share host header "Cache-Control" is "private, no-store"

  Scenario: The blog still serves its own pages
    When I fetch "/about" from the blog host
    Then the share host answers 200
