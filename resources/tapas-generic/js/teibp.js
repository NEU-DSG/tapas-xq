function clearPageBreaks(){
	$(".tapas-generic pb").css("display","none");
	$(".tapas-generic .-teibp-pb").css("display","none");
}

function addPageBreaks(){
    // var viewBox = $('.tapas-generic select#viewBox');
    // var cssFile = viewBox.val();
    // if (cssFile.indexOf('tapasGdiplo') > -1) {
    //     Tapas.currentTheme = 'diplomatic';
    // } else {
    //     Tapas.currentTheme = 'normalized';
    // }
    if (Tapas.currentTheme == 'diplomatic') {
    	$(".tapas-generic pb").css("display","block");
    	$(".tapas-generic .-teibp-pb").css("display","block");
    } else {
    	$(".tapas-generic pb").css("display","inline");
    	$(".tapas-generic .-teibp-pb").css("display","inline");
    }
		// console.log(Tapas.currentTheme);
		// console.log($("#maincss").attr('href'));
}

function init(){
	// $(".tapas-generic").addClass('diplomatic');
	// Tapas.currentTheme = 'diplomatic';
	$('#pbToggle').onclick = function(){
		if($(this).is(':checked')){
			clearPageBreaks();
			Tapas.showPbs = false;
		}else{
			addPageBreaks();
			Tapas.showPbs = true;
		}
	};
	addPageBreaks();
	$(this).checked = false;
}

$(document).ready(function(){
	console.log("I'm ready");
	init();
	$("#viewBox").change(function(e){
		switchThemes(e);
	});
});

function switchThemes(event) { // This needs to be changed so TAPAS can include TEI as a div instead of an iframe
// 	console.log("we are in switchThemes");
//     var cssFile = jQuery(event.target).val();
//     if (cssFile == '../css/tapasGdiplo.css') {
//         Tapas.currentTheme = 'diplomatic';
//     } else {
//         Tapas.currentTheme = 'normalized';
//     }
//     if (Tapas.showPbs) {
//         addPageBreaks();
//     }
// 	document.getElementById('maincss').href = jQuery(event.target).val();
// 	console.log(Tapas.currentTheme);
	$(".tapas-generic").removeClass('diplomatic').removeClass('normal').addClass($(this).val());
	Tapas.currentTheme = $(this).val();
	// switchThemes(e);
	console.log("we changed");
	console.log(Tapas.currentTheme);
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
