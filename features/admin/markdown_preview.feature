Feature: Markdown previews in the admin
  The admin renders Markdown through the post or task renderer and answers with the body alone, saving nothing.

  Background:
    Given I am signed in to the admin

  Scenario: A preview answers with the body alone and no layout
    When I preview through the "posts" Markdown renderer:
      """
      Hello *there*
      """
    Then the answer is 200
    And the preview answer starts with "<div class=\"post-body\">"
    And the API answer does not hold "<main"

  Scenario: The post renderer renders Markdown and drops raw HTML
    When I preview through the "posts" Markdown renderer:
      """
      Hello *there*
      """
    And I look at the answer as a page
    Then the page part ".post-body em" reads "there"
    When I preview through the "posts" Markdown renderer:
      """
      <details><summary>More</summary>hidden</details>
      """
    And I look at the answer as a page
    Then the page has ".post-body"
    And the page has no ".post-body details"

  Scenario: The task renderer keeps the raw HTML it allows
    When I preview through the "tasks" Markdown renderer:
      """
      <details><summary>More</summary>hidden</details>
      """
    And I look at the answer as a page
    Then the page part ".post-body details summary" reads "More"

  Scenario: The task renderer strips a raw script
    When I preview through the "tasks" Markdown renderer:
      """
      before

      <script>alert(1)</script>

      after
      """
    Then the API answer does not hold "<script"
    When I look at the answer as a page
    Then the page part ".post-body p:last-child" reads "after"

  Scenario: The task renderer keeps the site's own image and links a remote one
    When I preview through the "tasks" Markdown renderer:
      """
      ![own]({site}/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png) ![shot](https://example.com/shot.png)
      """
    And I look at the answer as a page
    Then the page has ".post-body img[src='{site}/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png'][alt='own']"
    And the page part ".post-body a[href='https://example.com/shot.png']" reads "shot"

  Scenario: A preview with no Markdown renders an empty body
    When I post to "/admin/markdown/preview/posts"
    And I look at the answer as a page
    Then the page has ".post-body"
    And the page part ".post-body" reads ""

  Scenario Outline: A renderer the admin does not know is refused
    When I preview through the "<renderer>" Markdown renderer:
      """
      Hello
      """
    Then the answer is 404

    Examples:
      | renderer |
      | html     |
      | tasksx   |
      | Posts    |

  Scenario: A preview with no CSRF token is refused
    When I post to "/admin/markdown/preview/posts" without a CSRF token
    Then the answer is 403

  Scenario: A signed out visitor is sent to sign in and gets no preview
    Given I sign out of the admin
    When I post the form "/admin/markdown/preview/posts" with the token from "/admin/sign-in" and:
      | _csrf_token | {token}       |
      | markdown    | Hello *there* |
    Then it redirects to a path ending in "/admin/sign-in"
    And the body does not include "<em>"
