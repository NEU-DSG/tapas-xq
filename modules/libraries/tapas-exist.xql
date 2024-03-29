xquery version "3.0";

module namespace txq="http://tapasproject.org/tapas-xq/exist";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "view-pkgs.xql";
import module namespace functx="http://www.functx.com";
import module namespace httpc="http://exist-db.org/xquery/httpclient";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";
import module namespace md="http://exist-db.org/xquery/markdown";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace sm="http://exist-db.org/xquery/securitymanager";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "general-functions.xql";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace validate="http://exist-db.org/xquery/validation";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(:~
  This library contains functions for carrying out requests in eXist-db. It 
  heavily relies upon the request and response modules, in conjunction with
  ../../controller.xql and the API-handling XQueries.
  
  @author Ashley M. Clark
  @version 1.1
  
  2020-02-07: Copied is-tapas-user() from the view packages library. Reformatted 
    and rearranged code.
  2017-12-07: Added function to get Markdown-flavored text and turn it into
    HTML. Added variable $txq:home-dir for the path to the home directory of
    TAPAS-xq in eXist.
  2017-01-30: Added function to get parameter definitions from view package
    configuration files.
  2015-10-26: Expanded XML validation and classified errors from that process
    as HTTP 422s.
  2015-10-05: Rearranged function logic to accommodate complex error messages. 
:)


(: VARIABLES :)

declare variable $txq:home-dir :=
  let $noPrefix := 
    replace(system:get-module-load-path(), 
      '^(xmldb:exist://)?(embedded-eXist-server)?(.+)$', '$3')
  return
    if ( matches($noPrefix,'tapas-xq$') ) then $noPrefix
    else replace($noPrefix,'(tapas-xq)(.+)$','$1')
  ;

(: FUNCTIONS :)
  
  (: Create a map of expected request parameters using the configuration file. :)
  declare function txq:make-param-map($pkgID as xs:string) as map(*) {
    let $parameters := dpkg:get-configuration($pkgID)/vpkg:parameters
    return
      map:new(
        for $param in $parameters/vpkg:parameter
        return map:entry($param/@name/data(.), $param/@as/data(.))
      )
  };
  
  (: Get a request parameter. :)
  declare function txq:get-param($param-name as xs:string) {
    let $param := request:get-parameter($param-name, 400)
    return 
      if ( $param instance of xs:integer and $param = 400 ) then 
        (400, concat("Parameter '",$param-name,"' must be present")) 
      else $param
  };
  
  (: Get a request parameter whose value is expected to be XML. :)
  declare function txq:get-param-xml($param-name as xs:string) {
    let $value := txq:get-param($param-name)
    return 
      if ( $value[1] instance of xs:integer ) then
        $value
      else 
        (: If the parameter exists, run a validation check on the file. :)
        let $file := txq:get-file-content($value)
        let $isXML := 
          try { txq:validate($file) }
          catch * { (422, "Provided file must be well-formed XML") }
        return 
          if ( $isXML[1] instance of xs:integer ) then
            $isXML
          else $file
  };
  
  (: Get the body of the request (should only be XML). :)
  declare function txq:get-body-xml() {
    txq:get-file-content(request:get-data())
  };
  
  (: Clean data to get XML, replacing any instances of U+FEFF that might make 
   : eXist consider the XML "invalid." :)
  declare function txq:get-file-content($file) {
    typeswitch($file)
      case node() return $file
      case xs:string return try { txq:get-file-content(parse-xml(replace($file, '﻿', ''))) }
                            catch * { (422, "Provided file must be TEI-encoded XML") }
      case xs:base64Binary return txq:get-file-content(util:binary-to-string($file))
      default return (422, "Provided file must be TEI-encoded XML")
  };
  
  (: Check if the document is well-formed and valid TEI. :)
  declare function txq:validate($document as item()) {
    let $wellformednessReport := validate:jing-report($document, doc('../../resources/well-formed.rng'))
    return
      if ( $wellformednessReport//status/text() eq "valid" ) then
        let $isTEI := <results>
                        {
                          let $validation := 
                            transform:transform($document, doc('../../resources/isTEI.xsl'), <parameters/>)
                          return
                            for $message in tokenize($validation,'&#xA;')[. ne '']
                            return <p>{$message}</p>
                        }
                      </results>
        return
          if ( $isTEI/* ) then
            (422, for $error in $isTEI/p 
                  let $text := $error/text()
                  return concat(upper-case(substring($text,1,1)),substring($text,2)) )
          else $isTEI
      else (422, "Provided file must be well-formed XML")
  };
  
  declare function txq:test-param($param-name as xs:string, $param-type as xs:string) {
    let $paramVal :=  (: If the expected type is XML, then try to turn the param 
                       : value into XML. :)
                      if ( matches($param-type, 'node\(.*\)') ) then
                        txq:get-param-xml($param-name)
                      (: If the expected type is boolean, then try to turn the 
                       : param value into a boolean. :)
                      else if ( $param-type eq 'xs:boolean'
                                and txq:get-param($param-name) castable as xs:boolean ) then
                          txq:get-param($param-name) cast as xs:boolean
                      (: Otherwise, just get the param value. :)
                      else txq:get-param($param-name)
    (: Get the datatype of the param value. :)
    let $valType := functx:atomic-type($paramVal) 
    (: Check to make sure the datatype is correct :)
    return
      if ( count($paramVal) eq 2 and $paramVal[1] instance of xs:integer ) then
        $paramVal
      (: Return nothing if the atomic type is as expected, or if the parameter 
       : value is valid XML (invalid XML should be caught by the test above). :)
      else if ( $valType eq $param-type or matches($param-type, 'node\(.*\)') ) then
        ()
      else 
        (400, concat("Parameter '",$param-name,"' must be of type ",$param-type))
  };
  
  (: Make sure that the incoming request matches the XQuery's expectations. :)
  declare function txq:test-request($method-type as xs:string, $params as map(*), 
     $success-code as xs:integer) as item()* {
    (: Do not proceed unless the requester has been authenticated by eXist.
      NOTE: In eXist v2.2, authentication tests fail when called from a library 
      function.
     :)
    let $hasAccess := dpkg:is-tapas-user()
    return
    if ( not($hasAccess) ) then (401, "Unauthorized")
    else
      (: Test each parameter against a map with expected datatypes.:)
      let $badParams := 
        map:new(
            for $param-name in map:keys($params)
            let $param-type := map:get($params, $param-name)
            let $testResult := txq:test-param($param-name, $param-type)
            return 
              if ( $testResult instance of item()* ) then
                map:entry($param-name, $testResult)
              else ()
          )
      (: HTTP 400 errors occur when the API call is wrong in some way. :)
      let $all400s := 
        map:for-each-entry($badParams, 
            function ($key, $value) {
              if ( $value[1] castable as xs:integer and xs:integer($value[1]) = 400 ) then
                $key
              else ()
            }
          )
      let $num400s := count($all400s)
      (: HTTP 422 errors occur when the API call is correct, but part of the 
        request is not actionable. :)
      let $all422s := 
        map:for-each-entry($badParams, 
            function ($key, $value) {
              if ( $value[1] castable as xs:integer and xs:integer($value[1]) = 422 ) then
                $key
              else ()
            }
          )
      return
        (: Return an error for any unsupported HTTP methods. :)
        if ( request:get-method() ne $method-type ) then
          (405, concat("Expected HTTP method ",$method-type))
        else
          (: Return an error if 1+ of the parameters does not match the expected type. :)
          if ( $num400s > 0 ) then
            (400, 
            <div>
              <p>{$num400s} parameter{ 
                  if ( $num400s > 1 ) then "s don't" 
                  else " doesn't" 
                } match expectations:</p>
              <ul>
                {
                  for $error in $all400s
                  return <li>{ map:get($badParams,$error)[2] }</li>
                }
              </ul>
            </div>)
        else
          (: Return an error if XML files are not valid or well-formed. :)
          if ( count($all422s) > 0 ) then
            (422, 
            <div>
              <p>Errors produced during XML validation:</p>
              <ul>
                {
                  for $file in $all422s
                  let $errors := map:get($badParams,$file)
                  let $report := subsequence($errors,2,count($errors))
                  return 
                    for $error in $report
                    return <li>{ $error }</li>
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
            else 
              let $userId := 
                try {
                  sm:id()//sm:username
                } catch * { '' }
              return
                (401, concat("User ",$userId," does not have access to the data directory"))
        else $success-code
  };
  
  (: Build an HTTP response. :)
  declare function txq:build-response($code as xs:integer, $content-type as xs:string, $content as item()) {
    (: $content should always be XML or a string. If it is an integer, then this 
     : function treats that integer as an error code. :)
    let $isError := $content instance of xs:integer
    let $returnCode :=  if ( $isError ) then
                          $content
                        else $code
    return
        (
          response:set-status-code($returnCode),
          response:set-header("Content-Type", $content-type),
          if ( $isError ) then
            tgen:get-error($content)
          else $content
        )
  };
  
  (: Retrieve Markdown-flavored text and turn it into HTML. :)
  declare function txq:parse-markdown($filename as xs:string) as item()* {
    if ( util:binary-doc-available($filename) ) then
      let $markdown := util:binary-to-string(util:binary-doc($filename))
      let $html := 
        <html>
          <head>
            <title>TAPAS-xq API</title>
          </head>
          <body>{ md:parse($markdown) }</body>
        </html>
      return ( 200, $html )
    else ( 500, tgen:get-error(500) )
  };
  
  (: Make sure the current user is logged out (by logging in as guest). :)
  declare function txq:logout() {
    xmldb:login('/db','guest','guest'),
    session:invalidate()
  };
