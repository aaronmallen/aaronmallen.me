Feature: The editor as you type
  The editor counts words, inserts Markdown, previews the post and its slug, and switches between Write and Preview.

  Background:
    Given I am signed in to the admin
    And I open a new post

  Scenario Outline: Each toolbar button inserts its snippet
    When I press the "<tool>" editor tool
    Then the post body holds "<snippet>"

    Examples:
      | tool        | snippet                     |
      | H2 heading  | \n\n##{space}          |
      | Bold        | **bold**                    |
      | Italic      | *italic*                    |
      | Code block  | \n\n```ruby\n\n```          |
      | Quote       | \n\n>{space}           |

  Scenario: A snippet goes in at the cursor or over the picked text
    When I fill in the post "Body" with "hello world"
    And I put the body cursor from 6 to 6
    And I press the "Bold" editor tool
    Then the post body holds "hello **bold**world"
    When I fill in the post "Body" with "hello world"
    And I put the body cursor from 6 to 11
    And I press the "Italic" editor tool
    Then the post body holds "hello *italic*"

  Scenario: The editor counts words and read time as you type, leaving Markdown marks out
    When I press the "Bold" editor tool
    Then the post word count reads "1 word"
    When I fill in the post "Body" with "one two three"
    Then the post word count reads "3 words"
    When I fill in the post "Body" with "## one --- two"
    Then the post word count reads "2 words"
    And I fill in the post body with 700 words
    Then the post read time reads "~3 min read"

  Scenario: The summary label shows above its field
    Then the post summary label reads "SUMMARY"

  Scenario: Preview hides the body and toolbar and Write brings them back
    Then the editor shows Write
    When I pick the "Preview" editor tab
    Then the editor shows Preview
    And the post body stays in the form
    When I pick the "Write" editor tab
    Then the editor shows Write

  Scenario: The arrow keys switch the tab
    When I pick the "Write" editor tab
    And I press the right arrow on the editor tabs
    Then the editor shows Preview

  Scenario: A body keeps every character across a round trip and saves from Preview
    When I fill in the post "Title" with "Hello"
    And I fill in the post body with:
      """
      # One

        two

      three
      """
    And I pick the "Preview" editor tab
    And I pick the "Write" editor tab
    Then the post body holds:
      """
      # One

        two

      three
      """
    When I fill in the post body with "two words  " exactly
    And I pick the "Preview" editor tab
    And I press the post button "Save draft"
    Then the post toast says "Draft saved"
    And the body of the post "Hello" is "two words  "

  Scenario: The slug preview turns titles into slugs the way the server does
    Then the editor's slug preview turns each title into its slug:
      | title                        | slug                |
      | Hello, World!                | hello-world         |
      | Ruby 3.4 & Rails             | ruby-3-4-rails      |
      | 2026: A Year                 | 2026-a-year         |
      | Café au lait                 | cafe-au-lait        |
      | Crème Brûlée                 | creme-brulee        |
      | naïve--résumé                | naive-resume        |
      | Ünïcödé_under_score          | unicode-under-score |
      | Ｆｕｌｌｗｉｄｔｈ           | fullwidth           |
      | ﬁle ﬂow                      | file-flow           |
      | İstanbul                     | istanbul            |
      | Straße                       | stra-e              |
      | 日本語 post                  | post                |
      | ---trim---                   | trim                |

  Scenario Outline: The server slugs each title as the slug preview does
    When I send the post form to "/admin/posts" with:
      | intent      | draft   |
      | post[title] | <title> |
    Then the posts table has a row with:
      | slug   |
      | <slug> |

    Examples:
      | title                                      | slug                |
      | Hello, World!                              | hello-world         |
      |   Ruby 3.4 & Rails     | ruby-3-4-rails      |
      | 2026: A Year                               | 2026-a-year         |
      | Café au lait                               | cafe-au-lait        |
      | Crème Brûlée                               | creme-brulee        |
      | naïve--résumé                              | naive-resume        |
      | Ünïcödé_under_score                        | unicode-under-score |
      | Ｆｕｌｌｗｉｄｔｈ                         | fullwidth           |
      | ﬁle ﬂow                                    | file-flow           |
      | İstanbul                                   | istanbul            |
      | Straße                                     | stra-e              |
      | 日本語 post                                | post                |
      | ---trim---                                 | trim                |

  Scenario: The preview shows the body and title typed on Write
    When I fill in the post "Title" with "A fresh title"
    And I fill in the post "Body" with "Hello *there*"
    And I pick the "Preview" editor tab
    Then the post preview shows "there" as the emphasis
    And the post preview shows "A fresh title" as the title

  Scenario: The preview sets the title and body in the public post's type
    When I fill in the post "Title" with "A title"
    And I fill in the post body with:
      """
      ## Heading

      one two
      """
    And I press the post button "Publish"
    And I open a new post
    And I fill in the post "Title" with "A title"
    And I fill in the post body with:
      """
      ## Heading

      one two
      """
    And I pick the "Preview" editor tab
    Then the editor preview sets type as the post page "/writing/a-title" does

  Scenario: The preview asks the server only when it shows and something changed
    Given I count the post previews asked for
    When I type "one two three" into the post field "Body"
    Then the post word count reads "3 words"
    And the post previews asked for number 0
    When I pick the "Preview" editor tab
    Then the post preview shows "one two three" as the body
    And the post previews asked for number 1
    When I pick the "Write" editor tab
    And I pick the "Preview" editor tab
    Then the post previews asked for number 1
    When I type "one two" into the post field "Title"
    Then the post preview shows "one two" as the title
    And the post previews asked for number 2

  Scenario: A late answer to an earlier preview does not replace a later one
    When I pick the "Preview" editor tab
    And I hold the next post preview while I retitle the post "stale words" then "fresh words"
    Then the post preview shows "fresh words" as the title

  Scenario: The cross-post counts follow what you type
    Given Mastodon and Bluesky are connected for cross-posts
    And I open a new post
    Then the cross-post counts read "Mastodon 0/500, Bluesky 0/300, LinkedIn 0/3000"
    And the post field "Cross-post text" suggests "The title and link land here once you name the post."
    When I fill in the post details "Cross-post text" with "hello"
    Then the cross-post counts read "Mastodon 5/500, Bluesky 5/300, LinkedIn 5/3000"
    When I fill in the post details "Cross-post text" with "Read {link} and tell me"
    Then the cross-post counts read "Mastodon 40/500, Bluesky 65/300, LinkedIn 66/3000"
    When I fill in the post details "Cross-post text" with "👍🏽 👨‍👩‍👧 done"
    Then the cross-post counts read "Mastodon 8/500, Bluesky 8/300, LinkedIn 8/3000"
    When I fill in the post details "Cross-post text" with "{301 a}"
    Then the cross-post count for Bluesky is over
    And the cross-post count for Mastodon is not over
    When I pick the "Bluesky" network in the post details
    Then the cross-post count for Bluesky is off

  Scenario: The cross-post counts a mention as the handle each network gets
    Given Mastodon and Bluesky are connected for cross-posts
    And the people table holds:
      | key | name         | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | ada.bsky.social | did:plc:ada |
    And I open a new post
    When I fill in the post details "Cross-post text" with "hi @{ada}"
    Then the cross-post counts read "Mastodon 15/500, Bluesky 19/300, LinkedIn 15/3000"

  Scenario: The cross-post box previews the title and link as you name the post, saving nothing
    Given Mastodon and Bluesky are connected for cross-posts
    And I open a new post
    When I fill in the post "Title" with "A fresh title"
    Then the cross-post box suggests the title "A fresh title" and the link "a-fresh-title"
    And the cross-post counts read "Mastodon 38/500, Bluesky 71/300, LinkedIn 72/3000"
    When I fill in the post details "Slug" with "chosen"
    Then the cross-post box suggests the title "A fresh title" and the link "chosen"
    When I fill in the post details "Cross-post text" with "hello"
    Then the cross-post counts read "Mastodon 5/500, Bluesky 5/300, LinkedIn 5/3000"
    And the posts table holds 0 rows
    When I fill in the post details "Cross-post text" with ""
    And I fill in the post "Title" with "{301 a}"
    Then the cross-post count for Bluesky is over
