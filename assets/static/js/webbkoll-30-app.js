document.addEventListener("DOMContentLoaded", function(event) {
  var tables = document.querySelectorAll('[data-sortable]'), i;
  for (i = 0; i < tables.length; ++i) {
    new Tablesort(tables[i]);
  }
});

window.addEventListener("load", function(event) {
  // The a11y elements ("How to...") mess up scrolling to fragment identifiers
  // (e.g. #cookies) on initial page load, at least in FF; this is a workaround
  // until I figure out something better.
  if (window.location.hash) {
      document.getElementById(window.location.hash.substring(1)).scrollIntoView();
  }
});
