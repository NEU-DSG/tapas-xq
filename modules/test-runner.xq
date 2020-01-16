xquery version "3.0";

import module namespace test="http://exist-db.org/xquery/xqsuite" 
  at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace txqt="http://tapasproject.org/tapas-xq/testsuite"
  at "libraries/testsuite-ingest.xql";
import module namespace inspect="http://exist-db.org/xquery/inspection";

declare namespace http="http://expath.org/ns/http-client";

(:~
  @author Ashley M. Clark
  @version 1.0
 :)

let $exreq := doc('xmldb:exist:///db/apps/tapas-xq/resources/testdocs/exhttpSkeleton.xml')
let $baseURL := replace(request:get-url(),'/modules/test-runner\.xq','')
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
    else if ( $exreq/http:request[not(@href)] or $exreq/http:request/@href ne $baseURL ) then
      update insert attribute href { $baseURL } into $exreq/http:request
    else ()
  )
return (
    system:as-user($txqt:user?('name'), $txqt:user?('password'),
      test:suite(
        inspect:module-functions(xs:anyURI("libraries/testsuite-ingest.xql"))
      )
    )
    ,
    sm:remove-account($txqt:user?('name')),
    sm:remove-account('faker')
  )
