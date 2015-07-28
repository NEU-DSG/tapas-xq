xquery version "3.0";

module namespace txq="http://tapasproject.org/tapas-xq/exist";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "general-functions.xql";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace functx="http://www.functx.com";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";

(:~
 : This library contains functions for carrying out requests in eXist-db. It 
 : heavily relies upon the request and response modules, in conjunction with
 : ../../controller.xql and the API-handling XQueries.
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

(: Get a request parameter. :)
declare function txq:get-param($param-name as xs:string) {
  request:get-parameter($param-name, 400)
};

(: Get a request parameter whose value is expected to be XML. :)
declare function txq:get-param-xml($param-name as xs:string) {
  let $value := txq:get-param($param-name)
  return txq:get-file-content($value)
};

(: Get the body of the request (should only be XML). :)
declare function txq:get-body-xml() {
  request:get-data()
};

(: Clean data to get XML, replacing any instances of U+FEFF that might make 
 : eXist consider the XML "invalid." :)
declare function txq:get-file-content($file) {
  typeswitch($file)
    case node() return $file
    case xs:string return parse-xml(replace($file,'﻿',''))
    case xs:base64Binary return txq:get-file-content(util:binary-to-string($file))
    default return 400
};

(: Make sure that the incoming request matches the XQuery's expectations. :)
declare function txq:test-request($method-type as xs:string, $params as map, $success-code as xs:integer) as xs:integer {
  (: Test each parameter against a map with expected datatypes.:)
  let $requestParams := map:for-each-entry( $params, 
                                            function($param-name as xs:string, $param-type as xs:string) as xs:boolean {
                                              let $paramVal :=  (: If the expected type is XML, then try to turn
                                                                 : the param value into XML. :)
                                                                if ( $param-type eq 'node()' ) then
                                                                  txq:get-param-xml($param-name)
                                                                (: If the expected type is boolean, then try to turn
                                                                 : the param value into a boolean. :)
                                                                else if ( $param-type eq 'xs:boolean' ) then
                                                                  if ( txq:get-param($param-name) castable as xs:boolean ) then
                                                                    xs:boolean(txq:get-param($param-name))
                                                                  else 400
                                                                (: Otherwise, just get the param value. :)
                                                                else txq:get-param($param-name)
                                              (: Get the datatype of the param value. :)
                                              let $valType := functx:atomic-type($paramVal) 
                                              (: Check to make sure the datatype is correct :)
                                              return $valType eq $param-type or ($valType eq 'xs:untypedAtomic' and $param-type eq 'node()')
                                            })
  return
    (: Test HTTP method. :)
    if ( request:get-method() eq $method-type ) then
      if ( not(functx:is-value-in-sequence(false(), $requestParams)) ) then
        (: xd: If the request includes the appropriate key, log in that user. :)
          (: If the current user has access to the 'tapas-data' folder, then return a success code. :)
          if ( sm:has-access(xs:anyURI('/db/tapas-data'),'rwx') ) then
            $success-code
          (: Return an error if login fails. :)
          else 401
      (: Return an error if 1+ of the parameters does not match the expected type. :)
      else 400
    (: Return an error for any unsupported HTTP methods. :)
    else 405
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