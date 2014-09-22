var Tapas = {};


//Set up an object to help deal with the needs of negiating through the document-database
Tapas.displayRefData = function(e) {
    var html = '';
    var target = e.target;
    var ref = $(target).data('tapasHashedRef');
    while (typeof ref == "undefined") {
        var target = target.parentNode;
        ref = $(target).data('tapasHashedRef');
    }
    var clickTarget = $(e.target).parent("[id]");
    //and here we work around different policies about id formation. First, try direct equivalence
    var id = clickTarget.attr('id');
    var aTarget = $("a[id='" + ref + "']");
    if(aTarget.length != 0  ) {
        //bop back up to the enclosing p@class='contextualItem'. it looks like that's the most reliable container
        var parentTarget = aTarget.parent("[class='contextualItem']");
        if(parentTarget) {
            //$("#tapas-ref-dialog").dialog('close');
            html += "<p class='tei-element'>TEI element: " + e.target.nodeName + "</p>";
            //desperate effort to produce a consistent, non-code duplicating way to build HTML for the info dialog
            html += Tapas.ographyToHtml(parentTarget);
            console.log(html);
            Tapas.refreshDialog(html, target);
        } else {
            console.log('failed finding target');
        }
    } else {
            console.log('no target');
           //no luck, so try adding a #       
           id = '#' + clickTarget.attr('id');
           var aTarget = $("a[id='" + ref + "']");   
    }
}

Tapas.refreshDialog = function(html, target) {
    $("#tapas-ref-dialog").dialog('close');
    $("#tapas-ref-dialog").html(html);
    //placing the dialog for data display in the big white space currently there. Adjust position via jQueryUI rules for different behavior
    $("#tapas-ref-dialog").dialog( "option", "position", { my: "right", at: "right", of: window });
    $("#tapas-ref-dialog").dialog( "option", "title", $(target).text());
    $("#tapas-ref-dialog").dialog('open');    
}

Tapas.displayNoteData = function(e) {
    var html = '';
    var tapasNoteNum = $(e.target).text();
    console.log(tapasNoteNum);
    console.log(e.target);
    var note = $("note[data-tapas-note-num = '" + tapasNoteNum + "']");
    console.log("note[data-tapas-note-num = '" + tapasNoteNum + "']");
    console.log(note);
    html = note.html();
    Tapas.refreshDialog(html, e.target);
}

/**
 * Produce the HTML to stuff into the modal (popup) for displaying more data
 * Branch around the "ography" type passed in to get to the right nodes, and the right data within them
 * 
 * Currently this is half-built. it might be abandoned, depending on the needs and complexit for data display in the modal
 */

Tapas.ographyToHtml = function(ography) {
    /*
    Tapas.findOgraphyType(ography);
    //this is placeholder in case we need to do something more fancy for the ography types, such as orgNames
    var ographyType = 'person';
    if(ographyType == 'person') {
        var ographyTypeNodeName = 'person';
    }
    var ographyData = ography.children(ographyTypeNodeName);
    */
    //designers will want to watch the classes assigned here. dialog, ography, and ographyType to customize the jQueryUi elements
    //themeroller might be our friend here
    var wrapperHtml = "<div class='wrapper dialog ography '>";
    
    var html = '';
    var children = ography.children();
    
    children.each(function(index, child) {
        switch(child.nodeName) {
            case 'persName':
                var subChildren = $(child).children();
                subChildren.each(function(index, child) {
                    html += "<p>" + "<span class='ography-data'>" + child.nodeName + ": </span> " + child.textContent + "</p>";    
                });
            break;
            
            case 'affiliation':
                var childHtml = $(child).html();
                var when = '';
                
                if(childHtml) {
                    if(typeof $(child).attr('when') != 'undefined') {
                        when = " (" + $(child).attr('when') + ")";    
                    }                
                    html += "<p><span class='ography-data'>" + child.nodeName + when + ": </span>" + childHtml + "</p>";
                }                
            break;
            
            default:
                var childHtml = $(child).html();
                if(childHtml) {
                    html += "<p>" + "<span class='ography-data'>" + child.nodeName + ": </span> " + childHtml + "</p>";
                }
            break;
        }
    });
    if(html == '') {
        html = "<p>No additional data</p>";
    }
    return wrapperHtml + html + "</div>";
}

Tapas.closeDialog = function() {
   $("#tapas-ref-dialog").dialog('close'); 
}

Tapas.findOgraphyType = function(ography) {
    //console.log(ography);
}

//Slap on the events/eventHandlers

$(document).ready(function() {
   var refs = $("[data-tapas-hashed-ref]");
   refs.mouseover(Tapas.displayRefData);
   //refs.mouseout(Tapas.closeDialog);
   var notes = $("[class='note-marker']");
   notes.mouseover(Tapas.displayNoteData);
   Tapas.notes = notes;
   Tapas.refs = refs; // not sure yet if we'll need this data on the Tapas object
   $("#tapas-ref-dialog").dialog({autoOpen: false}); //initialize the dialog, placing and data in it handled by Tapas.displayRefData 
   $("#viewBox").change(switchThemes);
});

    
