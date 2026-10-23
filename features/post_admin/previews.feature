Feature: Previews the editor asks the server for
  The editor asks the server to render the post as readers will see it and to write the cross-post text, saving nothing.

  Background:
    Given I am signed in to the admin
    And I open a new post

  Scenario: The post preview answers with the rendered post and no layout
    When I ask the admin to preview "the post" with:
      | title |   Hello   |
      | body  | one two                       |
      | tags  |  ruby, hanami,, ruby  |
    Then the post admin answers 200
    And the preview answer has type text/html
    And the preview answer starts with "<header"
    And the API answer does not hold "<main"
    And the API answer holds "<h2 class=\"post-title\">Hello</h2>"
    And the preview answer links the tags "ruby, hanami" to their pages

  Scenario: The post preview leaves out a blank title and renders with no fields
    When I ask the admin to preview "the post" with:
      | title |   |
      | body  | one    |
    Then the API answer does not hold "post-title"
    When I ask the admin to preview "the post" with:
      | body |  |
    Then the API answer holds "class=\"prose"

  Scenario: The post preview shows the read time
    When I ask the admin to preview "the post" with words:
      | body | 700 |
    Then the API answer holds "3 min read"

  Scenario: The post preview dates the post by its Chicago publish time
    When I ask the admin to preview "the post" with:
      | publish_at | 2030-09-07T22:30 |
    Then the API answer holds "datetime=\"2030-09-07T22:30:00-05:00\""
    And the API answer holds "Sep 7, 2030"

  Scenario Outline: The post preview dates the post today when the publish time will not do
    When I ask the admin to preview "the post" with:
      | publish_at | <publish at> |
    Then today is the date on the post preview

    Examples:
      | publish at       |
      |             |
      | soon             |
      | 2027-03-14T02:30 |

  Scenario: The post preview renders the body as the public post does
    When I fill in the post "Title" with "Hello"
    And I fill in the post body with:
      """
      ## Heading

      `code` and *emphasis*

      ```ruby
      puts :hi
      ```

      > quote <b>tag</b>
      """
    And I press the post button "Publish"
    And I pick the "Preview" editor tab
    Then the post page "/writing/hello" renders the body as the editor preview did

  Scenario Outline: A preview with no CSRF token is refused
    When I ask the admin to preview "<kind>" with:
      | _csrf_token | none  |
      | title       | Hello |
    Then the post admin answers 403

    Examples:
      | kind           |
      | the post       |
      | the cross-post |

  Scenario: The cross-post preview answers with the title and link as plain text
    When I ask the admin to preview "the cross-post" with:
      | title | Hello |
      | slug  | hello |
    Then the post admin answers 200
    And the preview answer has type text/plain
    And the preview answer is the title "Hello" and the link "hello"
    And the posts table holds 0 rows

  Scenario: The cross-post preview takes the slug the save would derive
    When I ask the admin to preview "the cross-post" with:
      | title | Hello There |
      | slug  |             |
    Then the preview answer is the title "Hello There" and the link "hello-there"

  Scenario: The cross-post preview answers with nothing for a blank title or no fields
    When I ask the admin to preview "the cross-post" with:
      | title |   |
      | slug  | hello  |
    Then the preview answer is empty
    When I ask the admin to preview "the cross-post" with:
      | slug |  |
    Then the preview answer is empty

  Scenario: A signed out visitor gets no preview
    Given I sign out of the admin
    When I ask the admin to preview "the post" from the sign-in page with:
      | title | Hello |
    Then the API answer does not hold "post-title"
    And the page has no axe breaches in light or dark
