Feature: Admin tag manager renames, describes and recolours tags
  Each tag's editor renames it, describes it and gives it one of the six colours. A rename carries every record
  that holds the tag, and a refusal keeps the editor open with what was typed.

  Background:
    Given I am signed in to the admin

  Scenario: A rename rewrites the name, carries the tagged records and says so
    Given these records carry tags for the tag manager:
      | kind | title   | tags |
      | post | On ruby | ruby |
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | hanami |
    Then the tag manager shows "[data-toast]" reading "Tag renamed"
    And the database answers "hanami" for:
      """
      select t.name from post_tags pt join tags t on t.id = pt.tag_id join posts p on p.id = pt.post_id
      where p.title = 'On ruby'
      """

  Scenario: A blank rename is refused against its row, in the open editor in the side panel
    Given the tag manager holds the public tags "ruby"
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | " " |
    Then the tag manager answers 422
    And the tag manager shows "aside.settings-side #tag-{public:ruby}-editor.tag-editor-open #tag-{public:ruby}-name-error"

  Scenario: A rename from the private tab renames the private tag and goes back to that tab
    Given the tag manager holds the private tags "chores"
    When I post to the tag manager at "/admin/tags/{private:chores}" with:
      | tag[name] | errands |
      | scope     | private |
    Then the tag manager lands on "/admin/settings/tagging?scope=private#tags"
    And the database answers "errands" for:
      """
      select name from tags
      """

  Scenario: A rename takes a name the other scope holds
    Given the tag manager holds the public tags "ruby"
    And the tag manager holds the private tags "hanami"
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | hanami |
    Then the database answers "hanami" for:
      """
      select name from tags where scope = 'public'
      """

  Scenario: A rename to a name the same scope holds says why
    Given the tag manager holds the public tags "ruby, hanami"
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | hanami |
    Then the tag manager shows ".field-error" reading "Another tag already holds that name."

  Scenario: A rename answers 404 for a tag from the other scope
    Given the tag manager holds the public tags "ruby"
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | hanami  |
      | scope     | private |
    Then the tag manager answers 404

  Scenario: The rename form holds the description
    Given the tag manager holds these tags:
      | name | description  |
      | ruby | the language |
    When I visit "/admin/settings/tagging"
    Then the tag manager's "#tag-{public:ruby}-form textarea[name='tag[description]']" holds "the language"

  Scenario: A description is stored, and an emptied field clears it
    Given the tag manager holds these tags:
      | name | description  |
      | ruby | the language |
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name]        | ruby              |
      | tag[description] | matz's *language* |
    Then the database answers "matz's *language*" for:
      """
      select description from tags
      """
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name]        | ruby |
      | tag[description] | " "  |
    Then the database answers "true" for:
      """
      select description is null from tags
      """

  Scenario: The description holds through a rename and a new colour
    Given the tag manager holds these tags:
      | name | description  |
      | ruby | the language |
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | crystal |
    And I post to the tag manager at "/admin/tags/{public:crystal}" with:
      | tag[name]  | crystal   |
      | tag[color] | mk-orange |
    Then the database answers "crystal, mk-orange, the language" for:
      """
      select name, color, description from tags
      """

  Scenario: A refused rename keeps the typed description and stores nothing
    Given the tag manager holds these tags:
      | name | description  |
      | ruby | the language |
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name]        | " "          |
      | tag[description] | half written |
    Then the tag manager answers 422
    And the tag manager's "#tag-{public:ruby}-form textarea[name='tag[description]']" holds "half written"
    And the database answers "the language" for:
      """
      select description from tags
      """

  Scenario: A description from the private tab describes the private tag
    Given the tag manager holds the private tags "chores"
    When I post to the tag manager at "/admin/tags/{private:chores}" with:
      | tag[name]        | chores           |
      | tag[description] | around the house |
      | scope            | private          |
    Then the database answers "around the house" for:
      """
      select description from tags
      """

  Scenario: A new colour is stored with the name it held, and says so
    Given the tag manager holds these tags:
      | name | color   |
      | ruby | mk-blue |
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name]  | ruby      |
      | tag[color] | mk-orange |
    Then the tag manager shows "[data-toast]" reading "Tag recoloured"
    And the database answers "ruby, mk-orange" for:
      """
      select name, color from tags
      """

  Scenario: The editor offers a swatch for each colour and marks the one the tag holds
    Given the tag manager holds these tags:
      | name | color   |
      | ruby | mk-blue |
    When I visit "/admin/settings/tagging"
    Then the tag manager lists the value of ".tag-editor button[name='tag[color]']" as "mk-pink, mk-green, mk-blue, mk-violet, mk-sand, mk-orange"
    And the tag manager shows ".tag-editor button[name='tag[color]'][value='mk-blue'][aria-pressed='true']"

  Scenario: A new colour leaves the tag of the same name in the other scope alone
    Given the tag manager holds these tags:
      | name | scope   | color   |
      | ruby | public  | mk-blue |
      | ruby | private | mk-blue |
    When I post to the tag manager at "/admin/tags/{private:ruby}" with:
      | tag[name]  | ruby      |
      | tag[color] | mk-orange |
      | scope      | private   |
    Then the database answers "mk-blue" for:
      """
      select color from tags where scope = 'public'
      """

  Scenario: Every form in a private tag's editor carries the scope
    Given the tag manager holds the private tags "chores"
    When I visit "/admin/settings/tagging?scope=private"
    Then the tag manager lists the value of ".tag-editor form input[name='scope']" as "private, private, private"

  Scenario: A colour that is not one of the six is refused
    Given the tag manager holds these tags:
      | name | color   |
      | ruby | mk-blue |
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name]  | ruby   |
      | tag[color] | papaya |
    Then the database answers "mk-blue" for:
      """
      select color from tags
      """
