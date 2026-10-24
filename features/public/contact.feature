Feature: Contact
  The contact page takes a reply address, a subject and a message. A complete send stores the message with the
  sender's daily hash and lands on a confirmation. A bad field comes back with the server's own error. A
  honeypot, a signed stamp and a limit per sender and in all turn away bots without saying why.

  Scenario: The contact page heads the page and lists the info beside the form
    When I visit "/contact"
    Then the page title is "Contact | Aaron Allen"
    And ".hd .kicker" reads "Contact"
    And ".hd h1" reads "Send me something."
    And ".hd p.ld" reads "Real messages from real people get an answer, usually within a few days."
    And the page has ".g.even > .stick > .hd + dl.ci"
    And the page has ".g.even > .stick + div > form.form.card"
    And the texts of "dl.ci dt.kicker" are:
      | Where I am  |
      | What I’m on |
      | What I keep |
      | Elsewhere   |
    And the page has ".ci-v:text-is('San Antonio, Texas')"
    And the page has ".ci-s [data-clock='America/Chicago'][data-clock-label='Central time · %{time} here right now']"
    And "dl.ci" has a link "Credit Ninja" to "/about"
    And "dl.ci" has a link "Hanakai" to "https://hanakai.org"
    And "dl.ci" has a link "any of the projects" to "/projects"
    And the page has ".ci-v:text-is('Your address, subject and message, until I delete them.')"
    And the page has ".ci-s:has-text('No mailing list, no third party. Spam is gone after 30 days.')"
    And "dl.ci" has a link "Privacy" to "/privacy"
    And the links in ".ci ul.links a" go to:
      | https://github.com/aaronmallen           |
      | https://ruby.social/@aaronmallen         |
      | https://bsky.app/profile/aaronmallen.dev |
    And the page has no axe breaches in light or dark

  Scenario: The form posts back to /contact with three required, labelled, capped fields in reading order
    When I visit "/contact"
    Then the page has "form#contact-form.form[method='post'][action='/contact']"
    And the page has 1 of "form"
    And the page has "input[type='email']#cf-email"
    And the field labelled "Your email" is "#cf-email"
    And the field labelled "Subject" is "#cf-subject"
    And the field labelled "Message" is "#cf-message"
    And the names of "form .f-row .f-i" are:
      | message[reply_to] |
      | message[subject]  |
      | message[body]     |
    And the page has 3 of "form .f-row .f-i[required]"
    And the page has no "form .f-row .f-i[tabindex]"
    And "#cf-email" has the attribute "placeholder" set to "you@somewhere.dev"
    And "#cf-subject" has the attribute "placeholder" set to "What's this about?"
    And "#cf-message" has the attribute "placeholder" set to "Bugs, better patterns, arguments about service objects. All welcome."
    And the page has "#cf-subject[maxlength='200']"
    And the page has "#cf-message[maxlength='5000']"
    And the page has no "form[novalidate]"

  Scenario: The clock's slot reads the zone until a script fills it
    When I request "/contact"
    Then the body matches "data-clock=\"America/Chicago\"[^>]*>Central time<"

  Scenario: The count under the message follows it, with empty slots for the count and total, hidden without script
    When I request "/contact"
    Then the body matches "id=\"cf-message\"[^>]*>[^<]*</textarea><p class=\"f-h\" data-count-for=\"cf-message\" hidden><span data-count></span>[^<\d]*<span data-total></span></p>"

  Scenario: The submit sits under a silent icon beside a note, and the page carries no token, cookie or error
    When I visit "/contact"
    Then the page has "button.f-b[type='submit']:has-text('Send message') > i.fa-paper-plane[aria-hidden='true']"
    And ".f-a .f-n" reads "Goes straight to my inbox."
    And the page has no "input[type='hidden'][name='_csrf_token']"
    And the page has no ".f-e:visible"
    When I request "/contact"
    Then there is no "Set-Cookie" header

  Scenario: Each field has one hidden error slot holding the copy the server sends
    When I visit "/contact"
    Then the "data-for" of each ".f-e" is:
      | cf-email   |
      | cf-subject |
      | cf-message |
    And "#cf-email-error" has the attribute "data-blank" set to "Add an address I can answer."
    And "#cf-email-error" has the attribute "data-format" set to "That is not an email address."
    And "#cf-subject-error" has the attribute "data-blank" set to "Say what this is about."
    And "#cf-message-error" has the attribute "data-blank" set to "Write a message."
    And the page has no "#cf-subject-error[data-format], #cf-message-error[data-format]"

  Scenario: The page reads out no address to write to but the placeholder's
    When I request "/contact"
    Then the body does not include "mailto:"
    And the only email addresses in the body are "you@somewhere.dev"

  Scenario: The honeypot is a text field out of the tab order and the accessibility tree, styled out, with a bait label
    When I visit "/contact"
    Then the page has ".f-hp[aria-hidden='true'] input[type='text'][name='message[reference]'][tabindex='-1'][autocomplete='off']"
    And the page has ".f-hp label[for='cf-reference']"
    And the page has "#cf-reference[name='message[reference]']"

  Scenario: The page after a send confirms it as sent, offers no form, stores nothing, and keeps the head and info
    When I visit "/contact?sent=1"
    Then ".f-ok strong" reads "Message sent."
    And ".f-ok p" reads "It's in my queue. I'll reply to the address you gave. Thanks for writing."
    And the page has ".f-ok > i.fa-circle-check[aria-hidden='true']"
    And the page has no ".f-ok.f-wait"
    And the page has no "form"
    And the page has no ".post-body"
    And ".stick .hd h1" reads "Send me something."
    And the page has 4 of ".stick dl.ci .ci-r"
    And the page has no axe breaches in light or dark
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """

  Scenario Outline: The page asked for with <query> shows the plain form
    When I visit "/contact?<query>"
    Then the page has "form"
    And the page has no ".f-ok"
    And the page has no ".f-e:visible"
    And the page has no "[aria-invalid]"
    And "#cf-subject" has no "value" attribute

    Examples:
      | query                 |
      | throttled=1           |
      | errors[body][]=blank  |
      | values[subject]=x     |
      | values=x              |
      | errors=x              |

  Scenario: The page reached from another site answers
    Given my requests send the header "Sec-Fetch-Site" as "cross-site"
    When I request "/contact"
    Then it answers 200

  Scenario: A complete send redirects to the confirmation and stores the message with the sender's daily hash
    When I send the contact form:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 302
    And the "Location" header is "/contact?sent=1"
    And there is no "Set-Cookie" header
    And the database answers "ada@example.com|A question|About the beacon|unread" for:
      """
      SELECT m.reply_to || '|' || m.subject || '|' || m.body || '|' || mail_threads.status FROM mail_messages m JOIN mail_threads ON mail_threads.id = m.mail_thread_id
      """
    And the database answers "true" for:
      """
      SELECT visitor_hash ~ '^[0-9a-f]{64}$' AND visitor_hash <> encode(sha256('127.0.0.1'), 'hex') FROM mail_messages
      """
    When I request "/contact?sent=1"
    Then the body includes "Message sent."
    And the body does not include "About the beacon"
    When I request "/contact?sent=1"
    Then the database answers "1" for:
      """
      SELECT count(*) FROM mail_threads
      """

  Scenario: Two senders on one address with different browsers share one hash, keyed on the address alone
    When I send the contact form 2 times with the browsers "Mozilla/5.0 xN"
    Then the database answers "1" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM mail_messages
      """

  Scenario Outline: A send another site's page made, <how>, is refused and stored nowhere
    Given my requests send the header "<header>" as "<value>"
    When I send the contact form:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 403
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | how                                    | header         | value                |
      | which the browser marks cross-site     | Sec-Fetch-Site | cross-site           |
      | from a browser naming another origin   | Origin         | https://evil.example |

  Scenario Outline: A send the site's own page made, <how>, is stored
    Given my requests send <headers>
    When I send the contact form:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 302
    And the database answers "1" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | how                                  | headers                                      |
      | which the browser marks same-origin  | the header "Sec-Fetch-Site" as "same-origin" |
      | from a client that sends neither     | no "Origin" header                           |
      | asking for JSON                      | the header "Accept" as "application/json"    |
      | asking for plain text                | the header "Accept" as "text/plain"          |

  Scenario: A failing send from a client asking for JSON comes back unprocessable with the page
    Given my requests send the header "Accept" as "application/json"
    When I send the contact form:
      | reply_to | ada@example.com  |
      | subject  |                  |
      | body     | About the beacon |
    Then it answers 422
    And the "Content-Type" header is "text/html; charset=utf-8"

  Scenario: A filled honeypot stores nothing and follows the redirect a real sender follows, with no reason given
    When I send the contact form:
      | reply_to  | ada@example.com     |
      | subject   | A question          |
      | body      | About the beacon    |
      | reference | http://spam.example |
    Then it answers 302
    And the "Location" header is "/contact?sent=1"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """
    When I request "/contact?sent=1"
    Then the body does not include "class=\"f-e\""

  Scenario: The stamp rides the form hidden, signed for the moment the page was drawn
    When I visit "/contact"
    Then the page has "input[type='hidden'][name='message[stamp]']"
    And the stamp on the form was signed just now

  Scenario Outline: A send whose stamp is <age> is stored
    When I send the contact form with a stamp from <seconds> seconds ago:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 302
    And there is no "Set-Cookie" header
    And the database answers "1" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | age                     | seconds |
      | at the minimum time     | 3       |
      | just inside the expiry  | 86340   |

  Scenario Outline: A send <how> stores nothing and reads as sent
    When I send the contact form with a stamp from <seconds> seconds ago:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 302
    And the "Location" header is "/contact?sent=1"
    And there is no "Set-Cookie" header
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | how                               | seconds |
      | sent sooner than the minimum time | 1       |
      | sent before it was drawn          | -60     |
      | with a stamp past the expiry      | 86401   |
      | sent at once                      | 0       |

  Scenario Outline: A send with <stamp> as its stamp stores nothing and reads as sent
    When I send the contact form with the stamp "<stamp>":
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 302
    And the "Location" header is "/contact?sent=1"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | stamp              |
      | none               |
      | an empty one       |
      | soon               |
      | a moved time       |
      | a forged signature |

  @timeout:180_000
  Scenario Outline: In production the stamp keeps to <setting> set to <value>
    Given the environment sets <setting> to "<value>"
    And the site runs in production
    When I send the contact form with a stamp from <seconds> seconds ago:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 302
    And the database answers "<stored>" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | setting                        | value | seconds | stored |
      | CONTACT_MINIMUM_SUBMIT_SECONDS | 30    | 10      | 0      |
      | CONTACT_STAMP_EXPIRY_HOURS     | 1     | 7200    | 0      |
      | CONTACT_MINIMUM_SUBMIT_SECONDS | 0     | 0       | 1      |

  Scenario: A form sent back with an error carries a stamp drawn new
    When I send the contact form with a stamp from 60 seconds ago:
      | reply_to | ada@example.com  |
      | subject  |                  |
      | body     | About the beacon |
    Then it answers 422
    When I keep the body
    And I load the body I kept into the page
    Then the stamp on the form was signed just now

  Scenario: A send past the limit comes back refused with the page, stores nothing more and reads as a wait
    When I send the contact form 4 times
    Then it answers 429
    And the database answers "3" for:
      """
      SELECT count(*) FROM mail_threads
      """
    And the body matches "<div class=\"f-ok f-wait\"[^>]*>\s*<i class=\"[^\"]*fa-hourglass-half[^\"]*\" aria-hidden=\"true\">"
    And the body does not include "About the beacon"
    When I load the body I kept into the page after keeping it
    Then ".hd h1" reads "Send me something."
    And ".f-ok.f-wait strong" reads "You have sent enough for now"
    And ".f-ok.f-wait p" reads "That one did not reach me. Wait a while and send it again."
    And ".f-ok" does not match the pattern "\d"
    And the page has no "form"
    And the page has no ".post-body"
    And ".stick .hd h1" reads "Send me something."
    And the page has 4 of ".stick dl.ci .ci-r"

  Scenario Outline: A run of sends <how> is refused once the limit is reached
    Given my requests send the header "<header>" as "<value>"
    When I send the contact form 4 times <variation>
    Then it answers 429
    And the database answers "3" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | how                                   | header          | value       | variation                                 |
      | from one address with a new browser on each | Accept    | text/html   | with the browsers "Mozilla/5.0 xN"        |

  @timeout:180_000
  Scenario: In production a run of sends forging X-Forwarded-For, which is not the proxy's header, is refused once the limit is reached
    Given the site runs in production
    When I send the contact form 4 times from the addresses "unused"
    Then it answers 429
    And the database answers "3" for:
      """
      SELECT count(*) FROM mail_threads
      """

  @timeout:180_000
  Scenario: In production a second address, or a second IPv6 /64, has an allowance of its own
    Given the site runs in production
    When I send the contact form 3 times from the addresses "203.0.113.7"
    And I send the contact form 1 time from the addresses "198.51.100.4"
    Then it answers 302
    When I send the contact form 3 times from the addresses "2001:db8:1:2::1"
    And I send the contact form 1 time from the addresses "2001:db8:1:3::1"
    Then it answers 302
    And the database answers "8" for:
      """
      SELECT count(*) FROM mail_threads
      """

  @timeout:180_000
  Scenario: In production one IPv6 /64 with a new address on each send shares one allowance and one hash
    Given the site runs in production
    When I send the contact form 4 times from the addresses "2001:db8:1:2::N"
    Then it answers 429
    And the database answers "3" for:
      """
      SELECT count(*) FROM mail_threads
      """
    And the database answers "1" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM mail_messages
      """

  @timeout:180_000
  Scenario: In production an IPv4 address written as IPv6 shares the IPv4 address's allowance
    Given the site runs in production
    When I send the contact form 3 times from the addresses "203.0.113.7"
    And I send the contact form 1 time from the addresses "::ffff:203.0.113.7"
    Then it answers 429

  @timeout:180_000
  Scenario: In production sends from many addresses past a total limit set to three are refused
    Given the environment sets CONTACT_TOTAL_THROTTLE_LIMIT to "3"
    And the site runs in production
    When I send the contact form 4 times from the addresses "203.0.113.N"
    Then it answers 429
    And the database answers "3" for:
      """
      SELECT count(*) FROM mail_threads
      """

  @timeout:180_000
  Scenario: In production sends from many addresses take twenty in all and refuse the next
    Given the site runs in production
    When I send the contact form 21 times from the addresses "203.0.113.N"
    Then it answers 429
    And the database answers "20" for:
      """
      SELECT count(*) FROM mail_threads
      """

  Scenario: A send missing the subject comes back unprocessable, naming the field and keeping what was typed
    When I send the contact form:
      | reply_to | ada@example.com  |
      | subject  |             |
      | body     | About the beacon |
    Then it answers 422
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """
    When I load the body I kept into the page after keeping it
    Then the page has "form"
    And "#cf-subject-error.f-e" reads "Say what this is about."
    And the page has "p.f-e[data-for='cf-subject']"
    And the page has 1 of "p.f-e[data-for='cf-subject']"
    And "#cf-subject-error" has the attribute "data-blank" set to "Say what this is about."
    And the page has "#cf-subject[aria-invalid='true'][aria-describedby='cf-subject-error']"
    And the page has no "#cf-email[aria-invalid], #cf-message[aria-invalid]"
    And "#cf-email" has the attribute "value" set to "ada@example.com"
    And "#cf-message" has the value "About the beacon"

  Scenario Outline: A send holding only Unicode spaces in <field> comes back unprocessable, naming it, and stores nothing
    When I send the contact form:
      | reply_to | <reply_to> |
      | subject  | <subject>  |
      | body     | <body>     |
    Then it answers 422
    And the body matches "id=\"<id>-error\"[^>]*>\s*<message>\s*<"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """

    Examples:
      | field             | reply_to        | subject    | body              | id         | message                       |
      | the reply address | \u2003          | A question | About the beacon  | cf-email   | That is not an email address. |
      | the subject       | ada@example.com | \u2003     | About the beacon  | cf-subject | Say what this is about.       |
      | the message       | ada@example.com | A question | \u2003\n\u3000    | cf-message | Write a message.              |

  Scenario: An address with a Unicode space inside comes back unprocessable, naming the address
    When I send the contact form:
      | reply_to | ada\u2003lovelace@example.com |
      | subject  | A question                    |
      | body     | About the beacon              |
    Then it answers 422
    And the body matches "id=\"cf-email-error\"[^>]*>\s*That is not an email address.\s*<"

  Scenario: Unicode spaces around the words are stored as typed
    When I send the contact form:
      | reply_to | ada@example.com          |
      | subject  | \u2003A question\u2003   |
      | body     | \u00a0About the beacon   |
    Then it answers 302
    And the database answers "true" for:
      """
      SELECT subject = E'\u2003A question\u2003' AND body = E'\u00a0About the beacon' FROM mail_messages
      """

  Scenario: A message longer than the field takes comes back unprocessable, the count line between it and its error
    When I send a contact message of 5001 characters
    Then it answers 422
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """
    When I load the body I kept into the page after keeping it
    Then "#cf-message-error.f-e" reads "Shorten the message."
    And the page has "#cf-message + p.f-h + p.f-e"

  Scenario: An address that is not one comes back unprocessable, named and kept
    When I send the contact form:
      | reply_to | ada              |
      | subject  | A question       |
      | body     | About the beacon |
    Then it answers 422
    When I load the body I kept into the page after keeping it
    Then "#cf-email-error.f-e" reads "That is not an email address."
    And "#cf-email" has the attribute "value" set to "ada"

  Scenario: A control character comes back unprocessable rather than reaching the database
    When I send the contact form:
      | reply_to | ada@example.com    |
      | subject  | A question         |
      | body     | hello\u0000world   |
    Then it answers 422
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """

  Scenario Outline: A hidden character in <field> is named as one, not as a field to check
    When I send the contact form:
      | reply_to | <reply_to> |
      | subject  | <subject>  |
      | body     | <body>     |
    Then it answers 422
    When I load the body I kept into the page after keeping it
    Then "#<id>-error.f-e" reads "<message>"
    And the page has no ".f-e:text-is('Check this field.')"

    Examples:
      | field             | reply_to             | subject           | body                  | id         | message                                |
      | the reply address | ada\u0001@example.com | A question       | About the beacon      | cf-email   | The address holds a hidden character.  |
      | the subject       | ada@example.com      | A\u0001question   | About the beacon      | cf-subject | The subject holds a hidden character.  |
      | the message       | ada@example.com      | A question        | About\u0001the beacon | cf-message | The message holds a hidden character.  |

  Scenario: A body holding a tab and a line break is kept
    When I send the contact form:
      | reply_to | ada@example.com   |
      | subject  | A question        |
      | body     | first\n\tsecond   |
    Then the database answers "true" for:
      """
      SELECT body = E'first\n\tsecond' FROM mail_messages
      """

  Scenario: A send with nothing but its stamp names every field
    When I send the contact form:
      | reply_to |  |
      | subject  |  |
      | body     |  |
    Then it answers 422
    When I load the body I kept into the page after keeping it
    Then the texts of ".f-e:visible" are:
      | Add an address I can answer. |
      | Say what this is about.      |
      | Write a message.             |

  Scenario: A body holding HTML is stored as typed, and read back into the field escaped
    When I send the contact form:
      | reply_to | ada@example.com                                |
      | subject  | A question                                     |
      | body     | <script>alert('x')</script> and <b>bold</b>    |
    Then the database answers "<script>alert('x')</script> and <b>bold</b>" for:
      """
      SELECT body FROM mail_messages
      """
    When I send the contact form:
      | reply_to | ada@example.com                                |
      | subject  |                                           |
      | body     | <script>alert('x')</script> and <b>bold</b>    |
    Then the body includes "&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;"
    And the body includes "&lt;b&gt;bold&lt;/b&gt;"
    And the body does not include "<script>alert"
    And the body does not include "<b>bold</b>"
    When I load the body I kept into the page after keeping it
    Then "#cf-message" has the value "<script>alert('x')</script> and <b>bold</b>"
