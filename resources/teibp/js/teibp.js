function getPageBreaks(){
	return document.getElementsByClassName('teibp').getElementsByTagName('pb');
}

function clearPageBreaks(){
	var pageBreaks = getPageBreaks();
	for(pageBreak in pageBreaks){
		pageBreaks[pageBreak].textContent = '';
	}
}

function addPageBreaks(){
	var pageBreaks = getPageBreaks();
	for(pageBreak in pageBreaks){
		if(null != pageBreaks[pageBreak].attributes.getNamedItem('n')
			&& undefined != pageBreaks[pageBreak].attributes.getNamedItem('n')){
			pageBreaks[pageBreak].textContent = "page: " 
				+ pageBreaks[pageBreak].attributes.getNamedItem('n').value
				+ "";
		}else{pageBreaks[pageBreak].textContent = "page"}
	}
}

function init(){
	document.getElementsByClassName('teibp').getElementById('pbToggle').onclick = function(){
		if(document.getElementsByClassName('teibp').getElementById('pbToggle').checked){
			clearPageBreaks();
		}else{
			addPageBreaks();
		}
	};
	addPageBreaks();
	document.getElementsByClassName('teibp').getElementById('pbToggle').checked = false;
}

$(document).ready(function(){
	init();
});

function switchThemes(theme){ // This needs to be fixed.
	document.getElementById('maincss').href=theme.options[theme.selectedIndex].value;
}
