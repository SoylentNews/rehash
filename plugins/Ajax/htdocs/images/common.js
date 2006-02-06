function toggleIntro(id, toggleid) {
	var obj = document.getElementById(id);
	var toggle = document.getElementById(toggleid);
	if (obj.className == 'introhide') {
		obj.className = "intro"
		toggle.innerHTML = "[-]";
	} else {
		obj.className = "introhide"
		toggle.innerHTML = "[+]";
	}
}
