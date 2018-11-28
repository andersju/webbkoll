document.addEventListener("DOMContentLoaded", function(event) {
  var tables = document.querySelectorAll('[data-sortable]'), i;
  for (i = 0; i < tables.length; ++i) {
    new Tablesort(tables[i]);
  }
});