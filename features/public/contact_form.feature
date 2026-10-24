Feature: Contact form
  In the browser the contact form tabs its fields in order, counts the message, shows the time where Aaron is,
  and names a field the browser or the server refuses until it is put right. With no script it still posts.

  Scenario: A message sent is confirmed on a page of its own, stored once, without a cookie
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada@example.com  |
      | Subject    | A question       |
      | Message    | About the beacon |
    And I send the contact form after the minimum wait
    Then I am on "/contact?sent=1"
    And ".f-ok strong" includes "Message sent."
    And the browser holds no cookie for the page
    When I reload the page
    And I reload the page
    Then ".f-ok strong" includes "Message sent."
    And the database answers "ada@example.com|A question|About the beacon|1" for:
      """
      SELECT reply_to || '|' || subject || '|' || body || '|' || (SELECT count(*) FROM mail_threads) FROM mail_messages
      """

  Scenario: Tab runs the three fields in order and lands on the send, never the honeypot, which sits off the screen
    When I open the contact form
    Then Tab from "#cf-email" reaches:
      | cf-subject |
      | cf-message |
      | BUTTON     |
    And the right edge of "input[name='message[reference]']" sits off the screen

  Scenario: The count under the message shows, starts at nothing, and counts up and down
    When I open the contact form
    Then ".f-row p.f-h" is visible
    And "p.f-h" reads "0 / 5000"
    When I fill in the contact form:
      | Message | About the beacon |
    Then "p.f-h" reads "16 / 5000"
    When I fill in the contact form:
      | Message | Beacon |
    Then "p.f-h" reads "6 / 5000"

  Scenario: The count starts at the length of what the page came back holding
    When I open the contact form
    And I fill in the contact form:
      | Subject    | \u0020      |
      | Your email | ada@example.com  |
      | Message    | About the beacon |
    And I send the contact form after the minimum wait
    Then "p.f-h" reads "16 / 5000"

  Scenario Outline: The clock shows <shown> in the site's zone at <at>
    Given the browser's clock reads "<at>"
    When I open the contact form
    Then "[data-clock]" reads "Central time · <shown> here right now"

    Examples:
      | at                       | shown   |
      | 2026-10-09T20:07:30Z     | 3:07 pm |
      | 2026-01-09T23:59:59Z     | 6:00 pm |

  Scenario: The clock shows the zone with the script off
    Given the page's scripts do not load
    When I open the contact form
    Then "[data-clock]" reads "Central time"

  Scenario: An address the browser refuses is named, and nothing posts
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada              |
      | Subject    | A question       |
      | Message    | About the beacon |
    And I send the contact form at once
    Then "#cf-email-error" reads "That is not an email address."
    And I am on "/contact"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """

  Scenario Outline: A <field> left blank is asked for, the filled fields left alone, a screen reader pointed at it
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada@example.com  |
      | Subject    | A question       |
      | Message    | About the beacon |
      | <label>    |                  |
    And I send the contact form at once
    Then "#<id>-error" reads "<message>"
    And the page has "#<id>[aria-invalid='true'][aria-describedby='<id>-error']"
    And 1 of ".f-e:visible" are visible

    Examples:
      | field   | label   | id         | message                 |
      | subject | Subject | cf-subject | Say what this is about. |
      | message | Message | cf-message | Write a message.        |

  Scenario: The first bad field takes the focus
    When I open the contact form
    And I fill in the contact form:
      | Message | About the beacon |
    And I send the contact form at once
    Then the focus is on "#cf-email"

  Scenario: The message clears once the field is put right, and the second send goes through
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada@example.com  |
      | Subject    |                  |
      | Message    | About the beacon |
    And I send the contact form at once
    Then "#cf-subject-error" is visible
    When I fill in the contact form:
      | Subject | A question |
    Then "#cf-subject-error" is hidden
    And the page has no "#cf-subject[aria-invalid]"
    When I send the contact form after the minimum wait
    Then I am on "/contact?sent=1"
    And the database answers "A question" for:
      """
      SELECT subject FROM mail_messages
      """

  Scenario: A field the server refuses reads its refusal, and holds one message however the two arrive
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada@example      |
      | Subject    | A question       |
      | Message    | About the beacon |
    And I send the contact form after the minimum wait
    Then "#cf-email-error" reads "That is not an email address."
    When I fill in the contact form:
      | Your email |  |
    And I send the contact form at once
    Then "#cf-email-error" reads "Add an address I can answer."
    And the page has 1 of ".f-e[data-for='cf-email']"

  Scenario: With the script off the form posts and confirms the send
    Given the page's scripts do not load
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada@example.com  |
      | Subject    | A question       |
      | Message    | About the beacon |
    And I send the contact form after the minimum wait
    Then I am on "/contact?sent=1"
    And the database answers "A question" for:
      """
      SELECT subject FROM mail_messages
      """

  Scenario: With the script off the server's refusal reads back
    Given the page's scripts do not load
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada@example      |
      | Subject    | A question       |
      | Message    | About the beacon |
    And I send the contact form after the minimum wait
    Then "#cf-email-error" reads "That is not an email address."

  Scenario: With the script off the browser still refuses a blank field in its own words
    Given the page's scripts do not load
    When I open the contact form
    And I fill in the contact form:
      | Your email | ada@example.com  |
      | Message    | About the beacon |
    And I send the contact form at once
    Then "#cf-subject-error" is hidden
    And I am on "/contact"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_threads
      """
