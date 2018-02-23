function toggleLogin() {
	document.getElementById("login-form").classList.toggle("hidden");
}

function toggleProfile() {
	document.getElementById("user-menu").classList.toggle("hidden");
}

$(document).click(function(event) { 
	console.log("click")
	if(!$(event.target).closest('.user-container').length) {
		if($('#login-form').is(":visible")) {
			$('#login-form').addClass("hidden")
		} else if ($('#user-menu').is(":visible")) {
			$('#user-menu').addClass("hidden")
		}
	}
});