function selectall () {
	myform = this.form;
        for (var i = 0; i < myform.elements.length; i++)
                myform.elements[i].checked = true;
}
function unhideButton {
	sabutton = document.getElementById("sabutton");
	sabutton.style.display = 'block';
}
if(window.addEventListener){
    window.addEventListener('load',unhideButton,false); //W3C
}
else{
    window.attachEvent('onload',unhideButton); //IE
}
document.getElementById("sabutton").addEventListener("click", selectall);
