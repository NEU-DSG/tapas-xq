xquery version "3.0";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace compress="http://exist-db.org/xquery/compression";

declare %private function local:create-zip-entry($filename, $filecontents) {
  <entry name="{$filename}.xml" type="xml" method="deflate">{ $filecontents }</entry>
};

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
    let $tfcZipEntry := local:create-zip-entry("tfcTEST", $tfc)
    let $modsZipEntry := local:create-zip-entry("modsTEST", $mods)
    return
    (
      response:set-status-code(201),
      (:response:set-header("Location", $loc),:)
      response:set-header("Content-Type", "application/zip"),
      response:stream-binary(
        compress:zip(
          (: The entries representing files to be zipped must be wrapped in a 
            sequence. :)
          ( $tfcZipEntry, $modsZipEntry ),
          (: Current directory hierarchy does not need to be respected. :)
          false()
        ),
        'application/zip',
        'TEST.zip'
      )
    )
  else ()
(: Return an error for any unsupported HTTP methods. :)
else (
  (
    response:set-status-code(405),
    <error>{request:get-method()} method not supported.</error>
  )
)