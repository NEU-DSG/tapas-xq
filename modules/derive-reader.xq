xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace transform="http://exist-db.org/xquery/transform";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {
                                  "assets-base" : 'xs:string',
                                  "file" : 'item()'
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "application/xml";

let $estimateCode := txq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $teiXML := txq:get-param-xml('file')
                        let $XSLparams := <parameters>
                                            <param name="filePrefix" value="{txq:get-param('assets-base')}"/>
                                          </parameters>
                        let $xhtml := transform:transform($teiXML, doc("../resources/teibp/teibp.xsl"), $XSLparams) (: xd: Handle different reader XSLs :)
                        return $xhtml
                      else tgen:get-error($estimateCode)
return txq:build-response($estimateCode, $contentType, $responseBody)
