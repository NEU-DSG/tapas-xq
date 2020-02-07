xquery version "3.0";

import module namespace test="http://exist-db.org/xquery/xqsuite" 
  at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace txqt="http://tapasproject.org/tapas-xq/testsuite"
  at "libraries/testsuite.xql";
import module namespace inspect="http://exist-db.org/xquery/inspection";

declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

  declare option output:media-type "text/xml";
  declare option output:method "xml";
  declare option output:omit-xml-declaration "no";

(:~
 : `GET exist/apps/tapas-xq/tests` 
 : Run suite of unit tests for the TAPAS-xq API.
 : 
 : Returns results from executing the unit tests defined in 
 : libraries/testsuite.xql. These tests require database administrator
 : privileges.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: GET</li>
 : </ul>
 :
 : @return XML
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

let $exreq := doc('xmldb:exist:///db/apps/tapas-xq/resources/testdocs/exhttpSkeleton.xml')
let $baseUrl := 
  let $reqUrl := request:get-url()
  return
    if ( contains($reqUrl, '/tests') ) then
      replace($reqUrl, '/tests','')
    else
      let $noRest :=
        if ( contains($reqUrl, '/rest/') ) then
          replace($reqUrl, '/rest(/db)?', '')
        else $reqUrl
      return
        replace($noRest, '/modules/test-runner\.xq','')
let $setup := (
    if ( sm:user-exists($txqt:user?('name')) ) then ()
    else
      sm:create-account($txqt:user?('name'), $txqt:user?('password'), 'tapas', ())
    ,
    if ( sm:user-exists('faker') ) then ()
    else
      sm:create-account('faker', 'faker', 'guest', ())
    ,
    if ( contains(request:get-url(),'eXide') ) then ()
    else if ( $exreq/http:request[not(@href)] or $exreq/http:request/@href ne $baseUrl ) then
      update insert attribute href { $baseUrl } into $exreq/http:request
    else ()
  )
return (
    system:as-user($txqt:user?('name'), $txqt:user?('password'),
      test:suite(
        inspect:module-functions(xs:anyURI("libraries/testsuite.xql"))
      )
    )
    ,
    sm:remove-account($txqt:user?('name')),
    sm:remove-account('faker')
  )
