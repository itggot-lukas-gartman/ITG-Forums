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

// function upvote(id) {
// 	var rep = parseInt(document.getElementById(id).innerHTML);
// 	document.getElementById(id).innerHTML = ++rep;
// }

// function postDownvote(id) {

// }