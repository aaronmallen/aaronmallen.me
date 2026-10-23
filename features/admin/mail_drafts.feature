Feature: Admin mail drafts and attachments
  Compose saves drafts to Gmail, a stored draft opens again in compose, and
  attachments go out with mail and come down from Gmail.

  Background:
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the Google account "aaron@work.example" is connected with "openid gmail.modify gmail.send"

  Scenario: Saving a draft stores it in Gmail and shows it in Drafts
    Given Gmail saves drafts as "r1" into the thread "t5"
    When I post to the mail route "/admin/mail/draft" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Plans
      mail[html]=<p>Soon</p>
      """
    Then the mail answer holds the JSON:
      """
      {"draft": "r1"}
      """
    And Gmail got mail at POST "/drafts" with the header "To: ada@example.com"
    And Gmail got mail at POST "/drafts" with the header "Subject: Plans"
    And the Gmail thread "t5" shows here as draft
    When I post to the mail route "/admin/mail/draft" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Plans
      mail[html]=<p>Later</p>
      mail[draft]=r1
      """
    Then Gmail got PUT "/users/me/drafts/r1" 1 time

  Scenario: A draft Gmail lost starts again as a new draft
    Given Gmail saves drafts as "r1" into the thread "t5"
    And Gmail answers PUT "/users/me/drafts/gone" with status 404
    When I post to the mail route "/admin/mail/draft" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Plans
      mail[html]=<p>Soon</p>
      mail[draft]=gone
      """
    Then the mail answer holds the JSON:
      """
      {"draft": "r1"}
      """

  Scenario: Drafts refuse an account that may not send
    Given the mail account "aaron@home.example"
    When I post to the mail route "/admin/mail/draft" with:
      """
      mail[from]=@[aaron@home.example]
      mail[to]=ada@example.com
      mail[subject]=Plans
      mail[html]=<p>Soon</p>
      """
    Then the mail answer has status 422

  Scenario: Autosaving a stored draft rewrites the draft alone and shows its latest text
    Given the mail threads:
      | subject | account            | gmail id | draft | message gmail id |
      | Plans   | aaron@work.example | t5       | yes   | m1               |
    And the mail thread "Plans" has the messages:
      | message gmail id | draft |
      | d0               | yes   |
    And the messages of the mail thread "Plans" were stored an hour ago
    And Gmail answers PUT "/users/me/drafts/r1" with:
      """
      {"id": "r1", "message": {"id": "d1", "threadId": "t5"}}
      """
    And Gmail answers GET "/users/me/threads/t5" with:
      """
      {"id": "t5", "messages": [{"id": "m1", "threadId": "t5"}, {"id": "d1", "threadId": "t5"}]}
      """
    And Gmail answers GET "/users/me/messages/d1" with:
      """
      {"id": "d1", "threadId": "t5", "labelIds": ["DRAFT"], "internalDate": "1790000000000",
        "payload": {"mimeType": "multipart/alternative",
                    "headers": [{"name": "From", "value": "aaron@work.example"}, {"name": "Subject", "value": "Later"}],
                    "parts": [{"mimeType": "text/html", "filename": "", "headers": [], "body": {"data": "PHA-TGF0ZXI8L3A-"}}]}}
      """
    When I post to the mail route "/admin/mail/draft" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Later
      mail[html]=<p>Later</p>
      mail[draft]=r1
      """
    Then the Gmail thread "t5" holds the messages "d1, m1"
    And the Gmail message "m1" was not rewritten
    And the Gmail message "d1" reads "<p>Later</p>"
    And the Gmail thread "t5" reads "Later" as a draft

  Scenario: A stored draft opens in compose only when asked
    Given the mail threads:
      | subject | account            | gmail id | draft |
      | Plans   | aaron@work.example | t5       | yes   |
    When I visit the mail page "/admin/mail?thread=#[Plans]"
    Then the mail reader offers to edit the draft of "Plans"
    And the mail compose is closed
    Given Gmail answers GET "/users/me/drafts" with:
      """
      {"drafts": [{"id": "r1", "message": {"id": "d1", "threadId": "t5"}}]}
      """
    And Gmail answers GET "/users/me/drafts/r1" with:
      """
      {"id": "r1", "message": {"id": "d1", "threadId": "t5", "labelIds": ["DRAFT"], "internalDate": "1790000000000",
        "payload": {"mimeType": "multipart/alternative",
                    "headers": [{"name": "To", "value": "ada@example.com"}, {"name": "Cc", "value": "cy@example.com"},
                                {"name": "Subject", "value": "Engines"}],
                    "parts": [{"mimeType": "text/html", "filename": "", "headers": [], "body": {"data": "PHA-U29vbjwvcD4"}}]}}}
      """
    When I visit the mail page "/admin/mail?thread=#[Plans]&resume=1"
    Then the mail compose is open
    And the mail compose field "draft" holds "r1"
    And the mail compose field "to" holds "ada@example.com"
    And the mail compose field "cc" holds "cy@example.com"
    And the mail compose field "subject" holds "Engines"
    And the mail compose field "html" holds "<p>Soon</p>"

  Scenario: Sending a draft sends it through Gmail so it leaves Drafts
    Given the mail threads:
      | subject | account            | gmail id | draft |
      | Plans   | aaron@work.example | t5       | yes   |
    And Gmail sends the draft "r1" into the thread "t5"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Plans
      mail[html]=<p>Go</p>
      mail[draft]=r1
      """
    Then Gmail got mail at POST "/drafts/send" for the draft "r1"
    And the Gmail thread "t5" shows here as sent

  Scenario: A draft Gmail lost goes out as new mail
    Given Gmail answers POST "/users/me/drafts/send" with status 404
    And Gmail sends mail into the thread "t9"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Plans
      mail[html]=<p>Go</p>
      mail[draft]=gone
      """
    Then Gmail got POST "/users/me/messages/send" 1 time

  Scenario: An attachment goes out inside the mail
    Given Gmail sends mail into the thread "t9"
    When I send mail with the file "plan.csv" holding "one,two"
    Then Gmail got mail at POST "/messages/send" holding 'Content-Disposition: attachment; filename="plan.csv"'
    And Gmail got mail at POST "/messages/send" carrying the file "plan.csv" holding "one,two"

  Scenario: A received attachment lists on its message and downloads from Gmail
    Given the mail threads:
      | subject  | account            | gmail id | message gmail id |
      | The deck | aaron@work.example | t3       | m3               |
    And the mail thread "The deck" holds the attachment "deck.pdf" as part "1"
    And Gmail answers GET "/users/me/messages/m3" with:
      """
      {"id": "m3", "payload": {"mimeType": "multipart/mixed", "parts": [
        {"partId": "0", "mimeType": "text/plain", "filename": "", "body": {"data": "U2VlIGF0dGFjaGVk"}},
        {"partId": "1", "mimeType": "application/pdf", "filename": "deck.pdf", "body": {"attachmentId": "a1", "size": 2048}}]}}
      """
    And Gmail answers GET "/users/me/messages/m3/attachments/a1" with:
      """
      {"data": "JVBERg"}
      """
    When I visit the mail page "/admin/mail?thread=#[The deck]"
    Then the mail reader lists the attachment "deck.pdf" at "/admin/mail/messages/1/attachments/1"
    When I fetch the mail page "/admin/mail/messages/1/attachments/1"
    Then the mail answer is the file "deck.pdf" holding "%PDF"
    And the mail page "/admin/mail/messages/1/attachments/9" answers with status 404
