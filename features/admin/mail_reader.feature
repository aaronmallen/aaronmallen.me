Feature: Admin mail reader
  Opening a thread marks it read and shows it beside the list, with the
  acts that fit where it lives.

  Scenario: Opening a thread marks it read and lands on it in the same list
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject | account            |
      | Hello   | aaron@work.example |
    When I visit the mail page "/admin/mail?folder=inbox&show=unread&account=@[aaron@work.example]"
    And I open the mail thread "Hello"
    Then the mail page address is "/admin/mail?account=@[aaron@work.example]&folder=inbox&show=unread&thread=#[Hello]#read-#[Hello]"
    And the mail thread "Hello" is now read
    When I post to the mail route "/admin/mail/#[Hello]/open" with:
      """
      folder=inbox
      show=all
      """
    Then the mail answer goes to "/admin/mail?folder=inbox&show=all&thread=#[Hello]#read-#[Hello]"
    When I post to the mail route "/admin/mail/999999/open"
    Then the mail answer has status 404

  Scenario: The reader shows a Gmail thread with its earlier messages folded
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject | account            | from         | reply to        | minutes ago | labels |
      | Hello   | aaron@work.example | Ada Lovelace | ada@example.com | 2           | urgent |
    And the mail thread "Hello" has the messages:
      | from         | reply to           | body       | minutes ago |
      |              | aaron@work.example | My reply   | 1           |
      | Ada Lovelace | ada@example.com    | Her answer | 0           |
    When I visit the mail page "/admin/mail?thread=#[Hello]"
    Then the mail reader meta shows "aaron@work.example"
    And the mail reader meta shows "#urgent"
    And the mail reader title is "Hello"
    And the mail reader shows the latest message as plain text "Her answer"
    And the mail reader folds "2 earlier messages · Ada Lovelace, you"
    And the mail reader marks the folded message "My reply" as mine
    And the mail row "Hello" is open
    And the mail sender says "Ada Lovelace isn’t in Contacts"
    And the mail reader shows a link "Add to Contacts" to "/admin/contacts/new?name=Ada%20Lovelace&email=ada@example.com"
    And the mail actions are "Archive, Snooze, Make a task, Star, Mark read, Trash, Gmail"
    And the page has no axe breaches in light or dark

  Scenario: The reader shows a message with HTML as rich text
    Given I am signed in to the admin
    And the mail threads:
      | subject | html                                                                                                               |
      | Notes   | <p><a href="https://example.com/n">notes</a></p><ul><li>One</li></ul><img src="https://example.com/a.png" alt="A"> |
    And the web serves the image "https://example.com/a.png"
    When I visit the mail page "/admin/mail?thread=#[Notes]"
    Then the mail reader shows a link "notes" to "https://example.com/n"
    And the mail reader shows a list item "One"
    And the mail reader loads the image "https://example.com/a.png"

  Scenario: The reader knows a sender by their email in Contacts and not by their name
    Given I am signed in to the admin
    And the mail threads:
      | subject | from         | reply to        |
      | Hello   | Ada Lovelace | ada@example.com |
      | Hi      | Cy Twombly   | cy@example.com  |
    And the contact "Countess of Lovelace" at the mail address "Ada@Example.com"
    And the contact "Cy Twombly" at the mail address "other@example.com"
    When I visit the mail page "/admin/mail?thread=#[Hello]"
    Then the mail sender says "Countess of Lovelace"
    And the mail reader shows a link "Open person" to "/admin/contacts/1/edit"
    When I visit the mail page "/admin/mail?thread=#[Hi]"
    Then the mail sender says "Cy Twombly isn’t in Contacts"

  Scenario: A contact form thread offers spam and delete, and names a stranger by email
    Given I am signed in to the admin
    And the mail threads:
      | subject | status | reply to            | snoozed hours |
      | Read    | read   | visitor@example.com |               |
      | Junk    | spam   |                     |               |
      | Later   | read   |                     | 1             |
    When I visit the mail page "/admin/mail?thread=#[Read]"
    Then the mail actions are "Archive, Snooze, Make a task, Star, Mark unread, Spam, Delete"
    And the mail sender says "visitor@example.com isn’t in Contacts · via the contact form"
    And the mail reader shows a link "Add to Contacts" to "/admin/contacts/new?email=visitor@example.com"
    When I visit the mail page "/admin/mail?folder=spam&thread=#[Junk]"
    Then the mail actions are "Not spam, Delete forever"
    When I visit the mail page "/admin/mail?folder=snoozed&thread=#[Later]"
    Then the mail actions are "Archive, Wake, Make a task, Star, Mark unread, Spam, Delete"

  Scenario: The reader marks spam, snoozes, wakes and deletes a thread
    Given I am signed in to the admin
    And the mail threads:
      | subject | snoozed hours |
      | Pest    |               |
      | Later   |               |
      | Sleepy  | 1             |
      | Gone    |               |
    When I post to the mail route "/admin/mail/#[Pest]/change/spam" with:
      """
      folder=inbox
      show=all
      """
    Then the mail answer goes to "/admin/mail?folder=inbox&show=all&thread=#[Pest]#read-#[Pest]"
    And the mail thread "Pest" is now spam
    When I post to the mail route "/admin/mail/#[Later]/snooze" with:
      """
      pick=%[a day from now]
      folder=inbox
      """
    Then the mail answer goes to a page starting "/admin/mail?folder=inbox&show=all&thread=#[Later]"
    And the mail thread "Later" is now snoozed
    When I post to the mail route "/admin/mail/#[Sleepy]/wake" with:
      """
      folder=snoozed
      """
    Then the mail thread "Sleepy" is now awake
    When I post to the mail route "/admin/mail/#[Gone]/delete" with:
      """
      folder=spam
      show=all
      """
    Then the mail answer goes to "/admin/mail?folder=spam&show=all"
    And the mail thread "Gone" is now gone

  Scenario: Archiving from the reader on a later page keeps that page
    Given I am signed in to the admin
    And 301 older mail threads
    When I visit the mail page "/admin/mail?page=3&thread=#[Older 250]"
    And I submit the mail reader form "Archive"
    Then the mail answer goes to a page with "page=3"
    And the mail thread "Older 250" is now archived

  Scenario: Archiving the last thread on the last page steps back a page
    Given I am signed in to the admin
    And 201 older mail threads
    When I visit the mail page "/admin/mail?page=3&thread=#[Older 201]"
    And I submit the mail reader form "Archive"
    Then the mail answer goes to a page with "page=2"
