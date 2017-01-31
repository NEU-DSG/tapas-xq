xquery version "3.0";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace map="http://www.w3.org/2005/xpath-functions/map";
import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace transform="http://exist-db.org/xquery/transform";

(:~
 : `POST exist/apps/tapas-xq/derive-reader/:type` 
 : Derive XHTML (reading interface) production files from a TEI document.
 : 
 : Returns XHTML generated from the TEI document with status code 200. eXist 
 : does not store any files as a result of this request.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: multipart/form-data</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>type: A keyword representing the type of reader view to generate. 
 : Values can be "teibp" or "tapas-generic".</li>
 :    <li>file: A TEI-encoded XML document.</li>
 :  </ul>
 : </ul>
 :
 : @return XHTML
 : 
 : @author Ashley M. Clark
 : @version 1.0
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
let $readerType := txq:test-param('type','xs:string')
return
  if ( $readerType[1] instance of xs:string and $readerType = $txq:valid-reader-types ) then
    (: Create a new map of the expected parameters using the always-present ones 
      listed above, as well as any parameters defined in the reader's config file. 
      At this point, the reader type has already been tested, so it is removed from 
      the map. :)
    let $testParams := map:new((map:remove($parameters,'type'), txq:make-param-map($readerType)))
    let $reqEstimate := txq:test-request($method, $testParams, $successCode)
    let $estimateCode := $reqEstimate[1]
    let $responseBody :=  if ( $estimateCode = $successCode ) then
                            let $teiXML := txq:get-param-xml('file')
                            (: Set XSLT parameters using HTTP parameters. :)
                            let $XSLparams := <parameters>
                                                {
                                                  for $key in map:keys($testParams)[. ne 'file']
                                                  return 
                                                    <param name="{$key}" value="{ txq:get-param($key) }"/>
                                                }
                                              </parameters>
                            (: XD: Apply the appropriate transformation. :)
                            let $xhtml := 
                              if ( txq:get-param('type') eq 'teibp' ) then 
                                let $allHTML := transform:transform($teiXML, doc("../resources/teibp/teibp.xsl"), $XSLparams)
                                return
                                  <div xmlns="http://www.w3.org/1999/xhtml" class="teibp">
                                    { $allHTML/body/* }
                                  </div>
                              else if ( txq:get-param('type') eq 'tapas-generic' ) then
                                transform:transform($teiXML, doc("../resources/tapas-generic/tei2html.xslt"), $XSLparams)
                              (: If the $type keyword doesn't match the 
                               : expected values, return an error. :)
                              else (400, "':type' must have a value of 'teibp' or 'tapas-generic'")
                            return $xhtml
                          else if ( $reqEstimate instance of item()* ) then
                            tgen:set-error($reqEstimate[2])
                          else tgen:get-error($estimateCode)
    return 
      if ( $responseBody[2] ) then txq:build-response($responseBody[1], $contentType, $responseBody[2])
      else txq:build-response($estimateCode, $contentType, $responseBody)
  else 
    let $message := 
      let $list := string-join($txq:valid-reader-types,', ')
      return concat("'type' must be one of the following: ", $list)
    return txq:build-response(400, $contentType, tgen:set-error($message))
