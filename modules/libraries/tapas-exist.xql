xquery version "3.0";

module namespace txq="http://tapasproject.org/tapas-xq/exist";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "general-functions.xql";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace validate="http://exist-db.org/xquery/validation";
import module namespace functx="http://www.functx.com";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";

(:~
 : This library contains functions for carrying out requests in eXist-db. It 
 : heavily relies upon the request and response modules, in conjunction with
 : ../../controller.xql and the API-handling XQueries.
 : 
 : @author Ashley M. Clark
 : @version 1.0
 : 
 : 2015-10-05: Rearranged function logic to accommodate complex error messages. 
:)

(: Get a request parameter. :)
declare function txq:get-param($param-name as xs:string) {
  let $param := request:get-parameter($param-name, 400)
  return if ( $param instance of xs:integer and $param = 400 ) then (400, concat("Parameter '",$param-name,"' must be present")) else $param 
};

(: Get a request parameter whose value is expected to be XML. :)
declare function txq:get-param-xml($param-name as xs:string) {
  let $value := txq:get-param($param-name)
  return if ( $value[1] instance of xs:integer ) then $value else txq:get-file-content($value)
};

(: Get the body of the request (should only be XML). :)
declare function txq:get-body-xml() {
  txq:get-file-content(request:get-data())
};

(: Clean data to get XML, replacing any instances of U+FEFF that might make 
 : eXist consider the XML "invalid." :)
declare function txq:get-file-content($file) {
  typeswitch($file)
    case node() return txq:validate($file)
    case xs:string return parse-xml(replace($file,'﻿',''))
    case xs:base64Binary return txq:get-file-content(util:binary-to-string($file))
    default return (400,"Provided file must be TEI-encoded XML")
};

(: Check if the document is well-formed and valid TEI. :)
declare function txq:validate($document) {
  let $wellformednessReport := validate:jing-report($document, doc('../../resources/well-formed.rng'))
  return
    if ( $wellformednessReport//status/text() eq "valid" ) then
      let $isTEI := <results>
                      {
                        transform:transform($document,doc('../../resources/isTEI.xsl'),<parameters/>)
                      }
                    </results>
      return
        if ( $isTEI/* ) then
          (400, "Provided file must be valid TEI")
        else $isTEI
    else (400, "Provided file must be well-formed XML")
};

declare function txq:test-param($param-name as xs:string, $param-type as xs:string) {
  let $paramVal :=  (: If the expected type is XML, then try to turn the param 
                     : value into XML. :)
                    if ( $param-type eq 'node()' ) then
                      txq:get-param-xml($param-name)
                    (: If the expected type is boolean, then try to turn the 
                     : param value into a boolean. :)
                    else if ( $param-type eq 'xs:boolean' ) then
                      if ( txq:get-param($param-name) castable as xs:boolean ) then
                        txq:get-param($param-name) cast as xs:boolean
                      else 400
                    (: Otherwise, just get the param value. :)
                    else txq:get-param($param-name)
  (: Get the datatype of the param value. :)
  let $valType := functx:atomic-type($paramVal) 
  (: Check to make sure the datatype is correct :)
  return
    if ( $paramVal instance of item()* ) then $paramVal
    else if ( $valType eq $param-type ) then ()
    else (400, concat("Parameter '",$param-name,"' must be of type ",$param-type))
};

(: Make sure that the incoming request matches the XQuery's expectations. :)
declare function txq:test-request($method-type as xs:string, $params as map, $success-code as xs:integer) as item()* {
  (: Test each parameter against a map with expected datatypes.:)
  let $badParams := map:new(
                          for $param-name in map:keys($params)
                          let $param-type := map:get($params, $param-name)
                          let $testResult := txq:test-param($param-name,$param-type)
                          return 
                            if ( empty($testResult) ) then map:entry($param-name,$testResult)
                            else ()
                        )
  let $numErrors := count(map:keys($badParams))
  return
    (: Return an error for any unsupported HTTP methods. :)
    if ( request:get-method() ne $method-type ) then
      (405, concat("Expected HTTP method ",$method-type))
    else
      (: Return an error if 1+ of the parameters does not match the expected type. :)
      if ( $numErrors > 0 ) then
        (400, 
        <div>
          <p>{$numErrors} parameter{ if ( $numErrors > 1 ) then "s don't" else " doesn't" } match expectations:</p>
          <ul>
            {
              for $error in map:keys($badParams)
              return <li>{ map:get($badParams,$error)[2] }</li>
            }
          </ul>
        </div>)
    else 
      (: If the request will affect what is stored in eXist, check the user's permissions. :)
      if ($method-type eq 'DELETE' or $success-code = 201) then 
        (: If the current user has access to the 'tapas-data' folder, then return a success code. :)
        if ( sm:has-access(xs:anyURI('/db/tapas-data'),'rwx') ) then
          $success-code
        (: Return an error if login fails. :)
        else (401, "User does not have access to the data directory")
    else $success-code
};

(: Build an HTTP response. :)
declare function txq:build-response($code as xs:integer, $content-type as xs:string, $content as item()) {
  (: $content should always be XML or a string. If it is an integer, then this 
   : function treats that integer as an error code. :)
  let $isError := $content instance of xs:integer
  let $returnCode :=  if ($isError) then
                        $content
                      else $code
  return
      (
        response:set-status-code($returnCode),
        response:set-header("Content-Type", $content-type),
        if ($isError) then
          tgen:get-error($content)
        else $content
      )
};

(: Make sure the current user is logged out (by logging in as guest). :)
declare function txq:logout() {
  xmldb:login('/db','guest','guest'),
  session:invalidate()
};