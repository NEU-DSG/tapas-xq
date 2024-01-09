xquery version "3.1";

  module namespace tap="http://tapasproject.org/tapas-xq/api";
(:  LIBRARIES  :)
  import module namespace Session="http://basex.org/modules/session";
  import module namespace tgen="http://tapasproject.org/tapas-xq/general"
    at "general-functions.xql";
(:  NAMESPACES  :)
  declare default element namespace "http://www.w3.org/1999/xhtml";
  declare namespace array="http://www.w3.org/2005/xpath-functions/array";
  declare namespace bin="http://expath.org/ns/binary";
  declare namespace db="http://basex.org/modules/db";
  declare namespace http="http://expath.org/ns/http-client";
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace perm="http://basex.org/modules/perm";
  declare namespace request="http://exquery.org/ns/request";
  declare namespace rest="http://exquery.org/ns/restxq";
  declare namespace tapas="http://www.wheatoncollege.edu/TAPAS/1.0";
  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace update="http://basex.org/modules/update";
  declare namespace user="http://basex.org/modules/user";
  declare namespace validate="http://basex.org/modules/validate";
  declare namespace web="http://basex.org/modules/web";
  declare namespace xhtml="http://www.w3.org/1999/xhtml";
  declare namespace xslt="http://basex.org/modules/xslt";

(:~
  An API for the XML database component of TAPAS.
  
  @author Ash Clark
  @since 2023
 :)
 
 
(:
    VARIABLES
 :)
  
  declare variable $tap:db-name := 'tapas-data';


(:
    PERMISSIONS
    https://docs.basex.org/wiki/Permissions
    https://docs.basex.org/wiki/User_Management
 :)
  
  (:
    All POST and DELETE traffic is funneled through this function first. The current user must have 
    either (A) write-level access across BaseX, or (B) write-level access to the "tapas-data" database.
    If the current user does not have write permissions, the API returns a 401 "Unauthorized" response.
   :)
  declare 
    %perm:check('/tapas-xq')
    %rest:POST
    %rest:DELETE
  function tap:check-user-write-access() {
    let $userInfo := user:list-details(user:current())
    let $userWriteAccess := 
      $userInfo/@permission/data(.) = ('write', 'create', 'admin')
    let $dbWriteAccess :=
      exists($userInfo//Q{}database[@pattern eq $tap:db-name][@permission eq 'write'])
    where not($userWriteAccess or $dbWriteAccess)
    return
      web:error(401, "You must provide valid credentials in order to complete this action.")
  };


(:
    RESTXQ ENDPOINTS
 :)
  
  
  declare
    %rest:GET
    %rest:path("/tapas-xq")
    %output:method("xhtml")
    %output:media-type("text/html")
  function tap:home() {
    <html lang="en">
      <head>
        <title>TAPAS-xq</title>
      </head>
      <body>
        <p>Hello world!</p>
      </body>
    </html>
  };
  
  (: TEMPORARY: used to test that authentication of POST and DELETE requests works.
  declare
    %rest:POST
    %rest:DELETE
    %rest:path("/tapas-xq")
    %output:method("xhtml")
    %output:media-type("text/html")
  function tap:post-test() {
    <p>Success!</p>
  };:)
  
  
  (:~
    Completely removes all database records (TEI file, MODS, TFE) associated with the given TEI core 
    file identifier. Returns a short confirmation that the resources will be deleted. If no TEI document 
    is associated with the given identifier, the response will have a status code of 500.
    
    Originally ../legacy/delete-by-docid.xq .
    
    @param project-id the unique identifier of the project which owns the core file
    @param doc-id a unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE)
    @return XML
   :)
  declare
    %updating
    %rest:DELETE
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:delete-core-file($project-id as xs:string, $doc-id as xs:string) {
    (: Originally, this endpoint returned a 200 response, since it could check to make sure that the 
    file was gone after deletion. The "202 Accepted" response is more appropriate now, since we can only 
    promise that we *will* delete the item, we can't say that we *have done* it. :)
    let $successCode := 202
    let $response := 
      let $teiDoc := tap:get-stored-xml($project-id, $doc-id)
      return 
        tap:plan-response($successCode, ($teiDoc), 
          <p>Deleting core file {$doc-id} and associated files in project {$project-id}.</p>)
    return (
        (: Delete the core file only if the response anticipates success. (Note that, unlike in eXist, 
        the deletion must occur at the end of execution. This function can't be *certain* that deletion 
        will occur, but it can check for odds of success (authenticated user, available documents). :)
        if ( tap:is-expected-response($response, $successCode) ) then
          db:delete($tap:db-name, concat($project-id,'/',$doc-id))
        else ()
        ,
        update:output($response)
      )
  };
  
  
  (:~
    Completely removes all database records associated with the given TAPAS project identifier. Returns 
    a short confirmation that the resources will be deleted. If no XML documents are associated with the 
    given project ID, the response will have a status code of 500.
    
    Originally ../legacy/delete-by-projid.xq .
    
    @param project-id the unique identifier of the project to be deleted
    @return XML
   :)
  declare
    %updating
    %rest:DELETE
    %rest:path("/tapas-xq/{$project-id}")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:delete-project-docs($project-id as xs:string) {
    (: See comments in tap:delete-core-file() above for info on this HTTP status code. :)
    let $successCode := 202
    let $response := 
      let $numDocs := tap:count-project-docs($project-id)
      return 
        tap:plan-response($successCode, ($numDocs), 
          <p>Deleting {$numDocs} resources in project {$project-id}.</p>)
    return (
        (: Delete the core file only if the response anticipates success. :)
        if ( tap:is-expected-response($response, $successCode) ) then
          db:delete($tap:db-name, $project-id)
        else ()
        ,
        update:output($response)
      )
  };
  
  
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
    
    Originally ../legacy/store-tei.xq .
    
    @param project-id the unique identifier of the project which owns the work
    @param doc-id a unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE) 
    @param file the TEI-encoded XML document to be stored
    @return XML
   :)
  declare
    %updating
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/tei")
    %rest:form-param('file', '{$file}')
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file($project-id as xs:string, $doc-id as xs:string, $file as item()) {
    let $successCode := 201
    let $fileXML := tap:get-file-content($file)
    let $xmlFileIsTEI :=
      if ( $fileXML instance of element(tap:err) ) then ()
      else tap:validate-tei-minimally($fileXML)
    let $filepath := concat($project-id,'/',$doc-id,'/',$doc-id,'.xml')
    let $possiblyErroneous := ( $fileXML, $xmlFileIsTEI )
    let $response := tap:plan-response($successCode, $possiblyErroneous)
    return (
        (: Only store TEI if there were no errors. :)
        if ( tap:is-expected-response($response, $successCode) ) then  
          db:put($tap:db-name, $fileXML, $filepath)
        else ()
        ,
        update:output($response)
      )
  };
  
  
  (:~
    Derive MODS production file from a TEI document and store it in the database.
    
    Originally ../legacy/store-mods.xq .
    
    @param project-id the unique identifier of the project which owns the work
    @param doc-id a unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE) 
    @param collections comma-separated list of collection identifiers with which the work should be associated
    @param is-public indicates if the XML document should be queryable by the public. (Note that if the document belongs to even one public collection, it should be queryable.)
    @return XML
   :)
  declare
    %updating
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
    let $successCode := 201
    let $teiDoc := tap:get-stored-xml($project-id, $doc-id)
    let $xslParams := map {
        'displayTitle': $title,
        'displayAuthors': $authors,
        'displayContributors': $contributors,
        'timelineDate': $timeline-date
      }
    let $mods :=
      (: Skip transformation if the TEI file hasn't been stored. :)
      if ( $teiDoc instance of element(tap:err) ) then ()
      else
        try {
          xslt:transform($teiDoc, doc("../resources/tapas2mods.xsl"), $xslParams)
        } catch * {
          <tap:err code="500">Could not transform {$doc-id} into MODS</tap:err>
        }
    let $filepath := concat($project-id,'/',$doc-id,'/mods.xml')
    let $possiblyErroneous := ( $teiDoc, $mods )
    let $response := tap:plan-response($successCode, $possiblyErroneous)
    return (
        (: Only store MODS if there were no errors. :)
        if ( tap:is-expected-response($response, $successCode) ) then
          db:put($tap:db-name, $mods, $filepath)
        else ()
        ,
        update:output($response)
      )
  };
  
  
  (:~
    Store 'TAPAS-friendly-environment' metadata. Triggers the generation of a small XML file containing 
    useful information about the context of the TEI document, such as its parent project. Returns path 
    to the TFE file within the database, with status code 201. If no TEI document is associated with the 
    given doc-id, the response will have a status code of 500. The TEI file must be stored before any of 
    its derivatives.
    
    Originally ../legacy/store-tfe.xq .
    
    @param project-id the unique identifier of the project which owns the work
    @param doc-id a unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE) 
    @param collections comma-separated list of collection identifiers with which the work should be associated
    @param is-public (optional) indicates if the XML document should be queryable by the public. The default is 'false'. (Note that if the document belongs to even one public collection, it should be queryable.)
    @return XML
   :)
  declare
    %updating
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/tfe")
    %rest:form-param('collections', '{$collections}')
    %rest:form-param('is-public', '{$is-public}', "false")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file-tfe($project-id as xs:string, $doc-id as xs:string, 
     $collections as xs:string+, $is-public as xs:boolean) {
    let $successCode := 201
    let $useCollections :=
      let $tokens :=
        for $str in $collections
        return tokenize($str, ',')[normalize-space() ne '']
      return
        <tapas:collections>{
          for $token in $tokens
          return
            <tapas:collection>{ $token }</tapas:collection>
        }</tapas:collections>
    let $tfe :=
      <tapas:metadata>
        <tapas:owners>
          <tapas:project>{ $project-id }</tapas:project>
          <tapas:document>{ $doc-id }</tapas:document>
          { $useCollections }
        </tapas:owners>
        <tapas:access>{ $is-public }</tapas:access>
      </tapas:metadata>
    let $filepath := concat($project-id,'/',$doc-id,'/tfe.xml')
    let $response := 
      let $teiDoc := tap:get-stored-xml($project-id, $doc-id)
      return tap:plan-response($successCode, ($teiDoc))
    return (
        (: Only store the TFE if there were no errors. :)
        if ( tap:is-expected-response($response, $successCode) ) then
          db:put($tap:db-name, $tfe, $filepath)
        else ()
        ,
        update:output($response)
      )
  };


(:
    SUPPORT FUNCTIONS
 :)
  
  (:~
    Build an HTTP response from only a status code.
   :)
  declare function tap:build-response($status-code as xs:integer) as item()+ {
    tap:build-response($status-code, (), ())
  };
  
  (:~
    Build an HTTP response.
   :)
  declare function tap:build-response($status-code as xs:integer, $content as item()*) as item()+ {
    tap:build-response($status-code, $content, ())
  };
  
  (:~
    Build an HTTP response.
   :)
  declare function tap:build-response($status-code as xs:integer, $content as item()*, $headers as item()*) as item()+ {
    (: If $content appears to be an integer, then this function treats that integer as an error code. :)
    let $noContentProvided := empty($content)
    return (
        <rest:response>
          <http:response status="{$status-code}">
            { $headers }
          </http:response>
        </rest:response>
        ,
        if ( $noContentProvided ) then
          tgen:set-status-description($status-code)
        else $content
      )
  };
  
  (:~
    Given a sequence of items, find any <tap:err> problems and compile them into an HTML report. If 
    there are no errors, this function will return an empty sequence.
   :)
  declare function tap:compile-errors($sequence as item()*) as element()? {
    let $errors :=
      for $item in $sequence
      return
        typeswitch ($item)
          case element(tap:err) return $item
          default return ()
    (: Define a little function to trim excess whitespace and recover from an empty error message. :)
    let $useMessage := function ($error as element(tap:err)) as xs:string {
        let $msg := normalize-space($error)
        let $code := $error/@code/xs:integer(.)
        return
          if ( $msg eq '' and exists($code) ) then
            tgen:get-error($code)
          else if ( $msg eq '' ) then
            "Unknown error raised"
          else $msg
      }
    return
      if ( empty($errors) ) then ()
      else if ( count($errors) eq 1 ) then
        <p>Problem found: { $useMessage($errors) }</p>
      else
        <div>
          <h1>Problems found!</h1>
          <ul>{
            for $err in $errors
            return
              <li>{ $useMessage($err) }</li>
          }</ul>
        </div>
  };
  
  (:~
    Determine how many XML documents are available in a given project, and return an error if the 
    project id does not match any records.
   :)
  declare function tap:count-project-docs($project-id as xs:string) {
    (: Set up an error if the document doesn't exist. :)
    let $numDocs := count(db:list($tap:db-name, $project-id))
    return
      if ( $numDocs gt 0 ) then $numDocs
      else tgen:set-error(400, "Project not found: "||$project-id)
  };
  
  declare function tap:list-project-core-files($project-id as xs:string) {
    let $allFiles := db:list($tap:db-name, $project-id)
    return
      if ( count($allFiles) eq 0 ) then
        tgen:set-error(400, "Project not found: "||$project-id)
      else
        for $filename in $allFiles
        let $dirPath := replace($filename, '/[^/]+$', '')
        group by $dirPath
        return $dirPath
  };
  
  declare function tap:list-core-file-docs($project-id as xs:string, $doc-id as xs:string) {
    let $coreFilePath := concat($project-id,'/',$doc-id)
    return
      (: Set up an error if the document doesn't exist. :)
      if ( not(db:exists($tap:db-name, $project-id)) ) then
        tgen:set-error(400, "Project not found: "||$project-id)
      else db:list($tap:db-name, $coreFilePath)
  };
  
  (:~
    Clean data to get XML, replacing any instances of U+FEFF that might make a processor consider the 
    XML "invalid."
   :)
  declare function tap:get-file-content($file) {
    typeswitch($file)
      case node() return $file
      (: When files are sent with POST requests, BaseX puts those files in a map, with the filename as 
        the key. :)
      case map(xs:string, item()*) return 
        let $filename := map:keys($file)
        return
          if ( count($filename) ne 1 ) then
            tgen:set-error(422, "Can accept only one XML file at a time")
          else tap:get-file-content($file?($filename))
      case xs:string return 
        let $cleanStr := replace($file, '﻿', '')
        let $xml :=
          try {
            parse-xml($cleanStr)
          } catch * { 
            tgen:set-error(422, "Could not parse plain text as XML")
          }
        return 
          if ( $xml instance of element(tap:err) ) then $xml
          else tap:get-file-content($xml)
      case xs:base64Binary return 
        (: Try decoding the file as UTF-8 or UTF-16. :)
        let $decodedFile :=
          let $decodedFileUTF8 :=
            try {
              bin:decode-string($file)
              => tap:get-file-content()
            } catch * { () }
          return
            if ( empty($decodedFileUTF8) or $decodedFileUTF8 instance of element(tap:err) ) then
              try {
                bin:decode-string($file, 'utf-16')
                => tap:get-file-content()
              } catch * { () }
            else $decodedFileUTF8
        return
          (: Return an error message if the binary file could not be decoded. :)
          if ( empty($decodedFile) ) then
            tgen:set-error(422, "Could not read binary file as encoded with UTF-8 or UTF-16")
          else $decodedFile
      default return 
        tgen:set-error(422, "Provided file must be TEI-encoded XML. Received unknown type")
  };
  
  (:~
    Try to retrieve a TEI "core file" document stored in the TAPAS database, and return an error if the 
    document doesn't exist.
   :)
  declare function tap:get-stored-xml($project-id as xs:string, $doc-id as xs:string) {
    tap:get-stored-xml($project-id, $doc-id, concat($doc-id,'.xml'))
  };
  
  (:~
    Try to retrieve an XML document stored in the TAPAS database, and return an error if the document 
    doesn't exist.
   :)
  declare function tap:get-stored-xml($project-id as xs:string, $doc-id as xs:string, $filename as xs:string) as node()? {
    let $filepath := concat($project-id,'/',$doc-id,'/',$filename)
    return
      (: Set up an error if the document doesn't exist. :)
      if ( not(db:exists($tap:db-name, $filepath)) ) then
        tgen:set-error(400, "Document not found: "||$filepath)
      else db:get($tap:db-name, $filepath)
  };
  
  (:~
    Determine if a response matches the expected HTTP code.
   :)
  declare function tap:is-expected-response($response as item()+, $expected-code as xs:integer) as xs:boolean {
    $response[1]//http:response/@status/xs:integer(.) eq $expected-code
  };
  
  (:~
    Test a sequence of items for <tap:err> flags. Returns a response depending on whether the request 
    can be considered successful or not.
   :)
  declare function tap:plan-response($success-code as xs:integer, $possible-errors as item()*) as item()* {
    tap:plan-response($success-code, $possible-errors, ())
  };
  
  (:~
    Test a sequence of items for <tap:err> flags. Returns a response depending on whether the request 
    can be considered successful or not. If $response-body is provided, it is used as the main content 
    of a successful response.
   :)
  declare function tap:plan-response($success-code as xs:integer, $possible-errors as item()*, $response-body as item()?) as item()* {
    let $errors := tap:compile-errors($possible-errors)
    return
      (: Build a response using existing errors and a HTTP status code. :)
      if ( exists($errors) and exists($possible-errors[@code]) ) then
        tap:build-response($possible-errors[@code][1]/@code, $errors)
      (: Use a generic 400 error if no status code was found. :)
      else if ( exists($errors) ) then
        tap:build-response(400, $errors)
      (: If a response body was provided, use that in the success response. :)
      else if ( exists($response-body) ) then
        tap:build-response($success-code, $response-body)
      (: Otherwise, just use the success HTTP code. :)
      else tap:build-response($success-code)
  };
  
  (:~
    Determine if a well-formed XML document looks like TEI. If the XML looks fine, the function returns 
    an empty sequence.
   :)
  declare function tap:validate-tei-minimally($document as node()) as element(tap:err)* {
    (: The minimal Schematron returns plain text, with one line per flagged error. We wrap each one in a 
      <tap:err> for later compilation. :)
    let $validationErrors :=
      let $report := xslt:transform-text($document, doc('../resources/isTEI.xsl'))
      for $msg in tokenize($report, '&#xA;')
      return tgen:set-error(422, $msg)
    (: Skip any whitespace-only lines or empty strings leftover from tokenizing the validation report. :)
    return $validationErrors[normalize-space() ne '']
  };
