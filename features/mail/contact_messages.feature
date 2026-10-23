Feature: Contact form messages
  A message sent through the contact form lands as a mail thread on the contact form account.
  The form caps each field, limits how often one visitor and everyone together may send, and
  files mail from a sender marked as spam straight into spam.

  Scenario: The contact form trims the ends of every field and files the message on the contact form account
    When a visitor sends the contact form from " ada@example.com " about "  A question " saying "\n About the beacon \n"
    Then the contact form answers with status 302
    And the contact form stored the message:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
      | provider | contact_form     |
      | hashed   | true             |

  Scenario: The contact form stores every line break in the body as a newline
    When a visitor sends the contact form from "ada@example.com" about "A question" saying "About\r\nthe\rbeacon\n"
    Then the contact form stored the message:
      | body | About\nthe\nbeacon |

  Scenario Outline: The contact form <verdict> a <field> of <size> letters
    When a visitor sends the contact form with a <field> of <size> letters
    Then the contact form answers with status <status>

    Examples:
      | verdict | field    | size | status |
      | takes   | subject  | 200  | 302    |
      | takes   | body     | 5000 | 302    |
      | refuses | subject  | 201  | 422    |
      | refuses | reply_to | 254  | 422    |

  Scenario: The contact form counts the browser's line breaks in a body as one letter each
    When a visitor sends the contact form with a body of 500 lines of nine letters and "a"
    Then the contact form answers with status 302
    When a visitor sends the contact form with a body of 500 lines of nine letters and "aa"
    Then the contact form answers with status 422

  Scenario: A visitor whose messages all went out before the window opened is heard again
    When a visitor sends the contact form
    And a visitor sends the contact form
    And a visitor sends the contact form
    And a visitor sends the contact form
    Then the contact form answers with status 429
    Given the contact mail sent so far arrived 61 minutes ago
    When a visitor sends the contact form
    Then the contact form answers with status 302
    And the mail threads kept are "A question, A question, A question, A question"

  Scenario: Mail from a sender the admin marked as spam goes to spam, but the sender hears the same
    Given I am signed in to the admin
    And the mail threads:
      | subject  | reply to        |
      | Old note | ada@example.com |
    When I post to the mail route "/admin/mail/#[Old note]/change/spam"
    And a visitor sends the contact form from "ada@example.com"
    Then the contact form answers with status 302
    And the newest mail thread is spam

  Scenario: Mail from a sender MCP marked as spam goes to spam in any letter case, and other senders stay unread
    Given I am signed in to the admin
    And the mail threads:
      | subject  | reply to        |
      | Old note | Ada@Example.COM |
    And an MCP client connected with the scopes "read write mail"
    When I call the MCP mail tool "mark_mail_thread" with:
      """
      {"id": #[Old note], "status": "spam"}
      """
    And a visitor sends the contact form from "aDA@example.com"
    Then the contact form answers with status 302
    And the newest mail thread is spam
    When a visitor sends the contact form from "grace@example.com"
    Then the newest mail thread is unread

  Scenario: Mail from a spam sender goes to spam even after a neighbour is marked read
    Given an API token with the scopes "read write mail"
    And the mail threads:
      | subject  | reply to          |
      | Old note | ada@example.com   |
      | Kind one | grace@example.com |
    When I call the mail API with POST "/mail/threads/#[Old note]/mark" and:
      """
      {"status": "spam"}
      """
    And I call the mail API with POST "/mail/threads/#[Kind one]/mark" and:
      """
      {"status": "read"}
      """
    And a visitor sends the contact form from "ada@example.com"
    Then the newest mail thread is spam

  Scenario: The reaper deletes a spam sender's next message in time, and the sender stays marked
    Given an API token with the scopes "read write mail"
    And the mail threads:
      | subject  | reply to        |
      | Old note | ada@example.com |
    When I call the mail API with POST "/mail/threads/#[Old note]/mark" and:
      """
      {"status": "spam"}
      """
    And a visitor sends the contact form from "ada@example.com"
    And the spam marks age by 31 days
    And the spam reaper runs
    Then the mail threads kept are ""
    When a visitor sends the contact form from "ada@example.com"
    Then the newest mail thread is spam

  Scenario: Mail from a spam sender is unread again once a message from them is marked read
    Given an API token with the scopes "read write mail"
    And the mail threads:
      | subject  | reply to        |
      | Old note | ada@example.com |
    When I call the mail API with POST "/mail/threads/#[Old note]/mark" and:
      """
      {"status": "spam"}
      """
    And a visitor sends the contact form from "ada@example.com"
    And I call the mail API with POST "/mail/threads/#[A question]/mark" and:
      """
      {"status": "read"}
      """
    And a visitor sends the contact form from "ada@example.com"
    Then the newest mail thread is unread

  Scenario: Mail from a spam sender is unread again once the admin marks a message from them unread
    Given I am signed in to the admin
    And an API token with the scopes "read write mail"
    And the mail threads:
      | subject  | reply to        |
      | Old note | ada@example.com |
    When I call the mail API with POST "/mail/threads/#[Old note]/mark" and:
      """
      {"status": "spam"}
      """
    And a visitor sends the contact form from "ada@example.com"
    And I post to the mail route "/admin/mail/#[A question]/change/unread"
    And a visitor sends the contact form from "ada@example.com"
    Then the newest mail thread is unread

  Scenario: Spam counts toward the limit on everyone's mail
    Given an API token with the scopes "read write mail"
    And the mail threads:
      | subject  | reply to        |
      | Old note | ada@example.com |
    And 18 other visitors sent mail in the last hour
    When I call the mail API with POST "/mail/threads/#[Old note]/mark" and:
      """
      {"status": "spam"}
      """
    And a visitor sends the contact form from "ada@example.com"
    Then the contact form answers with status 302
    When a visitor sends the contact form from "grace@example.com"
    Then the contact form answers with status 429

  Scenario: The contact form takes one of two messages from one sender that both pass the count before the lock
    When a visitor sends the contact form
    And a visitor sends the contact form
    And two visitors send the contact form while the mail lock is held
    Then the contact form answers the two visitors with "302, 429"
    And the mail threads kept are "A question, A question, A question"

  Scenario: The contact form takes one of two messages that both pass the total count before the lock
    Given 19 other visitors sent mail in the last hour
    When two visitors send the contact form while the mail lock is held
    Then the contact form answers the two visitors with "302, 429"
    And 20 mail threads are kept
