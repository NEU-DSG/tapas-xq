xquery version "3.0";

module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";

import module namespace file="http://exist-db.org/xquery/file";
import module namespace http="http://expath.org/ns/http-client";
import module namespace httpc="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";
import module namespace xdb="http://exist-db.org/xquery/xmldb";

(:~
 : This library contains functions for dynamically updating and maintaining the view 
 : packages available in eXist.
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

declare variable $dpkg:github-base := 'https://api.github.com/repos';
declare variable $dpkg:github-vpkg := concat($dpkg:github-base,'/NEU-DSG/tapas-view-packages');
declare variable $dpkg:home-directory := '/db/tapas-view-pkgs';

declare function dpkg:get-package-from-github($pkgID as xs:string, $branch as xs:string) as xs:string {
  let $apiURL := concat($dpkg:github-vpkg,'/contents/',$pkgID,'?ref=',$branch)
  return $apiURL (: XD: Send requests to Github's API, then download the files from the responses. Handle directories recursively. :)
};

declare function dpkg:get-contents-from-github($jsonObjs as node()*) {
  for $obj in $jsonObjs
  let $type := $obj/pair[@name eq 'type']/text()
  return
    switch ($type)
      case 'dir' return dpkg:get-dir-from-github($obj)
      case 'file' return dpkg:get-file-from-github($obj)
      case 'submodule' return $type (: XD :)
      default return $type
};

declare function dpkg:get-dir-from-github($jsonObj as node()) {
  let $existDir := 
    let $relPath := $jsonObj/pair[@name eq 'path']/text()
    let $fullPath := concat($dpkg:home-directory,'/',$path)
    return 
      if ( xdb:collection-available($fullPath) ) then
        $fullPath
      else
        let $dirname := $jsonObj/pair[@name eq 'name']/text() 
        let $target := replace($fullPath,concat('/?',$dirname,'$'),'')
        return xdb:create-collection($target,$dirname)
  return
    if ( $existDir ) then
      let $apiURL := $jsonObj/pair[@name eq 'url']/text()
      let $contents := dpkg:get-json-objects($apiURL)
      return dpkg:get-contents-from-github($contents)
    else () (: error :)
};

declare function dpkg:get-file-from-github($jsonObj as node()) {
  let $filename := $jsonObj/pair[@name eq 'name']/text()
  let $path := $jsonObj/pair[@name eq 'path']/text()
  let $downloadURL := $jsonObj/pair[@name eq 'download_url']/text()
  return
    if ( $downloadURL ) then
      let $folder := 
        let $parentDir := replace($path,concat('/?',$filename,'$'),'')
        return concat($dpkg:home-directory,'/',$parentDir)
      let $download := httpc:get($downloadURL,false(),<headers/>)
      return 
        if ( $download/@statusCode/data(.) eq '200' ) then
          let $body := $download//httpc:body
          let $mimetype := substring-before($body/@mimetype/data(.),';')
          let $contents := 
            if ( contains($mimetype,'xml') ) then
              document {
                $body/processing-instruction(),
                $body/node()
              }
            else $body/node()
          return xdb:store($folder,$filename,$contents,$mimetype)
        else () (: error :)
    else () (: error :)
};

declare function dpkg:get-rails-packages() as node()* {
  let $railsAddr := xs:anyURI('') (: XD: Figure out where to store this. :)
  return dpkg:get-json-objects($railsAddr)
};

declare function dpkg:get-json-objects($url as xs:string) as node()* {
  let $address := xs:anyURI($url)
  let $request := httpc:get($address,false(),<headers/>)
  let $status := $request/@statusCode/data(.)
  let $body := $request/httpc:body
  return
    if ( $status eq '200' ) then
      let $jsonStr :=
        if ( $body[@encoding eq 'Base64Encoded'] ) then
          util:base64-decode($body/text())
        else $body/text()
      let $pseudojson := xqjson:parse-json($jsonStr)
      return 
        ( $pseudojson[@type eq 'object'] 
        | $pseudojson/item[@type eq 'object'] )
    else <error>{ $status }</error> (: error :)
};

declare function dpkg:set-up-package-collection() {
  if ( file:exists($dpkg:home-directory) ) then
    ()
  else file:mkdirs($dpkg:home-directory)
};

declare function dpkg:update-packages() {
  let $railsPkgs := dpkg:get-rails-packages()
  let $toUpdate := $railsPkgs/pair[@name eq 'machine_name']/text() (: XD: Identify the packages that should be updated in eXist. :)
  let $gitCalls := 
    for $pkg in $toUpdate
    return dpkg:get-package-from-github($pkg,'develop')
  return $gitCalls
};
