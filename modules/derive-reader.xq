xquery version "3.0";

declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "libraries/view-pkgs.xql";
import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace map="http://www.w3.org/2005/xpath-functions/map";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace xprc="http://exist-db.org/xproc";

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
 : 2017-10-13: Added transformation via XProc.
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

(: The type of reader requested must be tested first, so that the map of parameters 
  can be augmented as needed. :)
let $viewType := txq:test-param('type','xs:string')
return
  if ( $viewType[1] instance of xs:string and $viewType = $dpkg:valid-reader-types ) then
    (: Create a new map of the expected parameters using the always-present ones 
      listed above, as well as any parameters defined in the package config file. 
      At this point, the package type has already been tested, so it is removed from 
      the map. :)
    let $testParams := map:new((map:remove($parameters,'type'), txq:make-param-map($viewType)))
    let $reqEstimate := txq:test-request($method, $testParams, $successCode)
    let $estimateCode := $reqEstimate[1]
    let $runStmt := dpkg:get-run-stmt($viewType)
    (: The HTTP parameter 'file' will always contain the TEI file from which to 
      create the reader output. All remaining parameters should be passed on as 
      parameters to the program running the derivation process. :)
    let $scriptParams := map:keys($testParams)[. ne 'file']
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
                    for $key in $scriptParams
                    return 
                      <param name="{$key}" value="{ txq:get-param($key) }"/>
                  }
                </parameters>
              (: Run the XSL transformation. :)
              let $xhtml := transform:transform($teiXML, doc($xslPath), $xslParams)
              return $xhtml
              
          (:  XProc  :)
          case 'xproc' return 
            let $teiXML := txq:get-param-xml('file')
            let $xprocPath := dpkg:get-path-from-package($viewType, $runStmt/@pgm/data(.))
            let $step := $runStmt/vpkg:step[1]
            let $stepNamespace := (:$step/@ns/data(.):) namespace-uri-from-QName($step/@qname/data(.))
            let $xprocWrapper :=
              (: The namespace for the XProc step listed in the config file must be 
                defined at the root of the $xprocWrapper. To do so programmatically, 
                all we should have to do is use a computed namespace constructor:
                    namespace { $prefix } { $nsURI }
                However, eXist doesn't do anything with namespace constructors until
                v3.5.0, so until we upgrade, we should assume that the imported 
                XProc step will use the prefix and namespace:
                    xmlns:l="http://www.wheatoncollege.edu/TAPAS/1.0"
                (2017-10-13, Ashley)
              :)
              <p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
                xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0"
                version="1.0">
                {
                  (: Define the input and output ports outlined in the configuration 
                    file. If there is more than one primary per *put type, only the
                    first is marked as such. :)
                  for $putType in ('in', 'out')
                  let $gi := concat('p:',$putType,'put')
                  return
                    for $input in $step/vpkg:port[@put eq $putType]
                    let $name := $input/text()
                    let $isPrimary := $input/@primary eq 'true' 
                                  and not($input/preceding-sibling::vpkg:port[@put eq $putType][@primary eq 'true'])
                    return
                      element { $gi } {
                        attribute port { $name },
                        if ( $isPrimary ) then
                          (
                            attribute primary { 'true' },
                            if ( $putType eq 'in' ) then 
                              <p:inline>
                                { $teiXML }
                              </p:inline>
                            else ()
                          )
                        else ()
                      },
                  (: Check configured options against script parameters, and pass on 
                    values from the HTTP request. :)
                  for $option in $scriptParams
                  return
                    <p:option name="{$option}" 
                              select="'{txq:get-param($option)}'"/>
                }
                <p:import href="xmldb://{$xprocPath}"/>
                { 
                  element { QName($stepNamespace, $step/@name/data(.)) } { }
                }
              </p:declare-step>
            (: Run the $xprocWrapper on the imported XProc step, with the required 
              inputs and options. :)
            return xprc:process( $xprocWrapper )
          
          (:case 'xquery' return '':)
          
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
