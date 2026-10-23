Feature: Admin mail sending
  Compose and reply send mail through Gmail from an account allowed to send,
  and keep what I wrote when a send cannot go.

  Background:
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the Google account "aaron@work.example" is connected with "openid gmail.modify gmail.send"

  Scenario: Compose offers only the accounts allowed to send
    Given the mail account "aaron@home.example"
    And the Google account "aaron@home.example" is connected with "openid gmail.modify"
    And the mail account "aaron@side.example" that may not send
    And the Google account "aaron@side.example" is connected with "openid gmail.modify gmail.send"
    And the mail account "aaron@old.example"
    And the Google account "aaron@old.example" is connected with "openid gmail.modify gmail.send"
    And the Google connection for "aaron@old.example" is revoked
    When I visit "/admin/mail"
    Then the mail compose offers to send from "aaron@work.example"
    And the mail compose is closed

  Scenario: Compose opens from a link and fills the address a contact page sends
    When I visit "/admin/mail?compose=1&to=ada@example.com"
    Then the mail compose is open
    And the mail compose field "to" holds "ada@example.com"
    And the page has no axe breaches in light or dark

  Scenario: Compose suggests contacts in To and adds the signature
    Given the contact "Ada Lovelace" at the mail address "ada@example.com, ada@work.example"
    And the contact "Charles Babbage" with no mail address
    And the mail account "aaron@work.example" signs with "<b>Aaron</b>"
    When I visit "/admin/mail"
    Then the mail compose To field says "name or address · Contacts autocomplete"
    And the mail compose To field suggests:
      | ada@example.com  | Ada Lovelace |
      | ada@work.example | Ada Lovelace |
    And the mail compose signs with "Aaron" and can drop it
    And the mail compose says "sends through Gmail"

  Scenario: With no account that may send, compose and reply say so in place of From
    Given the mail account "aaron@work.example" is set not to send
    And the mail threads:
      | subject | account            | gmail id | reply to        |
      | Engines | aaron@work.example | t1       | ada@example.com |
    When I visit the mail page "/admin/mail?thread=#[Engines]"
    Then mail cannot be sent from any account

  Scenario: A new mail goes through Gmail from the picked account and shows in Sent
    Given Gmail sends mail into the thread "t9"
    When I visit "/admin/mail"
    Then the mail compose says "sends through Gmail"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com, bob@example.com
      mail[cc]=cy@example.com
      mail[bcc]=di@example.com
      mail[subject]=Engines
      mail[html]=<p>Hi</p>
      """
    Then Gmail got mail at POST "/messages/send" with the header "From: aaron@work.example"
    And Gmail got mail at POST "/messages/send" with the header "To: ada@example.com, bob@example.com"
    And Gmail got mail at POST "/messages/send" with the header "Cc: cy@example.com"
    And Gmail got mail at POST "/messages/send" with the header "Bcc: di@example.com"
    And Gmail got mail at POST "/messages/send" with the header "Subject: Engines"
    And Gmail got mail at POST "/messages/send" in a new thread
    And the Gmail thread "t9" shows here as sent
    And the Gmail thread "t9" sits on the mail account "aaron@work.example"
    And the mail toast says "Sent"

  Scenario: Sent HTML keeps the editor's formatting and drops everything else
    Given Gmail sends mail into the thread "t9"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Engines
      mail[html]=<p onclick="x()">Hi <script>alert(1)</script><a href="https://x.example" style="c">y</a><a href="javascript:alert(1)">z</a></p>
      """
    Then Gmail got mail at POST "/messages/send" with the HTML '<p>Hi <a href="https://x.example">y</a><a>z</a></p>'
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Engines
      mail[html]=<p><b>b</b><i>i</i><u>u</u><s>s</s></p><ul><li>a</li></ul><ol><li>n</li></ol><blockquote>q</blockquote><code>c</code>
      """
    Then Gmail got mail at POST "/messages/send" with the HTML "<p><b>b</b><i>i</i><u>u</u><s>s</s></p><ul><li>a</li></ul><ol><li>n</li></ol><blockquote>q</blockquote><code>c</code>"
    And Gmail got mail at POST "/messages/send" holding "text/plain"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Engines
      mail[body]=One%0Aline%0A%0ATwo
      """
    Then Gmail got mail at POST "/messages/send" with the HTML "<p>One<br>line</p><p>Two</p>"

  Scenario: Sent headers stay on one line and encode text beyond ASCII
    Given Gmail sends mail into the thread "t9"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Café
      mail[html]=<p>Hi</p>
      """
    Then Gmail got mail at POST "/messages/send" with the header "Subject: =?UTF-8?B?Q2Fmw6k=?="
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Engines%0D%0ABcc: eve@example.com
      mail[html]=<p>Hi</p>
      """
    Then Gmail got mail at POST "/messages/send" with no "Bcc" header

  Scenario: The signature goes out unless I remove it
    Given Gmail sends mail into the thread "t9"
    And the mail account "aaron@work.example" signs with "<b>Aaron</b>"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Engines
      mail[html]=<p>Hi</p>
      mail[signature]=1
      """
    Then Gmail got mail at POST "/messages/send" with the HTML "<p>Hi</p><br><b>Aaron</b>"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Engines
      mail[html]=<p>Hi</p>
      """
    Then Gmail got mail at POST "/messages/send" with the HTML "<p>Hi</p>"

  Scenario: A send from an account that may not send reopens compose with what I wrote
    Given the mail account "aaron@home.example" that may not send
    And the Google account "aaron@home.example" is connected with "openid gmail.modify gmail.send"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@home.example]
      mail[to]=ada@example.com
      mail[subject]=Engines
      mail[html]=<p>Keep me</p>
      """
    Then the mail answer has status 422
    When I look at the mail answer
    Then the mail compose is open
    And the mail compose flags "from" with "Pick an account that may send."
    And the mail compose keeps the HTML "<p>Keep me</p>"

  Scenario: A send that cannot go names what is wrong
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=
      mail[subject]=Engines
      mail[html]=<p> </p>
      """
    Then the mail answer shows "Add someone to send to."
    And the mail answer shows "Write something first."
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com, nobody
      mail[subject]=%[201 letters]
      mail[html]=<p>Hi</p>
      """
    Then the mail answer shows "Keep the subject to 200 characters."
    And the mail answer shows "Use email addresses split by commas."
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[cc]=nobody
      mail[subject]=Engines
      mail[html]=<p>Hi</p>
      """
    And I look at the mail answer
    Then the mail compose flags "cc" with "Use email addresses split by commas."

  Scenario: A send Gmail refuses says so
    Given Gmail answers POST "/users/me/messages/send" with status 500
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Engines
      mail[html]=<p>Hi</p>
      """
    Then the mail answer shows "Gmail would not send it. Try again."

  Scenario: A reply goes out in the same Gmail thread and answers the last message received
    Given the mail threads:
      | subject | account            | gmail id | reply to        | message gmail id |
      | Engines | aaron@work.example | t1       | ada@example.com | m1               |
    And the mail thread "Engines" has the messages:
      | message gmail id | draft | minutes ago |
      | m2               | yes   | -1          |
    And Gmail sends mail into the thread "t1"
    And Gmail answers GET "/users/me/messages/m1" with:
      """
      {"payload": {"headers": [{"name": "Message-ID", "value": "<m1@mail.example>"}]}}
      """
    When I visit the mail page "/admin/mail?thread=#[Engines]"
    Then the mail reply goes to "ada@example.com" as "Re: Engines"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Re: Engines
      mail[html]=<p>Yes</p>
      mail[thread]=#[Engines]
      thread=#[Engines]
      """
    Then Gmail got mail at POST "/messages/send" in the thread "t1"
    And Gmail got mail at POST "/messages/send" with the header "In-Reply-To: <m1@mail.example>"
    And Gmail got mail at POST "/messages/send" with the header "References: <m1@mail.example>"
    And the mail answer goes to a page with "thread=#[Engines]#read-#[Engines]"

  Scenario: Send & archive archives the thread in Gmail, and a failed archive still counts the send
    Given the mail threads:
      | subject | account            | gmail id | reply to        | message gmail id |
      | Engines | aaron@work.example | t1       | ada@example.com | m1               |
    And Gmail sends mail into the thread "t1"
    And Gmail takes changes to the mail threads "t1"
    And Gmail answers GET "/users/me/messages/m1" with:
      """
      {"payload": {"headers": [{"name": "Message-ID", "value": "<m1@mail.example>"}]}}
      """
    And Gmail answers GET "/users/me/messages/s1" with:
      """
      {"payload": {"headers": [{"name": "Message-ID", "value": "<s1@mail.example>"}]}}
      """
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Re: Engines
      mail[html]=<p>Yes</p>
      mail[thread]=#[Engines]
      mail[archive]=1
      thread=#[Engines]
      """
    Then Gmail received POST "/users/me/threads/t1/modify" holding '{"removeLabelIds":["INBOX"]}'
    And the mail toast says "Sent and archived"
    Given Gmail refuses changes to the mail thread "t1"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Re: Engines
      mail[html]=<p>Yes</p>
      mail[thread]=#[Engines]
      mail[archive]=1
      thread=#[Engines]
      """
    Then the mail answer has status 302

  Scenario: A reply that fails stays open with what I wrote
    Given the mail threads:
      | subject | account            | gmail id | reply to        |
      | Engines | aaron@work.example | t1       | ada@example.com |
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=ada@example.com
      mail[subject]=Re: Engines
      mail[html]=
      mail[thread]=#[Engines]
      thread=#[Engines]
      """
    And I look at the mail answer
    Then the mail reply stays open from "aaron@work.example"
    And the mail compose is closed

  Scenario: The reply says when the thread's account cannot send
    Given the mail account "aaron@home.example"
    And the Google account "aaron@home.example" is connected with "openid gmail.modify"
    And the mail threads:
      | subject | account            | gmail id | reply to        |
      | At home | aaron@home.example | t2       | ada@example.com |
    When I visit the mail page "/admin/mail?thread=#[At home]"
    Then the mail reply hints "aaron@home.example can’t send · grant it on Connected services"

  Scenario: A reply to a contact form thread goes out by email in a new thread
    Given the mail threads:
      | subject | reply to            |
      | Hello   | visitor@example.com |
    And Gmail sends mail into the thread "t9"
    When I visit the mail page "/admin/mail?thread=#[Hello]"
    Then the mail reply hints "sent from the contact form · the reply goes out by email"
    When I post to the mail route "/admin/mail/send" with:
      """
      mail[from]=@[aaron@work.example]
      mail[to]=visitor@example.com
      mail[subject]=Re: Hello
      mail[html]=<p>Thanks</p>
      mail[thread]=#[Hello]
      mail[archive]=1
      """
    Then Gmail got mail at POST "/messages/send" with the header "To: visitor@example.com"
    And Gmail got mail at POST "/messages/send" in a new thread
    And the Gmail thread "t9" shows here as sent
    And the mail thread "Hello" is now archived
