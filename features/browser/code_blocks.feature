Feature: Code blocks
  A fenced block renders highlighted, one line per source line, with no border inside, in the site's colors. A
  fence that names its file gets a caption with a file icon.

  Scenario Outline: A code block on the public post page renders highlighted in <scheme> mode
    Given the posts:
      | title | body                                                                                                                                                                                         |
      | Hello | ```ruby\nrequire "types"\n# app/actions/users/create.rb\nclass Create < Base\n  def call = Types::String.constructor { \|value\| value&.downcase&.strip }\n  NAME = "create"\nend\n``` |
    And I see the page in <scheme> mode
    When I visit "/writing/hello"
    Then every highlighter class starts with hl-
    And the code block draws 6 lines
    And nothing inside the code block has a border
    And the colors of these code parts are:
      | part                           | color     |
      | .hl-keyword                    | <keyword> |
      | .hl-string                     | <string>  |
      | .hl-entity.hl-name.hl-class    | <class>   |
      | .hl-entity.hl-name.hl-function | <function> |
      | .hl-comment                    | <comment> |

    Examples:
      | scheme | keyword | string  | class   | function | comment |
      | light  | #e14775 | #cc7a0a | #269d69 | #1c8ca8  | #918c8e |
      | dark   | #fc618d | #fce566 | #7bd88f | #5ad4e6  | #69676c |

  Scenario: A fence that names its file gets a caption on the public post page
    Given the posts:
      | title | body                                                                                                     |
      | Hello | ```ruby config/providers/redis.rb\nHanami.app.register_provider(:redis) do\nend\n```\n\n```ruby\nNAME = "create"\n``` |
    When I visit "/writing/hello"
    Then ".cf > .cf-n" reads "config/providers/redis.rb"
    And the page has ".cf-n > i[aria-hidden='true'] > svg"
    And the page has ".cf > .cf-n + pre.syntax-highlighting .hl-keyword:text-is('do')"
    And the page has 1 of "pre.syntax-highlighting:not(.cf pre)"

  Scenario Outline: A code block in the admin preview renders highlighted in <scheme> mode
    Given I am signed in to the admin
    And I see the page in <scheme> mode
    When I visit "/admin/posts/new"
    And I write the post body:
      """
      ```ruby
      require "types"
      # app/actions/users/create.rb
      class Create < Base
        def call = Types::String.constructor { |value| value&.downcase&.strip }
        NAME = "create"
      end
      ```
      """
    And I choose the "Preview" option
    Then the page has ".preview pre.syntax-highlighting"
    And every highlighter class starts with hl-
    And the code block draws 6 lines
    And nothing inside the code block has a border
    And the colors of these code parts are:
      | part                           | color     |
      | .hl-keyword                    | <keyword> |
      | .hl-string                     | <string>  |
      | .hl-entity.hl-name.hl-class    | <class>   |
      | .hl-entity.hl-name.hl-function | <function> |
      | .hl-comment                    | <comment> |

    Examples:
      | scheme | keyword | string  | class   | function | comment |
      | light  | #e14775 | #cc7a0a | #269d69 | #1c8ca8  | #918c8e |
      | dark   | #fc618d | #fce566 | #7bd88f | #5ad4e6  | #69676c |

  Scenario: A fence that names its file gets a caption in the admin preview
    Given I am signed in to the admin
    When I visit "/admin/posts/new"
    And I write the post body:
      """
      ```ruby config/providers/redis.rb
      Hanami.app.register_provider(:redis) do
      end
      ```

      ```ruby
      NAME = "create"
      ```
      """
    And I choose the "Preview" option
    Then ".preview .cf > .cf-n" reads "config/providers/redis.rb"
    And the page has ".preview .cf-n > i[aria-hidden='true'] > svg"
    And the page has ".preview .cf > .cf-n + pre.syntax-highlighting .hl-keyword:text-is('do')"
    And the page has 1 of ".preview pre.syntax-highlighting:not(.cf pre)"
