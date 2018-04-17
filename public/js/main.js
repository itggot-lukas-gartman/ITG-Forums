function toggleLogin() {
	document.getElementById("login-form").classList.toggle("hidden");
}

function toggleProfile() {
	document.getElementById("user-menu").classList.toggle("hidden");
}

$(document).ready(function() {
	$('#picture-file').change(function() {
		var fileSize = (this.files[0].size);
		if (fileSize < 5000000) {
			$('#update-picture').submit();
			$('body').append('<div class="dim"><img src="/img/loading.gif" /></div>');
		} else {
			alert("File size may not exceed 5MB")
		}
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