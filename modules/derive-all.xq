xquery version "3.0";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace compress="http://exist-db.org/xquery/compression";

declare %private function local:create-zip-entry($filename, $filecontents) {
  <entry name="{$filename}.xml" type="xml">{ $filecontents }</entry>
};

declare %private function local:get-file-content($file) {
  typeswitch($file)
    (: Replace any instances of U+FEFF that might make eXist consider the XML 
      "invalid." :)
    case xs:string return replace($file,'﻿','')
    case xs:base64Binary return local:get-file-content(util:binary-to-string($file))
    default return <error>Unrecognized file type.</error>
};

(: Filter resources to be decompressed from .zip file. :)
declare %private function local:unzip-entry-filter($path as xs:string, $data-type as xs:string, $param as item()*) as xs:boolean {
	if ($data-type = 'resource') then
		true()
	else 
		false()
};

declare %private function local:data-collection-exists() as xs:boolean {
  xmldb:collection-available('/db/data')
};

declare %private function local:logout() {
  xmldb:login('/db','guest','guest'),
  session:invalidate()
};

(:declare variable $filesUploaded := count(request:get-parameter-names()[starts-with(.,'file')]);:)

if (request:get-method() eq "POST") then
  if (request:is-multipart-content()) then
    if (xmldb:login('/db','admin','dsgT@pas')) then
      if (local:data-collection-exists()) then
        let $reqURL := local:get-file-content(request:get-parameter('request',<error>ERROR</error>))
        let $reqXML := parse-xml($reqURL)
        let $docURL := local:get-file-content(request:get-parameter('file',<error>ERROR</error>))
        let $docXML := parse-xml($docURL)
        (: xd: test that the parameters exist as part of the request :)
        
        let $xslParams :=  
                        <parameters>
                          <param name="proj-id" value="{$reqXML/proj-id}"/>
                          <param name="doc-id" value="{$reqXML/doc-id}"/>
                          <param name="is-public" value="{$reqXML/is-public}"/>
                          <param name="collections" value="test"/>
                        </parameters>
        let $origTEI := doc(concat('/db/tapas-data/PROJ-ID/DOC-ID/',$reqXML/doc-id,'.xml')) (: xd :)
        let $tfc := transform:transform($origTEI, doc("../resources/tfc-generator.xsl"), $xslParams)
        (: need to store the tfc for eXist use (where?); 
          need permissions to store the tfc; 
          need a file name for the tfc :)
        (:let $loc := xmldb:store("/db/apps/tapas-xq","test.xml",$tfc):)
        (: need to grab any changed metadata fields from Drupal's request :)
        let $mods := transform:transform($origTEI, doc("../resources/TAPAS2MODSminimal.xsl"), ())
        (:let $html := transform:transform($origTEI, doc(""),()):)
        let $tfcZipEntry := local:create-zip-entry("tfcTEST", $tfc)
        let $modsZipEntry := local:create-zip-entry("modsTEST", $mods)
        return
          (
            response:set-status-code(201),
            (:response:set-header("Location", $loc),:)
            response:set-header("Content-Type", "application/zip"),
            (:response:stream-binary(
              compress:zip(
                (\: The entries representing files to be zipped must be wrapped in a 
                  sequence. :\)
                ( 
                  <entry name="{$n}" type="collection">
                    {$tfcZipEntry}
                    {$modsZipEntry}
                  </entry> 
                ),
                (\: Current directory hierarchy DOES need to be respected. :\)
                true()
              ),
              'application/zip',
              'TEST.zip'
            ):)
            <all>
              { $reqXML }
            </all>
          )
      else (
        (
          response:set-status-code(500),
          <error>No '/db/data' collection.</error>
        )
      )
    (: Return an error if login fails. :)
    else (
      (
        response:set-status-code(401),
        <error>Provide valid credentials</error>
      )
    )
  (: Return an error if the request content type is not 'multipart'. :)
  else (
    (
      response:set-status-code(415),
      response:set-header("Content-Type","application/xml"),
      <error>The media type "{request:get-header("Content-Type")}" is not supported.</error>
    )
  )
(: Return an error for any unsupported HTTP methods. :)
else (
  (
    response:set-status-code(405),
    response:set-header("Allow", "POST"),
    response:set-header("Content-Type","application/xml"),
    <error>{request:get-method()} method is not supported.</error>
  )
)