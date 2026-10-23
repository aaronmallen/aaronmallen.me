Feature: Admin mail compose editor
  The compose editor formats text from its toolbar and keys, cleans pasted
  HTML, and saves a draft to Gmail as I type.

  Background:
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the Google account "aaron@work.example" is connected with "openid gmail.modify gmail.send"
    And Gmail saves drafts as "r1" into the thread "t5"

  Scenario: Each toolbar button formats the selection
    When I open mail compose
    And I write "word" in the mail editor and select it
    And I click the mail editor tool "Bold"
    Then the mail HTML holds "<b"
    And the mail editor tool "Bold" is pressed
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Italic"
    Then the mail HTML holds "<i"
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Underline"
    Then the mail HTML holds "<u"
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Strikethrough"
    Then the mail HTML holds "<strike"
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Bulleted list"
    Then the mail HTML holds "<ul"
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Numbered list"
    Then the mail HTML holds "<ol"
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Quote"
    Then the mail HTML holds "<blockquote"
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Code"
    Then the mail HTML holds "<code"
    And the page has no axe breaches in light or dark

  Scenario: Each key formats the selection
    When I open mail compose
    And I write "word" in the mail editor and select it
    And I press "Control+b" in the mail editor
    Then the mail HTML holds "<b"
    When I write "word" in the mail editor and select it
    And I press "Control+i" in the mail editor
    Then the mail HTML holds "<i"
    When I write "word" in the mail editor and select it
    And I press "Control+u" in the mail editor
    Then the mail HTML holds "<u"
    When I write "word" in the mail editor and select it
    And I press "Control+Shift+X" in the mail editor
    Then the mail HTML holds "<strike"
    When I write "word" in the mail editor and select it
    And I press "Control+Shift+Digit8" in the mail editor
    Then the mail HTML holds "<ul"
    When I write "word" in the mail editor and select it
    And I press "Control+Shift+Digit7" in the mail editor
    Then the mail HTML holds "<ol"
    When I write "word" in the mail editor and select it
    And I press "Control+Shift+Digit9" in the mail editor
    Then the mail HTML holds "<blockquote"
    When I write "word" in the mail editor and select it
    And I press "Control+e" in the mail editor
    Then the mail HTML holds "<code"

  Scenario: Clear formatting drops formatting from the button and the key
    When I open mail compose
    And I write "word" in the mail editor and select it
    And I click the mail editor tool "Bold"
    And I select everything in the mail editor
    And I click the mail editor tool "Clear formatting"
    Then the mail HTML does not hold "<b>"
    When I write "word" in the mail editor and select it
    And I click the mail editor tool "Bold"
    And I select everything in the mail editor
    And I press "Control+Backslash" in the mail editor
    Then the mail HTML does not hold "<b>"

  Scenario: The link tool links the selection, and an address as mail
    When I open mail compose
    And I write "word" in the mail editor and select it
    And I click the mail editor tool "Link"
    And I link the mail selection to "example.com" with the button
    Then the mail HTML holds '<a href="https://example.com">word</a>'
    When I write "word" in the mail editor and select it
    And I press "Control+k" in the mail editor
    And I link the mail selection to "ada@example.com" with Enter
    Then the mail HTML holds '<a href="mailto:ada@example.com">word</a>'

  Scenario: Pasted HTML keeps only a link's href
    When I open mail compose
    And I paste into the mail editor the HTML:
      """
      <p onclick="x()" style="color:red">Hi<script>alert(1)</script><a href="https://a.example" class="c">a</a><a href="javascript:alert(1)">b</a></p>
      """
    Then the mail HTML holds '<a href="https://a.example">a</a>'
    And the mail HTML does not hold "script"
    And the mail HTML does not hold "onclick"
    And the mail HTML does not hold "style"
    And the mail HTML does not hold "class"
    And the mail HTML does not hold "javascript"

  Scenario: Cc and Bcc show on demand, and attached files are named
    When I open mail compose
    Then the mail compose shows no cc field
    When I show the mail cc field
    Then the mail compose shows the cc field
    When I attach the file "plan.csv" to the mail
    Then the mail compose names the files "plan.csv"

  Scenario: Compose saves a draft to Gmail once I stop typing
    When I open mail compose
    And I address the mail to "ada@example.com" about "Engines"
    Then the mail compose says the draft saved
    And the mail compose field "draft" holds "r1"

  Scenario: Compose says when the draft did not save, and saves again later
    Given the mail draft route answers with status 500
    When I open mail compose
    And I address the mail to "ada@example.com" about "Engines"
    Then the mail compose says "draft not saved"
    When the mail draft route works again
    And I address the mail to "ada@example.com" about "Engines, again"
    Then the mail compose says the draft saved

  Scenario: Compose says the draft did not save when the request gets no answer
    When I open mail compose
    And the browser loses its network for mail
    And I address the mail to "ada@example.com" about "Engines"
    Then the mail compose says "draft not saved"

  Scenario: Ctrl+Enter sends the mail
    Given Gmail sends mail into the thread "t9"
    When I open mail compose
    And I address the mail to "ada@example.com" about "Engines"
    And I type "Hello" in the mail editor and press "Control+Enter"
    Then the mail toast says "Sent"

  Scenario: A resumed draft fills compose and asks Gmail for it once
    Given the mail threads:
      | subject | account            | gmail id | draft |
      | Plans   | aaron@work.example | t5       | yes   |
    And Gmail answers GET "/users/me/drafts" with:
      """
      {"drafts": [{"id": "r1", "message": {"id": "d1", "threadId": "t5"}}]}
      """
    And Gmail answers GET "/users/me/drafts/r1" with:
      """
      {"id": "r1", "message": {"id": "d1", "threadId": "t5", "labelIds": ["DRAFT"], "internalDate": "1790000000000",
        "payload": {"mimeType": "multipart/alternative",
                    "headers": [{"name": "To", "value": "ada@example.com"}, {"name": "Subject", "value": "Engines"}],
                    "parts": [{"mimeType": "text/html", "filename": "", "headers": [], "body": {"data": "PHA-U29vbjwvcD4"}}]}}}
      """
    When I visit the mail page "/admin/mail?thread=#[Plans]&resume=1"
    Then the mail compose field "to" holds "ada@example.com"
    And the mail page address has no "resume"
    When I discard the mail draft
    And a new mail thread "Hello there" arrives
    Then Gmail got GET "/users/me/drafts" 1 time
