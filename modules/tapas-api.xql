xquery version "3.1";

  module namespace tap="http://tapasproject.org/tapas-xq/api";
(:  LIBRARIES  :)
(:  NAMESPACES  :)
  (:declare default element namespace "http://www.tei-c.org/ns/1.0";:)
  declare namespace array="http://www.w3.org/2005/xpath-functions/array";
  declare namespace http="http://expath.org/ns/http-client";
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace request="http://exquery.org/ns/request";
  declare namespace rest="http://exquery.org/ns/restxq";
  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace xhtml="http://www.w3.org/1999/xhtml";

(:~
  An API for the XML database component of TAPAS.
  
  @author Ash Clark
  @since 2023
 :)
 
(:  VARIABLES  :)
  


(:  RESTXQ ENDPOINTS  :)
  
  (:~
    Derive XHTML (reading interface) production files from a TEI document. Returns generated XHTML with 
    status code 200. No files are stored as a result of this request.
    
    @param type a keyword representing the type of view package to generate.
    @param file a TEI-encoded XML document
    @return XHTML
   :)
  declare
    %rest:POST
    %rest:path("/tapas-xq/derive-reader/{$type}")
    %rest:form-param('file', '{$file}')
    %output:method("xhtml")
    %output:media-type("text/html")
  function tap:derive-reader($type as xs:string, $file as node()) {
    (: TODO. Originally ../legacy/derive-reader.xq :)
  };
  
  
  (:~
    Store a TEI document. Returns path to the TEI file within the database, with status code 201.
    
    @param project-id the unique identifier of the project which owns the work
    @param doc-id a unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE) 
    @param file the TEI-encoded XML document to be stored
    @return XML
   :)
  declare
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/tei")
    %rest:form-param('file', '{$file}')
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file($project-id as xs:string, $doc-id as xs:string, $file as item()) {
    (: TODO. Originally ../legacy/store-tei.xq :)
  };
  
  
  (:~
    Derive MODS production file from a TEI document and store it in the database.
    
    @param project-id the unique identifier of the project which owns the work
    @param doc-id a unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE) 
    @param collections comma-separated list of collection identifiers with which the work should be associated
    @param is-public indicates if the XML document should be queryable by the public. (Note that if the document belongs to even one public collection, it should be queryable.)
    @return XML
   :)
  declare
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/mods")
    %rest:form-param('title', '{$title}')
    %rest:form-param('authors', '{$authors}')
    %rest:form-param('contributors', '{$contributors}')
    %rest:form-param('timeline-date', '{$timeline-date}')
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file-mods($project-id as xs:string, $doc-id as xs:string, $title as xs:string, 
     $authors as xs:string?, $contributors as xs:string?, $timeline-date as xs:string?) {
    (: TODO. Originally ../legacy/store-mods.xq :)
  };
  
  
  (:~
    Store 'TAPAS-friendly-environment' metadata. Triggers the generation of a small XML file containing 
    useful information about the context of the TEI document, such as its parent project. Returns path 
    to the TFE file within the database, with status code 201. If no TEI document is associated with the 
    given doc-id, the response will have a status code of 500. The TEI file must be stored before any of 
    its derivatives.
    
    @param project-id the unique identifier of the project which owns the work
    @param doc-id a unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE) 
    @param collections comma-separated list of collection identifiers with which the work should be associated
    @param is-public (optional) indicates if the XML document should be queryable by the public. The default is 'false'. (Note that if the document belongs to even one public collection, it should be queryable.)
    @return XML
   :)
  declare
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/tfe")
    %rest:form-param('collections', '{$collections}')
    %rest:form-param('is-public', '{$is-public}', "false")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file-tfe($project-id as xs:string, $doc-id as xs:string, 
     $collections as xs:string+, $is-public as xs:boolean) {
    (: TODO. Originally ../legacy/store-tfe.xq :)
  };


(:  SUPPORT FUNCTIONS  :)
  
  
