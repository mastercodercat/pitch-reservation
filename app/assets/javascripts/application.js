// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
//= require jquery
//= require jquery_ujs
//= require jquery-ui
//= require jquery.sticky
//= require_self
//= require cocoon
//= require autocomplete-rails
//= require dataTables/jquery.dataTables
//= require dataTables_numhtml_sort.js
//= require dataTables_numhtml_detect.js
//= require dataTables/jquery.dataTables.bootstrap
//= require bootstrap

$(document).ready(function() {
// For DataTables and Bootstrap
	$('.datatable').dataTable({
	  "sDom": "<'row'<'span4'l><'span5'f>r>t<'row'<'span3'i><'span6'p>>",
	  "sPaginationType": "bootstrap",
		"sScrollX": "100%",
		"aoColumnDefs": [
		      { "bSortable": false, "aTargets": [ "no_sort" ] }
		    ]
	});

// For fading out flash notices
	$(".alert .close").click( function() {
	     $(this).parent().addClass("fade");
	});
	
	$("#sidebarbottom").sticky({topSpacing: 50, bottomSpacing: 200});
});

$.datepicker.setDefaults({
   minDate: new Date(),
});

// auto-submit cart dates #only-cart-dates
  $(document).on('change', '.submitchange', function() {
      $('#cart_dates').load( update_cart_path.value, // defined in _cart_dates in hidden field
// params need to be passed
        { 'reserver_id': reserver_id.value,
          'start_date_cart': cart_start_date_cart.value,
          'due_date_cart': cart_due_date_cart.value }
      );
  });

// auto-submit cart dates #only-cart-reserver
  $(document).on('blur', '.submittable', function() {
      $('#cart_dates').load( update_cart_path.value, // defined in _cart_dates in hidden field
// params need to be passed
        { 'reserver_id': reserver_id.value,
          'start_date_cart': cart_start_date_cart.value,
          'due_date_cart': cart_due_date_cart.value }
      );
  });

// general submit on change class
  $(document).on('change', '.autosubmitme', function() {
    $(this).parents('form:first').submit();
  });
});	
