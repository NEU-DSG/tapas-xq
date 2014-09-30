function clearPageBreaks(){
	$("pb").css("display","none");
	$(".-teibp-pb").css("display","none");
}

function addPageBreaks(){
    var viewBox = $('select#viewBox');
    var cssFile = viewBox.val();
    if (cssFile.indexOf('tapasGdiplo') > -1) {
        Tapas.currentTheme = 'diplomatic';
    } else {
        Tapas.currentTheme = 'normalized';
    }    
    if (Tapas.currentTheme == 'diplomatic') {
    	$("pb").css("display","block");	
    	$(".-teibp-pb").css("display","block");        
    } else {
    	$("pb").css("display","inline");	
    	$(".-teibp-pb").css("display","inline");        
    }
}

function init(){
	document.getElementById('pbToggle').onclick = function(){
		if(document.getElementById('pbToggle').checked){
			clearPageBreaks();
			Tapas.showPbs = false;
		}else{
			addPageBreaks();
			Tapas.showPbs = true;
		}
	};
	addPageBreaks();
	document.getElementById('pbToggle').checked = false;
}

//If W3C event model used, prefer that. Window events are fallbacks
if(document.addEventListener){
	//W3C event model used
	document.addEventListener("DOMContentLoaded", init, false);
	window.addEventListener("load", init, false);
} else if(document.attachEvent){
	//IE event model used
	document.attachEvent( "onreadystatechange", init);
	window.attachEvent( "onload", init);
}

function switchThemes(event) {
    var cssFile = jQuery(event.target).val();
    if (cssFile == '../css/tapasGdiplo.css') {
        Tapas.currentTheme = 'diplomatic';
    } else {
        Tapas.currentTheme = 'normalized';
    }
    if (Tapas.showPbs) {
        addPageBreaks();
    }
	document.getElementById('maincss').href = jQuery(event.target).val();
}

function showFacs(num, url, id) {
	facsWindow = window.open ("about:blank")
	facsWindow.document.write("<html>")
	facsWindow.document.write("<head>")
	facsWindow.document.write("<title>TEI Boilerplate Facsimile Viewer</title>")
	facsWindow.document.write($('#maincss')[0].outerHTML)
	facsWindow.document.write($('#customcss')[0].outerHTML)
	facsWindow.document.write("<link rel='stylesheet' href='../js/jquery-ui/themes/base/jquery.ui.all.css'>")
	facsWindow.document.write($('style')[0].outerHTML)
	facsWindow.document.write("<script type='text/javascript' src='../js/jquery/jquery.min.js'></script>")
	facsWindow.document.write("<script type='text/javascript' src='../js/jquery-ui/ui/jquery-ui.js'></script>")
	facsWindow.document.write("<script type='text/javascript' src='../js/jquery/plugins/jquery.scrollTo-1.4.3.1-min.js'></script>")
	facsWindow.document.write("<script type='text/javascript' src='../js/teibp.js'></script>")
	facsWindow.document.write("<script type='text/javascript'>")
	facsWindow.document.write("$(document).ready(function() {")
	facsWindow.document.write("$('.facsImage').scrollTo($('#" + id + "'))")
	facsWindow.document.write("})")
	facsWindow.document.write("</script>")
	facsWindow.document.write("<script>	$(function() {$( '#resizable' ).resizable();});</script>")
	facsWindow.document.write("</head>")
	facsWindow.document.write("<body>")
	facsWindow.document.write($("teiHeader")[0].outerHTML)
	//facsWindow.document.write("<teiHeader>" + $("teiHeader")[0].html() + "</teiHeader>")
	//facsWindow.document.write($('<teiHeader>').append($('teiHeader').clone()).html();)
	
	//facsWindow.document.write($("teiHeader")[0].outerHTML)
	facsWindow.document.write("<div id='resizable'>")
	facsWindow.document.write("<div class='facsImage'>")
	$(".-teibp-thumbnail").each(function() {
		facsWindow.document.write("<img id='" + $(this).parent().parent().parent().attr('id') + "' src='" + $(this).attr('src') + "' alt='facsimile page image'/>")
	})
	facsWindow.document.write("</div>")
	facsWindow.document.write("</div>")
	facsWindow.document.write($("footer")[0].outerHTML)
	
	facsWindow.document.write("</body>")
	facsWindow.document.write("</html>")
	facsWindow.document.close()
}