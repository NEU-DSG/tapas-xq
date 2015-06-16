xquery version "3.0";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace compress="http://exist-db.org/xquery/compression";

declare %private function local:create-zip-entry($filename, $filecontents) {
  <entry name="{$filename}.xml" type="xml" method="deflate">{ $filecontents }</entry>
};

declare %private function local:get-file-content($file) {
  typeswitch($file)
    case xs:string return replace($file,'﻿','')
    case xs:base64Binary return local:get-file-content(util:binary-to-string($file))
    default return <error>Unrecognized file type.</error>
};

(: if (request:get-remote-host() eq LocalDrupal) then...? :)
if (request:get-method() eq "POST") then
  if (request:is-multipart-content()) then
    (: Replace any instances of U+FEFF that might make eXist consider the XML 
      "invalid." :)
    let $fileData := local:get-file-content(request:get-parameter('file','ERROR'))
    let $origTEI := parse-xml($fileData)
    let $xslParams :=  
                    <parameters>
                      {
                        let $reqParams := ( 'user', 'collections', 'project', 'is-public' )
                        for $key in $reqParams
                          let $v := request:get-parameter($key,'ERROR')
                          return 
                            <param name="{$key}" value="{$v}"/>
                            (:if ($v='ERROR') then 
                              <error>{request:get-method()} method not supported.</error>
                            else <param name="{$key}" value="{$v}"/>:)
                      }
                    </parameters>
    let $tfc := transform:transform($origTEI, doc("../resources/tfc-generator.xsl"), $xslParams)
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
      (:for $i in request:get-parameter-names()
        return <param name="{$i}">{request:get-parameter($i,"")}</param>:)
    )
  (: Return an error for any unsupported HTTP methods. :)
  else (
    (
      response:set-status-code(415),
      response:set-header("Content-Type","application/xml"),
      <error>The media type "{request:get-header("Content-Type")}" is not supported.</error>
    )
  )
else (
  (
    response:set-status-code(405),
    response:set-header("Allow", "POST"),
    response:set-header("Content-Type","application/xml"),
    <error>{request:get-method()} method is not supported.</error>
  )
)