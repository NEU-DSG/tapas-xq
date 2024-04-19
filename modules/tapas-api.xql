xquery version "3.1";

  module namespace tap="http://tapasproject.org/tapas-xq/api";
(:  LIBRARIES  :)
  import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs"
    at "view-packages.xql";
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
  This is the API for TAPAS-xq, the XML database component of TAPAS. TAPAS-xq stores TEI documents, 
  indexes them, and generates derivatives such as MODS metadata and reading interface XHTML.
  
  TAPAS-xq also maintains a registry of “<a href="https://github.com/NEU-DSG/tapas-view-packages">view 
  packages</a>”. Each view package includes: a program for generating a “view” (a web page); web assets 
  for displaying that page; and a configuration file describing these contents. TAPAS-xq is mostly 
  concerned with the program component, and the configuration file which defines how to execute that 
  program.
  
  All POST and DELETE requests <strong>must</strong> include an Authentication header containing the 
  credentials for a BaseX user with write access to the TAPAS databases. If a request doesn’t meet this
  criteria, a response with an HTTP status code 401 will be returned.
  
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
  
  (:~
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
  
  (:~
    Generate documentation for the TAPAS-xq API, in XHTML or Markdown.
    
    @param format The formatting method to use when producing documentation. Valid options are 
      "markdown" or "html". The default is to return XHTML.
    @return a representation of the API documentation, with status code 200.
   :)
  (: NOTE: Because we're producing two wildly different formats of documentation at the same endpoint, 
    this function is set up as generically as possible, with the plaintext output method. To ensure that 
    the HTML version is rendered correctly, we use `serialize()` before returning the response with the 
    right "Content-Type" header. :)
  declare
    %rest:GET
    %rest:path("/tapas-xq/api")
    %rest:query-param('format', '{$format}', 'html')
    %output:method('text')
  function tap:get-documentation($format as xs:string?) {
    let $successCode := 200
    let $formatAsMarkdown := lower-case($format) eq 'markdown'
    let $xqDocXML := inspect:xqdoc('tapas-api.xql')
    let $outputDocs := 
      let $params := map {
          'html-title': "TAPAS-xq API",
          'source-code-url':
            "https://github.com/NEU-DSG/tapas-xq/blob/migrate/to-basex-10/modules/tapas-api.xql"
        }(: TODO: update link! :)
      return
        if ( $formatAsMarkdown ) then
          xslt:transform-text($xqDocXML, doc('../resources/xqdoc-to-markdown.xsl'), $params)
        else
          xslt:transform($xqDocXML, doc('../resources/xqdoc-to-api-docs.xsl'), $params)
          => serialize()
    let $mediaTypeHeader :=
      let $contentType := if ( $formatAsMarkdown ) then 'markdown' else 'html'
      return
        <http:header name="Content-Type" value="text/{$contentType}; charset=utf-8"/>
    return tap:build-response($successCode, $outputDocs, $mediaTypeHeader)
  };
  
  
  (:~
    Store a TEI record into the XML database, as well as MODS metadata and “TAPAS-friendly environment” 
    (TFE) metadata. The generated MODS metadata record is also returned in the HTTP response.
    
    This endpoint is a convenient wrapper for the “Store core file”, “Store core file object 
    description”, and “Store core file contextual metadata” endpoints. When a core file is initially 
    created, this endpoint alone will suffice to generate everything needed by TAPAS-xq and Rails.
    
    @param project-id The unique identifier of the project which owns the work.
    @param doc-id A unique identifier for the document record attached to the original TEI document and 
      its derivatives.
    @param file The TEI-encoded XML document to be stored.
    @param collections Comma-separated list of collection identifiers with which the work should be 
      associated.
    @param is-public Optional. Value of “true” or “false”. Indicates if the XML document should be 
      queryable by the public. By default, the document is considered private. (Note that if the 
      document belongs to even one public collection, it should be queryable.)
    @param title Optional. The work’s title as it should appear in TAPAS metadata.
    @param authors Optional. A list of authors’ names as they should appear in TAPAS metadata, separated 
      by vertical bars.
    @param contributors Optional. A list of contributors’ names as they should appear in TAPAS metadata, 
      separated by vertical bars.
    @return the MODS record derived from the TEI file, with HTTP status code 201. Any problems with the 
      TEI file will result in a response code of 500. If the MODS file could not be generated due to 
      transformation issues, the TEI and TFE files will still be stored despite the response error code.
   :)
  declare
    %updating
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}")
    %rest:form-param('file', '{$file}')
    %rest:form-param('collections', '{$collections}')
    %rest:form-param('is-public', '{$is-public}', "false")
    %rest:form-param('title', '{$title}')
    %rest:form-param('authors', '{$authors}')
    %rest:form-param('contributors', '{$contributors}')
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file-and-supplementals($project-id as xs:string, $doc-id as xs:string, 
     $file as item(), $collections as xs:string+, $is-public as xs:boolean,
     $title as xs:string?, $authors as xs:string?, $contributors as xs:string?) {
    let $successCode := 201
    let $fileXML := tap:get-file-content($file)
    let $xmlFileIsTEI :=
      if ( $fileXML instance of element(tap:err) ) then ()
      else tap:validate-tei-minimally($fileXML)
    let $teiErrors := tgen:find-errors(( $fileXML, $xmlFileIsTEI ))
    return
      (: If there are problems with the TEI, nothing should be done. Report the errors. :)
      if ( exists($teiErrors) ) then
        update:output(tap:plan-response($successCode, $teiErrors))
      else
        let $docBasePath := concat($project-id,'/',$doc-id,'/')
        (: Use the TEI header and user-provided fields to generate MODS. :)
        let $mods := tap:generate-mods($fileXML, $title, $authors, $contributors)
        (: Generate a TFE file to provide context for the TEI's searchability in TAPAS. :)
        let $tfe := tap:generate-tfe($project-id, $doc-id, $collections, $is-public)
        (: If the MODS couldn't be generated but we still intend to store the TEI and TFE, some fake 
          "errors" are used to log that nuance. :)
        let $erroneous :=
          if ( empty(tgen:find-errors($mods)) ) then ()
          else ( 
              <tap:err>TEI is stored</tap:err>,
              <tap:err>TFE is stored</tap:err>,
              $mods
            )
        let $response := tap:plan-response($successCode, $erroneous, $mods)
        return (
            db:put($tap:db-name, $fileXML, concat($docBasePath,$doc-id,'.xml')),
            db:put($tap:db-name, $tfe, concat($docBasePath,'/tfe.xml')),
            (: Only store the MODS if the transformation had no issues. :)
            if ( tap:is-expected-response($response, $successCode) ) then
              db:put($tap:db-name, $mods, concat($docBasePath,'/mods.xml'))
            else (),
            update:output($response)
          )
  };
  
  
  (:~
    Store a TEI document.
    
    @param project-id The unique identifier of the project which owns the work.
    @param doc-id A unique identifier for the document record attached to the original TEI document and 
      its derivatives (MODS, TFE).
    @param file The TEI-encoded XML document to be stored.
    @return XML containing the path to the TEI file within the database, with status code 201.
   :)
  (: Originally ../legacy/store-tei.xq :)
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
    let $response := tap:plan-response($successCode, $possiblyErroneous, <p>{ $filepath }</p>)
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
    Construct a MODS metadata record using the TEI header and any additional information provided in the 
    request. Store the MODS in the database alongside its core file TEI.
    
    The TEI core file must be stored <em>before</em> any of its derivatives.
    
    @param project-id The unique identifier of the project which owns the work.
    @param doc-id A unique identifier for the document record attached to the original TEI document and 
      its derivatives. 
    @param title Optional. The work’s title as it should appear in TAPAS metadata.
    @param authors Optional. A list of authors’ names as they should appear in TAPAS metadata, separated 
      by vertical bars.
    @param contributors Optional. A list of contributors’ names as they should appear in TAPAS metadata, 
      separated by vertical bars.
    @return the MODS record derived from the TEI file, with status code 201. If no TEI document is 
      associated with the given <code class="param">doc-id</code>, the response will have a status code 
      of 500.
   :)
  (: Originally ../legacy/store-mods.xq :)
  declare
    %updating
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/mods")
    %rest:form-param('title', '{$title}')
    %rest:form-param('authors', '{$authors}')
    %rest:form-param('contributors', '{$contributors}')
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file-object-description($project-id as xs:string, $doc-id as xs:string, 
     $title as xs:string?, $authors as xs:string?, $contributors as xs:string?) {
    let $successCode := 201
    let $teiDoc := tap:get-stored-xml($project-id, $doc-id)
    let $mods := tap:generate-mods($teiDoc, $title, $authors, $contributors)
    let $filepath := concat($project-id,'/',$doc-id,'/mods.xml')
    let $possiblyErroneous := ( $teiDoc, $mods )
    let $response := tap:plan-response($successCode, $possiblyErroneous, $mods)
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
    Store “TAPAS-friendly environment” (TFE) metadata. Triggers the generation of a small XML file 
    containing useful information about the context of the TEI document, such as its parent project.
    
    The TEI core file must be stored <em>before</em> any of its derivatives.
    
    @param project-id The unique identifier of the project which owns the work.
    @param doc-id A unique identifier for the document record attached to the original TEI document and 
      its derivatives.
    @param collections Comma-separated list of collection identifiers with which the work should be 
      associated.
    @param is-public Optional. Value of “true” or “false”. Indicates if the XML document should be 
      queryable by the public. By default, the document is considered private. (Note that if the 
      document belongs to even one public collection, it should be queryable.)
    @return the path to the new TFE file within the database, with status code 201. If no TEI document 
      is associated with the given <code class="param">doc-id</code>, the response will have a status 
      code of 500.
   :)
  (: Originally ../legacy/store-tfe.xq :)
  declare
    %updating
    %rest:POST
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/tfe")
    %rest:form-param('collections', '{$collections}')
    %rest:form-param('is-public', '{$is-public}', "false")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:store-core-file-contextual-metadata($project-id as xs:string, $doc-id as xs:string, 
     $collections as xs:string+, $is-public as xs:boolean) {
    let $successCode := 201
    let $tfe := tap:generate-tfe($project-id, $doc-id, $collections, $is-public)
    let $filepath := concat($project-id,'/',$doc-id,'/tfe.xml')
    let $response := 
      let $teiDoc := tap:get-stored-xml($project-id, $doc-id)
      return 
        tap:plan-response($successCode, ($teiDoc), <p>{ $filepath }</p>)
    return (
        (: Only store the TFE if there were no errors. :)
        if ( tap:is-expected-response($response, $successCode) ) then
          db:put($tap:db-name, $tfe, $filepath)
        else ()
        ,
        update:output($response)
      )
  };
  
  
  (:~
    Given the name of a TAPAS view package, generate an XHTML file from the provided TEI document. The 
    generated XHTML is not a full webpage but a <code>&lt;div&gt;</code> snippet, suitable for inclusion 
    in the TAPAS reading interface. 
    
    The XML database does not store any files as a result of this request.
    
    Note that additional form parameters may be available, depending on the view package selected. Check 
    the view package’s configuration file for additional parameters.
    
    @param type A keyword representing the type of reader view to generate. Valid keywords can be found 
      by making a request to  the “List registered view packages” endpoint.
    @param file A TEI-encoded XML document. If, in the future, a view package makes use of a different 
      input source (such as a TAPAS collection or a project), the file parameter may become optional.
    @return generated XHTML with status code 200.
   :)
  (: Originally ../legacy/derive-reader.xq :)
  declare
    %rest:POST
    %rest:path("/tapas-xq/derive-reader/{$type}")
    %rest:form-param('file', '{$file}')
    %output:method("xhtml")
    %output:media-type("text/html")
  function tap:derive-reader($type as xs:string, $file as item()) {
    let $successCode := 200
    let $isKnownType :=
      if ( not(dpkg:can-read-registry()) ) then
        tgen:set-error(500, "This user does not have read access to the view package database.")
      else if ( dpkg:is-known-view-package($type) ) then () 
      else tgen:set-error(400, "There is no view package named '"||$type||"'")
    let $fileXML := tap:get-file-content($file)
    let $xmlFileIsTEI :=
      if ( $fileXML instance of element(tap:err) ) then () else
        tap:validate-tei-minimally($fileXML)
    let $possiblyErroneous := ( $isKnownType, $fileXML, $xmlFileIsTEI )
    let $requestedHtml :=
      if ( exists(tap:compile-errors($possiblyErroneous)) ) then () else
        let $viewPkgRunStmt := dpkg:get-run-stmt($type)
        let $runType := $viewPkgRunStmt/@type/data(.)
        return
          switch ( $runType )
            case 'xslt' return
              let $xslPath := 
                dpkg:get-path-from-package($type, $viewPkgRunStmt/@pgm/data(.))
              let $viewPkgParams := dpkg:set-view-package-parameter-values($type)
              return try {
                  xslt:transform($fileXML, doc($xslPath), $viewPkgParams)
                } catch * {
                  tgen:set-error(500, 'XSLT transformation failed with error "'||$err:description||'" '
                    ||$err:value)
                }
            (: TODO: XProc :)
            (: Any other program type is politely declined. :)
            default return
              let $error :=
                if ( empty($runType) ) then
                  "View package configuration must include a method of transformation"
                else "Programs of type '"||$runType||"' cannot be run."
              return tgen:set-error(501, $error)
    return
      tap:plan-response($successCode, ($possiblyErroneous, $requestedHtml), $requestedHtml)
  };
  
  
  (:~
    Retrieve a TEI file stored in the XML database.
    
    @param project-id The identifier of the project which owns the core file.
    @param doc-id The identifier of the TEI core file.
    @return a copy of the TEI file, with status code 200.
   :)
  declare
    %rest:GET
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/tei")
    %output:indent("no")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:read-core-file($project-id as xs:string, $doc-id as xs:string) {
    let $successCode := 200
    let $file := tap:get-stored-xml($project-id, $doc-id)
    return tap:plan-response($successCode, $file, $file)
  };
  
  
  (:~
    Retrieve a MODS file associated with a given core file identifier.
    
    @param project-id The identifier of the project which owns the core file.
    @param doc-id The identifier of the TEI core file.
    @return a copy of the MODS metadata, with status code 200.
   :)
  declare
    %rest:GET
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/mods")
    %output:indent("yes")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:read-core-file-object-description($project-id as xs:string, $doc-id as xs:string) {
    let $successCode := 200
    let $file := tap:get-stored-xml($project-id, $doc-id, 'mods.xml')
    return tap:plan-response($successCode, $file, $file)
  };
  
  
  (:~
    Retrieve a TAPAS-friendly environment (TFE) file associated with a given core file identifier.
    
    @param project-id The identifier of the project which owns the core file.
    @param doc-id The identifier of the TEI core file.
    @return a copy of the TFE metadata, with status code 200.
   :)
  declare
    %rest:GET
    %rest:path("/tapas-xq/{$project-id}/{$doc-id}/tfe")
    %output:indent("yes")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:read-core-file-contextual-metadata($project-id as xs:string, $doc-id as xs:string) {
    let $successCode := 200
    let $file := tap:get-stored-xml($project-id, $doc-id, 'tfe.xml')
    return tap:plan-response($successCode, $file, $file)
  };
  
  
  (:~
    Completely remove all database records associated with a given TEI core file identifier: TEI file, 
    MODS metadata, and TAPAS-friendly environment record.
    
    @param project-id The identifier of the project which owns the core file.
    @param doc-id The identifier of the TEI core file.
    @return a short confirmation in XML that the resources will be deleted, with status code 202. If no 
      TEI document is associated with the given identifier, the response will have a status code of 500.
   :)
  (: Originally ../legacy/delete-by-docid.xq :)
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
          the deletion must occur at the end of execution. This function can't be *certain* that 
          deletion will occur, but it can check for odds of success (authenticated user, available 
          documents). :)
        if ( tap:is-expected-response($response, $successCode) ) then
          db:delete($tap:db-name, concat($project-id,'/',$doc-id))
        else ()
        ,
        update:output($response)
      )
  };
  
  
  (:~
    Completely remove all database records associated with the given TAPAS project.
    
    @param project-id The unique identifier of the project to be deleted.
    @return a short confirmation in XML that the resources will be deleted, with status code 202. If no 
      TEI document is associated with the given identifier, the response will have a status code of 500.
   :)
  (: Originally ../legacy/delete-by-projid.xq :)
  declare
    %updating
    %rest:DELETE
    %rest:path("/tapas-xq/{$project-id}")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:delete-project-documents($project-id as xs:string) {
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
    Retrieve the XML registry of all view packages currently available in TAPAS-xq.
    
    @return the XML registry of view packages, with status code 200.
   :)
  declare
    %rest:GET
    %rest:path("/tapas-xq/view-packages")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:list-registered-view-packages() {
    let $successCode := 200
    let $registry := 
      if ( not(dpkg:can-read-registry()) ) then
        tgen:set-error(401, "This user does not have read access to the view package database.")
      else dpkg:get-registry()
    return tap:plan-response($successCode, $registry, $registry)
  };
  
  
  (:~
    Retrieve the configuration file for a given view package.
    
    @param package-id The identifier of the view package.
    @return the XML configuration file of the view package with status code 200. If the requested 
      identifier does not match a view package registered with TAPAS-xq, the response will have a status 
      code of 400.
   :)
  declare
    %rest:GET
    %rest:path("/tapas-xq/view-packages/{$package-id}")
    %output:method("xml")
    %output:media-type("application/xml")
  function tap:get-view-package-configuration($package-id as xs:string) {
    let $successCode := 200
    let $configFile :=
      if ( not(dpkg:can-read-registry()) ) then
        tgen:set-error(401, "This user does not have read access to the view package database.")
      else if ( not(dpkg:is-known-view-package($package-id)) ) then
        tgen:set-error(400, "A view package named '"||$package-id||"' is not available")
      else dpkg:get-configuration($package-id)
    return tap:plan-response($successCode, $configFile, $configFile)
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
    Build an HTTP response with some content in the response body.
   :)
  declare function tap:build-response($status-code as xs:integer, $content as item()*) as item()+ {
    tap:build-response($status-code, $content, ())
  };
  
  (:~
    Build an HTTP response with a response body and response headers.
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
    let $errors := tgen:find-errors($sequence)
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
  
  (:~
    Generate a MODS metadata record from a TEI file and some user-provided fields.
   :)
  declare %private function tap:generate-mods($tei as node(), $title as xs:string?, $authors as 
     xs:string?, $contributors as xs:string?) {
    let $xslParams := 
      let $paramEntries := (
          if ( exists($title) ) then
            map:entry('displayTitle', $title)
          else (),
          if ( exists($authors) ) then
            map:entry('displayAuthors', $authors)
          else (),
          if ( exists($contributors) ) then
            map:entry('displayContributors', $contributors)
          else ()
        )
      return map:merge($paramEntries)
    return
      (: Skip transformation if something's wrong with the TEI file, or if it isn't available. :)
      if ( $tei instance of element(tap:err) ) then ()
      else
        try {
          xslt:transform($tei, doc("../resources/tapas2mods.xsl"), $xslParams)
        } catch * {
          <tap:err code="500">Could not transform TEI file into MODS. Error code {$err:code}: {
            $err:description}</tap:err>
        }
  };
  
  (:~
    Generate a “TAPAS-friendly environment” (TFE) metadata file.
   :)
  declare %private function tap:generate-tfe($project-id as xs:string, $doc-id as xs:string, 
     $collections as xs:string+, $is-public as xs:boolean) {
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
    return
      <tapas:metadata>
        <tapas:owners>
          <tapas:project>{ $project-id }</tapas:project>
          <tapas:document>{ $doc-id }</tapas:document>
          { $useCollections }
        </tapas:owners>
        <tapas:access>{ $is-public }</tapas:access>
      </tapas:metadata>
  };
  
  (:~
    Given a project identifier, list all files associated with that project.
   :)
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
  
  (:~
    Given a project and a document identifier, list all files associated with that core file.
   :)
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
    doesn't exist or should not be read by the current user.
   :)
  declare function tap:get-stored-xml($project-id as xs:string, $doc-id as xs:string, $filename as 
     xs:string) as node()? {
    let $filepath := concat($project-id,'/',$doc-id,'/',$filename)
    let $isPublic := 
      db:get($tap:db-name, concat($project-id,'/',$doc-id,'/tfe.xml'))
        //tapas:access/xs:boolean(.)
    return
      (: Set up an error if the document doesn't exist. :)
      if ( not(db:exists($tap:db-name, $filepath)) ) then
        tgen:set-error(404, "Document not found: "||$filepath)
      (: TODO: This is an overly-simplistic test — any account with write access to the DB should also 
        be able to read the doc. :)
      else if ( user:current() ne 'tapas' and not($isPublic) ) then
        tgen:set-error(403, "Access forbidden. Requested document is not publicly available.")
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
