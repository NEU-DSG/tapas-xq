xquery version "3.0";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "libraries/view-pkgs.xql";
import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace map="http://www.w3.org/2005/xpath-functions/map";
import module namespace transform="http://exist-db.org/xquery/transform";

(:~
 : `POST exist/apps/tapas-xq/derive-reader/:type` 
 : Derive XHTML (reading interface) production files from a TEI document.
 : 
 : Returns generated XHTML with status code 200. eXist does not store any 
 : files as a result of this request.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: multipart/form-data</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>type: A keyword representing the type of view to generate.</li>
 :    <li>file: A TEI-encoded XML document.</li>
 :  </ul>
 : </ul>
 :
 : @return XHTML
 : 
 : @author Ashley M. Clark
 : @version 1.1
 :
 : 2017-02-01: Restructured this file to allow dynamic view package functionality. 
 :   The view package type is tested first; then the HTTP request is tested against 
 :   the parameters set in the configuration file; then any transformations are run. 
 :   XSLT is currently the only program type supported.
:)

(: Declaring the serialization method to be XHTML keeps tags from self-closing. :)
declare option output:method "xhtml";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {
                                  "type" : 'xs:string',
                                  "file" : 'node()'
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "text/html";

(: The type of reader requested must be tested first, so that the map of expected 
  parameters can be augmented as needed. :)
let $viewType := txq:test-param('type','xs:string')
return
  if ( $viewType[1] instance of xs:string and dpkg:is-valid-view-package($viewType) ) then
    (: Create a new map of the expected parameters using the always-present ones 
      listed above, as well as any parameters defined in the package config file. 
      At this point, the package type has already been tested, so it is removed from 
      the map. :)
    let $testParams := map:new((map:remove($parameters,'type'), txq:make-param-map($viewType)))
    let $reqEstimate := txq:test-request($method, $testParams, $successCode)
    let $estimateCode := $reqEstimate[1]
    let $runStmt := dpkg:get-run-stmt($viewType)
    let $responseBody :=  
      if ( $estimateCode = $successCode ) then
        (: Make XHTML using... :)
        switch ( $runStmt/@type/data(.) )
          
          (:  XSLT  :)
          case 'xslt' return
              let $teiXML := txq:get-param-xml('file')
              let $xslPath := dpkg:get-path-from-package($viewType, $runStmt/@pgm/data(.))
              (: Set XSLT parameters using HTTP parameters. :)
              let $xslParams := 
                <parameters>
                  {
                    for $key in map:keys($testParams)[. ne 'file']
                    return 
                      <param name="{$key}" value="{ txq:get-param($key) }"/>
                  }
                </parameters>
              (: Run the XSL transformation. :)
              let $xhtml := transform:transform($teiXML, doc($xslPath), $xslParams)
              return $xhtml
              
          (:case 'xproc' return '' 
          case 'xquery' return '':)
          
          (: If the @type on <run> is invalid (or if there is no configuration file), 
            output a HTTP 501 error. The server cannot complete the request because 
            the given transformation is not supported by this code. :)
          default return 
            let $code := 501
            let $type := $runStmt/@type/data(.)
            let $error := 
              if ( empty($type) ) then
                "View package configuration must include a method of transformation"
              else concat("Programs of type '",$type,"' are not implemented")
            return ($code, $error)
      
      else if ( $reqEstimate instance of item()* ) then
        tgen:set-error($reqEstimate[2])
      else tgen:get-error($estimateCode)
    return 
      if ( $responseBody[2] ) then 
        txq:build-response($responseBody[1], $contentType, $responseBody[2])
      else 
        txq:build-response($estimateCode, $contentType, $responseBody)
  else 
    let $message := 
      let $list := string-join($dpkg:valid-reader-types,', ')
      return concat("'type' must be one of the following: ", $list)
    return txq:build-response(400, $contentType, tgen:set-error($message))
