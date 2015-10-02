xquery version "3.0";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace inspect="http://exist-db.org/xquery/inspection";

(:~
 : @author Ashley M. Clark
 : @version 1.0
:)

test:suite(
  inspect:module-functions(xs:anyURI("libraries/testsuite-ingest.xql"))
)
