function clearPageBreaks(){
	$(".teibp pb").css("display","none");
	$(".teibp .-teibp-pb").css("display","none");
}

function addPageBreaks(){
	$(".teibp pb").css("display","block");
	$(".teibp .-teibp-pb").css("display","block");
}

function init(){
	$(".teibp").addClass('default');
	$('#pbToggle').onclick = function(){
		if($('#pbToggle').checked){
			clearPageBreaks();
		}else{
			addPageBreaks();
		}
	};
	addPageBreaks();
	$('#pbToggle').checked = false;
}

$(document).ready(function(){
	init();
	$("#themeBox").on('change', function(e){
		switchThemes(e);
	});
});

function switchThemes(theme){
	$(".teibp").removeClass('sleepy').removeClass('terminal').removeClass('default').addClass($(theme.target).val());
}
