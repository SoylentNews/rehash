function setJSButtonsOn() {  
    var titles = document.querySelectorAll('.commentTop .title h4.noJS');
    for(var i =0; i< titles.length;i++){
        var title = titles[i];
        title.classList.remove("noJS");
    }

    var buttons = document.querySelectorAll('.expandAll');
    for(var i =0; i< buttons.length;i++){
        var button = buttons[i];
        button.classList.remove("noJS");
        button.addEventListener("click", function(event){
            var cid = event.target.getAttribute("cid");
            var checks = document.querySelectorAll('#tree_' + cid + ' input[type="checkbox"].commentHider, #tree_' + cid + ' input[type="checkbox"].commentTreeHider, #tree_' + cid + ' input[type="checkbox"].commentBelow');
            
            for(var i =0; i< checks.length;i++){
                var check = checks[i];
                if(!check.disabled){
                    check.checked = false;
                }
            }
        }, false);
    }
}
window.onload = setJSButtonsOn;