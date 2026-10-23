Feature: Admin mail settings
  Mail settings pick which accounts show and send, and which threads reach
  Waiting in the inbox.

  Background:
    Given I am signed in to the admin
    And the mail account "aaron@work.example"

  Scenario: The settings show and send from each Gmail account and only show the contact form
    Given the mail threads:
      | subject   |
      | From form |
    When I visit "/admin/mail"
    Then the page links "Mail settings" to the mail page "/admin/mail/settings"
    When I visit "/admin/mail/settings"
    Then the mail head says "Pick which accounts show and send, and which threads reach Waiting."
    And the mail settings tick "accounts[@[aaron@work.example]][shown]"
    And the mail settings tick "accounts[@[aaron@work.example]][sends]"
    And the mail settings tick "accounts[@[contact form]][shown]"
    And the mail settings have no "accounts[@[contact form]][sends]" box
    And the mail settings tick "settings[needs_reply]"
    And the mail settings tick "settings[starred]"
    And the mail settings leave "settings[important]" unticked
    And no mail settings are stored
    And the page has no axe breaches in light or dark

  Scenario: A changed setting saves at once and says so
    When I visit "/admin/mail/settings"
    And I untick "settings[starred]" in the mail settings
    Then the mail toast says "Mail settings saved"
    And the mail settings store "starred" as false
    When I post to the mail route "/admin/mail/settings" with:
      """
      settings[important]=1
      """
    And I follow the mail answer
    Then the mail settings tick "settings[important]"
    When I post to the mail route "/admin/mail/settings" with:
      """
      accounts[@[aaron@work.example]][shown]=1
      accounts[@[aaron@work.example]][sends]=0
      """
    Then the mail account "aaron@work.example" now sends no mail

  Scenario: An account turned off hides from Mail and Waiting until it is turned on
    Given the mail threads:
      | subject         | account            | starred |
      | Starred at work | aaron@work.example | yes     |
      | From the form   | contact form       |         |
    When I post to the mail route "/admin/mail/settings" with:
      """
      accounts[@[aaron@work.example]][shown]=0
      """
    And I visit "/admin/mail"
    Then the mail list shows "From the form"
    And the mail account picker does not offer "aaron@work.example"
    And Waiting holds the mail "From the form"
    When I post to the mail route "/admin/mail/settings" with:
      """
      accounts[@[aaron@work.example]][shown]=1
      """
    Then Waiting holds the mail "Starred at work, From the form"

  Scenario: The settings count the threads that wait now
    Given the mail threads:
      | subject | status |
      | First   |        |
      | Second  |        |
      | Read    | read   |
    Then Waiting holds the mail "First, Second"
    When I visit "/admin/mail/settings"
    Then the mail settings hint says "2 threads wait now."

  Scenario: Each Waiting rule lets threads in, says why, and keeps them out once off
    Given the contact "Countess of Lovelace" at the mail address "ada@example.com"
    And the mail label "needs-reply" on "aaron@work.example"
    And the mail threads:
      | subject     | account            | from         | reply to            | status | starred | labels      |
      | From form   | contact form       |              |                     |        |         |             |
      | From Ada    | aaron@work.example | Ada Lovelace | ADA@example.com     |        |         |             |
      | Needs reply | aaron@work.example |              | someone@example.com |        |         | needs-reply |
      | Starred     | aaron@work.example |              | someone@example.com | read   | yes     |             |
    Then Waiting holds the mail "From form, From Ada, Needs reply, Starred"
    And Waiting says the mail thread "From form" waits for "contact form"
    And Waiting says the mail thread "From Ada" waits for "from Contacts"
    And Waiting says the mail thread "Needs reply" waits for "label: needs-reply"
    And Waiting says the mail thread "Starred" waits for "starred"
    When I post to the mail route "/admin/mail/settings" with:
      """
      settings[contact_form]=0
      """
    Then Waiting holds the mail "From Ada, Needs reply, Starred"
    When I post to the mail route "/admin/mail/settings" with:
      """
      settings[people]=0
      """
    Then Waiting holds the mail "Needs reply, Starred"
    When I post to the mail route "/admin/mail/settings" with:
      """
      settings[needs_reply]=0
      """
    Then Waiting holds the mail "Starred"
    When I post to the mail route "/admin/mail/settings" with:
      """
      settings[starred]=0
      """
    Then Waiting holds the mail ""

  Scenario: Gmail's important mail waits only once its rule is on
    Given the mail threads:
      | subject | account            | reply to            | important |
      | Hello   | aaron@work.example | someone@example.com | yes       |
    Then Waiting holds the mail ""
    When I post to the mail route "/admin/mail/settings" with:
      """
      settings[important]=1
      """
    Then Waiting holds the mail "Hello"
    And Waiting says the mail thread "Hello" waits for "Gmail: important"

  Scenario: Mail that meets no rule stays on Mail alone
    Given the contact "Ada Lovelace" at the mail address "ada@example.com"
    And the mail threads:
      | subject   | account            | from         | reply to             | starred | archived |
      | Just mail | aaron@work.example |              | someone@example.com  |         |          |
      | Imposter  | aaron@work.example | Ada Lovelace | imposter@example.com |         |          |
      | Filed     | aaron@work.example |              | someone@example.com  | yes     | yes      |
    Then Waiting holds the mail ""
    When I visit "/admin/mail"
    Then the mail list holds "Just mail, Imposter"

  Scenario: Notifications from GitHub, Linear and Docs wait only once told to
    Given the mail threads:
      | subject | account            | reply to                           | starred |
      | GitHub  | aaron@work.example | notifications@github.com           | yes     |
      | Linear  | aaron@work.example | notifications@linear.app           | yes     |
      | Docs    | aaron@work.example | comments-noreply@docs.google.com   | yes     |
      | Drive   | aaron@work.example | drive-shares-dm-noreply@google.com | yes     |
    Then Waiting holds the mail ""
    When I post to the mail route "/admin/mail/settings" with:
      """
      settings[skip_notifications]=0
      """
    Then Waiting holds the mail "GitHub, Linear, Docs, Drive"

  Scenario: The nav and Today count what waits as Waiting does
    Given the mail threads:
      | subject       | account            | reply to            | starred |
      | Starred       | aaron@work.example | someone@example.com | yes     |
      | Just mail     | aaron@work.example | someone@example.com |         |
      | From the form | contact form       |                     |         |
    When I visit "/admin"
    Then the command palette counts "2 waiting" for the inbox
    And Today counts "2 waiting →" for the inbox
    And the page has no axe breaches in light or dark
    And Waiting holds the mail "Starred, From the form"
