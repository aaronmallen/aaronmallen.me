Feature: Admin tag field
  Forms that take tags show them as chips and suggest the tags that match as the owner types, each in its colour.
  Public forms suggest public tags, and the task and journal forms suggest private ones. The keyboard alone can
  pick a suggestion, and the field binds once however often the page morphs.

  Background:
    Given I am signed in to the admin
    And the tag manager holds these tags:
      | name  | scope   | color    |
      | ruby  | public  | mk-green |
      | rails | public  | mk-pink  |
      | rake  | private | mk-blue  |
    And these records carry tags for the tag manager:
      | kind    | title | tags |
      | project | sai   | ruby |

  Scenario: The tag field shows the tags as chips in place of the comma box
    When I visit "/admin/projects/1/edit"
    Then the tag manager shows no visible "[name='project[tags]']"
    And the tag field chips read "#ruby"

  Scenario: The tag field lists the public tags that match, each in its colour
    When I visit "/admin/projects/1/edit"
    And I type "ra" in the tag field "[data-tag-field-input]"
    Then the tag field suggests "#rails, New tag ra"
    And the tag manager shows ".tag-pick-result .tag.pink" reading "#rails"

  Scenario: The keyboard alone picks a suggestion and adds a chip in its colour, which saves
    When I visit "/admin/projects/1/edit"
    And I type "rai" in the tag field "[data-tag-field-input]"
    And the tag field suggests "#rails, New tag rai"
    And I press "ArrowDown" in the tag field "[data-tag-field-input]"
    And I press "Enter" in the tag field "[data-tag-field-input]"
    Then the tag field chips read "#ruby, #rails"
    And the tag manager shows ".tag-pick-chip .tag.pink" reading "#rails"
    When I click the button "Save project"
    Then the tag manager shows "[data-toast]" reading "Project saved"
    And the database answers "rails,ruby" for:
      """
      select string_agg(t.name, ',' order by t.name) from project_tags pt join tags t on t.id = pt.tag_id
      """

  Scenario: The tag field closes the suggestions on Escape
    When I visit "/admin/projects/1/edit"
    And I type "ra" in the tag field "[data-tag-field-input]"
    And the tag field suggests "#rails, New tag ra"
    And I press "Escape" in the tag field "[data-tag-field-input]"
    Then the tag manager shows no ".tag-pick-result"

  Scenario: A removed chip's tag comes off on save
    When I visit "/admin/projects/1/edit"
    And I click "button[aria-label='Remove ruby']" beside the tag field
    And I click the button "Save project"
    Then the tag manager shows "[data-toast]" reading "Project saved"
    And the database answers "0" for:
      """
      select count(*) from project_tags
      """

  Scenario: A new name adds a chip and makes the tag on save
    When I visit "/admin/projects/1/edit"
    And I type "hanami" in the tag field "[data-tag-field-input]"
    And I press "Enter" in the tag field "[data-tag-field-input]"
    Then the tag field chips read "#ruby, #hanami"
    When I click the button "Save project"
    Then the tag manager shows "[data-toast]" reading "Project saved"
    And the database answers "hanami,ruby" for:
      """
      select string_agg(t.name, ',' order by t.name) from project_tags pt join tags t on t.id = pt.tag_id
      """

  Scenario: The tag field binds once after a morph
    When I visit "/admin/projects/1/edit"
    And the tag field's page swaps its main and hears two morphs
    And I type "r" in the tag field "[data-tag-field-input]"
    And the tag field suggests "#rails, New tag r"
    And I press "ArrowDown" in the tag field "[data-tag-field-input]"
    Then the tag manager shows ".tag-pick-result[aria-selected='true']" reading exactly "#rails"

  Scenario: The post details suggest public tags
    Given these records carry tags for the tag manager:
      | kind       | title   | tags |
      | draft post | A draft |      |
    When I visit "/admin/posts/1/edit"
    And I click the button "Details"
    And I type "r" in the tag field "dialog#post-details[open] [data-tag-field-input]"
    Then the tag field suggests "#rails, #ruby, New tag r"

  Rule: The private forms suggest private tags

    Background:
      Given the tag manager holds these tags:
        | name   | scope   | color    |
        | chores | private | mk-green |
      And these records carry tags for the tag manager:
        | kind    | title | tags |
        | message | Hi    | barn |

    Scenario: The task modal lists the private tags that match, each in its colour
      When I visit "/admin/tasks"
      And I click the link "Create Task"
      And I type "r" in the tag field "dialog#task-create[open] [data-tag-field-input]"
      Then the tag field suggests "#chores, #rake, New tag r"
      And the tag manager shows ".tag-pick-result .tag.green" reading "#chores"

    Scenario: The task modal saves the pick
      When I visit "/admin/tasks"
      And I click the link "Create Task"
      And I fill "dialog#task-create[open] [name='task[title]']" beside the tag field with "Sweep the porch"
      And I type "cho" in the tag field "dialog#task-create[open] [data-tag-field-input]"
      And the tag field suggests "#chores, New tag cho"
      And I press "ArrowDown" in the tag field "dialog#task-create[open] [data-tag-field-input]"
      And I press "Enter" in the tag field "dialog#task-create[open] [data-tag-field-input]"
      And I click "dialog#task-create[open] button:text-is('Create task')" beside the tag field
      Then the tag manager shows ".task-title" visibly, reading "Sweep the porch"
      And the database answers "Sweep the porch, chores" for:
        """
        select k.title, t.name from tasks k join task_tags tt on tt.task_id = k.id join tags t on t.id = tt.tag_id
        """

    Scenario: The task drawer adds and saves a chip
      Given these records carry tags for the tag manager:
        | kind | title         | tags |
        | task | Mop the floor | rake |
      When I open the tag field in the task drawer of "Mop the floor"
      And I type "cho" in the tag field "dialog#task-panel[open] [data-tag-field-input]"
      And the tag field suggests "#chores, New tag cho"
      And I press "ArrowDown" in the tag field "dialog#task-panel[open] [data-tag-field-input]"
      And I press "Enter" in the tag field "dialog#task-panel[open] [data-tag-field-input]"
      And I click "dialog#task-panel[open] [data-task-edit] button:text-is('Save')" beside the tag field
      Then the tag manager shows "dialog#task-panel[open] [data-task-read]" visibly
      And the database answers "chores,rake" for:
        """
        select string_agg(t.name, ',' order by t.name) from task_tags tt join tags t on t.id = tt.tag_id
        """

    Scenario: The task drawer's tag field binds once after a morph
      Given these records carry tags for the tag manager:
        | kind | title         | tags |
        | task | Mop the floor |      |
      When I open the tag field in the task drawer of "Mop the floor"
      And the tag field's page hears two morphs
      And I type "r" in the tag field "dialog#task-panel[open] [data-tag-field-input]"
      And the tag field suggests "#chores, #rake, New tag r"
      And I press "ArrowDown" in the tag field "dialog#task-panel[open] [data-tag-field-input]"
      Then the tag manager shows ".tag-pick-result[aria-selected='true']" reading exactly "#chores"

    Scenario: The journal dialog lists the private tags that match
      When I visit "/admin/posts"
      And I press "w"
      And I fill "#journal-write-body" beside the tag field with "walked"
      And I type "r" in the tag field "#journal-write-tags-search"
      Then the tag field suggests "#chores, #rake, New tag r"

    Scenario: The journal dialog saves the chips
      When I visit "/admin/posts"
      And I press "w"
      And I fill "#journal-write-body" beside the tag field with "walked"
      And I type "cho" in the tag field "#journal-write-tags-search"
      And the tag field suggests "#chores, New tag cho"
      And I press "ArrowDown" in the tag field "#journal-write-tags-search"
      And I press "Enter" in the tag field "#journal-write-tags-search"
      And I type "lake" in the tag field "#journal-write-tags-search"
      And I press "Enter" in the tag field "#journal-write-tags-search"
      And I click "dialog#journal-write button:text-is('Save')" beside the tag field
      Then the tag manager shows ".toast" reading "Journal entry saved"
      And the database answers "chores,lake" for:
        """
        select string_agg(t.name, ',' order by t.name) from journal_entry_tags jt join tags t on t.id = jt.tag_id
        """
