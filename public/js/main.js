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

function toggleLogin() {
	document.getElementById("login-form").classList.toggle("hidden");
}

function toggleProfile() {
	document.getElementById("user-menu").classList.toggle("hidden");
}

function closeWarning(data) {
	$(document).submit(function() {
		window.onbeforeunload = null;
	});
	
	window.onbeforeunload = function () {
		var showDialog = false;

		var thread = data.document.getElementById("reply");
		var new_thread = data.document.getElementById("newThread");

		if (thread) {
			var reply = document.forms["reply"]["message"].value;
			if (reply != "") {
				showDialog = true;
			}
		} else if (new_thread) {
			var title = document.forms["newThread"]["title"].value;
			var text = document.forms["newThread"]["text"].value;
			if (title != "" || text != "") {
				showDialog = true;
			}
		}

		if (showDialog) {
			return confirm("Are you sure you want to close the current window? Any text entered will be lost.")
		}
	};
}

function upvote(str) {
	ary = str.split("-")
	var type = ary[0];
	var id = ary[1];

	$.post(window.location.origin + `/${type}/${id}/upvote`, function() {
		var rep = document.getElementById(str);
		// Increase the rep count display
		var rep_int = parseInt(rep.innerHTML);
		document.getElementById(str).innerHTML = ++rep_int;

		// Disable buttons
		var rep_parent_nodes = rep.parentNode.childNodes;
		rep_parent_nodes[1].setAttribute("disabled", "disabled");
		rep_parent_nodes[2].setAttribute("disabled", "disabled");
		rep_parent_nodes[1].removeAttribute("onclick");
		rep_parent_nodes[2].removeAttribute("onclick");
	});
}

function downvote(str) {
	ary = str.split("-")
	var type = ary[0];
	var id = ary[1];

	$.post(window.location.origin + `/${type}/${id}/downvote`, function() {
		var rep = document.getElementById(str);
		// Decrease the rep count display
		var rep_int = parseInt(rep.innerHTML);
		document.getElementById(str).innerHTML = --rep_int;

		// Disable buttons
		var rep_parent_nodes = rep.parentNode.childNodes;
		rep_parent_nodes[1].setAttribute("disabled", "disabled");
		rep_parent_nodes[2].setAttribute("disabled", "disabled");
		rep_parent_nodes[1].removeAttribute("onclick");
		rep_parent_nodes[2].removeAttribute("onclick");
	});
}

function setAccountFields(e) {
	username = e.options[e.selectedIndex].value;
	var url = location.origin;
	$.getJSON(`${url}/api/profile/${username}`, function( json ) {
		document.querySelector("#account_username").value = json.username;
		document.querySelector("#account_email").value = json.email;
		document.querySelector("#account_rank").value = json.rank;
		document.querySelector("#account_picture").value = json.picture;
	});

	if (username == document.querySelector("#user").textContent) {
		window.alert("Changing your own account will sign you out.");
	}
}

function setForumFields(e) {
	forum = e.options[e.selectedIndex].value;
	var url = location.origin;
	$.getJSON(`${url}/api/forum/${forum}`, function( json ) {
		document.querySelector("#forum_name").value = json.forum_name;
		document.querySelector("#forum_permission").value = json.permission;
	});
}

function setSubforumFields(e) {
	subforum = e.options[e.selectedIndex].value;
	var url = location.origin;
	$.getJSON(`${url}/api/subforum/${subforum}`, function( json ) {
		document.querySelector("#subforum_name").value = json.name;
		document.querySelector("#subforum_description").value = json.description;
	});
}