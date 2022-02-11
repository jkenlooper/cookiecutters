/** @format */
/*
Specificity ordered stylesheet (ITCSS). Sections are designated with a digit
in relation to the order they are imported. See ./site/README.md for details.
*/
/* 0 Generic */
/* 1 Elements */
/* 2 Objects */
import "./site/site.css";

/* 3 Components */
import "./base/base.css";

/* 4 Theme */
import "./site/4-theme-paper.css";

// Import the utils css last
/* 5 Utilities */
import "./site/5-utils.css";

// Root settings for custom properties
/* Root Settings */
import "./settings/settings.css";
