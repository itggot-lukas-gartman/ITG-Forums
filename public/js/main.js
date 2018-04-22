function toggleLogin() {
	document.getElementById("login-form").classList.toggle("hidden");
}

function toggleProfile() {
	document.getElementById("user-menu").classList.toggle("hidden");
}

function closeWarning(test) {
	window.onbeforeunload = function () {
		var title = document.forms["newThread"]["title"].value;
		var text = document.forms["newThread"]["text"].value;
		if (title != "" || text != "") {
			return confirm("Are you sure you want to close the current window? Any text entered will be lost.")
		}
	};

	$(document).submit(function() {
		window.onbeforeunload = null;
	});
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

function newServerAjaxCall(url, data, code) {
    var request = new XMLHttpRequest();
    request.onreadystatechange = function() {
        if (this.readyState === 4) {
            if (this.status === 200) {
                eval(code);
            } else {
                console.log("Error appeared for server ajax call: '" + url + "'");
                console.log(this.responseText);
            }
        }
    };
    request.open("POST", url, true);
    if (data === null) {
        request.send();
    } else {
        request.send(data);
    }
}

function upvote(id) {
	var rep = parseInt(document.getElementById(id).innerHTML);
	document.getElementById(id).innerHTML = ++rep;
}

function downvote(id) {
	var rep = parseInt(document.getElementById(id).innerHTML);
	document.getElementById(id).innerHTML = --rep;
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