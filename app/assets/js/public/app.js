import "../../css/public.css";
import { setupTaskFilters } from "../task_filter.js";
import { setupBeacon } from "./beacon.js";
import { setupBoardView } from "./board_view.js";
import { setupClock } from "./clock.js";
import { setupContactErrors } from "./contact_errors.js";
import { setupMessageCount } from "./message_count.js";
import { setupSearchKey } from "./search_key.js";
import { setupToc } from "./toc.js";

setupBeacon();
setupBoardView();
setupClock();
setupContactErrors();
setupMessageCount();
setupSearchKey();
setupTaskFilters();
setupToc();
