xquery version "3.0";

declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

(: if (request:get-remote-host() eq LocalDrupal) then...? :)
if (request:get-method() eq "POST") then
  if (request:get-header("Content-Type") eq "application/xml") then
    let $origTEI := request:get-data()
    let $tfc := transform:transform($origTEI, doc("../resources/tfc-generator.xsl"), ())
    (: need to store the tfc for eXist use (where?); 
      need permissions to store the tfc; 
      need a file name for the tfc :)
    (:let $loc := xmldb:store("/db/apps/tapas-xq","test.xml",$tfc):)
    (: need to grab any changed metadata fields from Drupal's request :)
    let $mods := transform:transform($origTEI, doc("../resources/TAPAS2MODSminimal.xsl"), ())
    return
    (
      response:set-status-code(201),
      (:response:set-header("Location", $loc),:)
      response:set-header("Content-Type", "multipart/form-data"),
      $tfc, $mods(:,
      <test>{ xmldb:collection-available("/db/apps/tapas-xq") }</test>:)
    )
  else ()
else ()