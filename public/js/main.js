function toggleLogin() {
	document.getElementById("login-form").classList.toggle("hidden");
}

function toggleProfile() {
	document.getElementById("user-menu").classList.toggle("hidden");
}

$(document).ready(function() {
	$('#picture-file').change(function() {
		$('#update-picture').submit();
		$('body').append('<div class="dim"><img src="/img/loading.gif" /></div>');
	});
});

$(document).click(function(event) {
	if(!$(event.target).closest('.user-container').length) {
		if($('#login-form').is(":visible")) {
			$('#login-form').addClass("hidden")
		} else if ($('#user-menu').is(":visible")) {
			$('#user-menu').addClass("hidden")
		}
	}
});