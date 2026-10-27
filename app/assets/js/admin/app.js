import "../../css/admin.css";
import { setupDiagrams } from "../diagrams.js";
import { setupTaskFilters } from "../task_filter.js";
import { bootAutosubmit, setupAutosubmit } from "./autosubmit.js";
import { bootBoardDrag } from "./board_drag.js";
import { bootBoardView, setupBoardView } from "./board_view.js";
import { bootBulk, setupBulk } from "./bulk.js";
import { setupCadences } from "./cadence.js";
import { setupCalendars } from "./calendar.js";
import { setupCommentAdds } from "./comment_add.js";
import { bootCommitImports, setupCommitImports } from "./commits.js";
import { setupConfirms } from "./confirm.js";
import { bootContactForms } from "./contact_form.js";
import { bootContextMenus } from "./context_menu.js";
import { setupDialogs } from "./dialog.js";
import { setupEditNotes } from "./edit_note.js";
import { setupFileDrops } from "./file_drop.js";
import { setupJournals } from "./journal.js";
import { bootKeys, setupKeys } from "./keys.js";
import { setupLinkForms } from "./link_form.js";
import { bootLive, MORPHED } from "./live.js";
import { bootMailDrag } from "./mail_drag.js";
import { setupMailEditors } from "./mail_editor.js";
import { setupMarkdownEditors } from "./markdown_editor.js";
import { bootMorphForms } from "./morph_form.js";
import { setupNotes } from "./notes.js";
import { bootPalette, setupPalette } from "./palette.js";
import { setupPersonFinder } from "./person_finder.js";
import { setupPersonForms } from "./person_form.js";
import { setupPools } from "./pools.js";
import { bootPostEditors, setupPostEditors } from "./post_editor.js";
import { setupPostSyndication } from "./post_syndication.js";
import { setupProjectChoices } from "./project_choices.js";
import { setupProjectEditors } from "./project_editor.js";
import { setupProjectPicks } from "./project_pick.js";
import { setupRecordKeys } from "./record_key.js";
import { setupAccountPickers } from "./social_account_picker.js";
import { setupSocialComposers } from "./social_composer.js";
import { setupTagFields } from "./tag_field.js";
import { bootTaskOrder, setupTaskOrder } from "./task_order.js";
import { bootTaskPanel, setupTaskPanel } from "./task_panel.js";
import { setupToasts } from "./toast.js";
import { bootTodayCalendar } from "./today_calendar.js";
import { bootTracked } from "./tracked.js";
import { setupWorkForms } from "./work_form.js";

const SETUPS = [
  setupAccountPickers,
  setupAutosubmit,
  setupBoardView,
  setupBulk,
  setupCadences,
  setupCalendars,
  setupCommentAdds,
  setupCommitImports,
  setupConfirms,
  setupDiagrams,
  setupDialogs,
  setupEditNotes,
  setupFileDrops,
  setupJournals,
  setupKeys,
  setupLinkForms,
  setupMailEditors,
  setupMarkdownEditors,
  setupNotes,
  setupPalette,
  setupPersonFinder,
  setupPersonForms,
  setupPools,
  setupPostEditors,
  setupPostSyndication,
  setupProjectChoices,
  setupProjectEditors,
  setupProjectPicks,
  setupRecordKeys,
  setupSocialComposers,
  setupTagFields,
  setupTaskFilters,
  setupTaskOrder,
  setupTaskPanel,
  setupToasts,
  setupWorkForms,
];

const BOOT = [
  bootAutosubmit,
  bootBoardDrag,
  bootBoardView,
  bootBulk,
  bootCommitImports,
  bootContactForms,
  bootContextMenus,
  bootKeys,
  bootLive,
  bootMailDrag,
  bootMorphForms,
  bootPalette,
  bootPostEditors,
  bootTaskOrder,
  bootTaskPanel,
  bootTodayCalendar,
  bootTracked,
];

function run(steps) {
  for (const step of steps) {
    try {
      step();
    } catch (error) {
      reportError(error);
    }
  }
}

run(SETUPS);
run(BOOT);
document.addEventListener(MORPHED, () => run(SETUPS));
