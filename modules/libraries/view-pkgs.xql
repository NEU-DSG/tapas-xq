xquery version "3.0";

module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";

import module namespace file="http://exist-db.org/xquery/file";
import module namespace http="http://expath.org/ns/http-client";
import module namespace httpc="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "tapas-exist.xql";
import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

(:~
 : This library contains functions for dynamically updating and maintaining the view 
 : packages available in eXist.
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

declare variable $dpkg:github-base := 'https://api.github.com/repos';
declare variable $dpkg:github-vpkg-repo := 'NEU-DSG/tapas-view-packages';
declare variable $dpkg:default-git-branch := 'develop';
declare variable $dpkg:home-directory := '/db/tapas-view-pkgs';
declare variable $dpkg:registry := concat($dpkg:home-directory,'/registry.xml');

declare function dpkg:call-github-contents-api($repoID as xs:string, $path as xs:string) {
  dpkg:call-github-contents-api($repoID, $path, $dpkg:default-git-branch)
};

(: Send requests to Github's API, then download the files from the responses. Handle 
  directories recursively. :)
declare function dpkg:call-github-contents-api($repoID as xs:string, $path as xs:string, $branch as xs:string) {
  let $apiURL := concat($dpkg:github-base,'/',$repoID,'/contents/',$path,'?ref=',$branch)
  let $pseudoJSON := dpkg:get-json-objects($apiURL)
  return dpkg:get-contents-from-github($pseudoJSON)
};

declare function dpkg:get-contents-from-github($jsonObjs as node()*) {
  for $obj in $jsonObjs
  let $type := $obj/pair[@name eq 'type']/text()
  return
    switch ($type)
      case 'dir' return dpkg:get-dir-from-github($obj)
      case 'file' return dpkg:get-file-from-github($obj)
      (:case 'submodule' return ():)
      default return () (: XD: symlinks :)
};

declare function dpkg:get-dir-from-github($jsonObj as node()) {
  let $existDir := 
    let $relPath := $jsonObj/pair[@name eq 'path']/text()
    return dpkg:make-directories($relPath)
  return
    if ( exists($existDir) ) then
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
    if ( exists(dpkg:set-up-packages-home()) ) then
      if ( exists($downloadURL) ) then
        let $folder := 
          let $parentPath := 
            if ( contains($path,'/') ) then
              replace($path,concat('/',$filename,'$'),'')
            else ''
          let $absoluteParentPath := dpkg:make-absolute-path($parentPath)
          return
            if ( xdb:collection-available($absoluteParentPath) ) then
              $absoluteParentPath
            else 
              (
                dpkg:make-directories($parentPath),
                xdb:collection-available($absoluteParentPath)
              )
        let $download := httpc:get($downloadURL,false(),<headers/>)
        let $statusCode := $download/@statusCode/data(.)
        return 
          if ( exists($folder) and $statusCode eq '200' ) then
            let $body := $download//httpc:body
            let $type := $body/@type/data(.)
            let $encoding := $body/@encoding/data(.)
            let $contents := 
              if ( contains($type, 'xml') ) then
                document { $body/processing-instruction(), $body/node() }
              else if ( exists($encoding) and $encoding eq 'URLEncoded' ) then
                xdb:decode($body/text())
              else if ( exists($encoding) and $encoding eq 'Base64Encoded' ) then
                util:base64-decode($body/text())
              else $body/text()
            return 
              if ( exists($contents) and not(empty($contents)) ) then
                let $mimetype := concat('text/',$type)
                return xdb:store($folder,$filename,$contents,$mimetype)
              else () (: error :)
          else () (: error :)
      else () (: error :)
    else () (: error :)
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
      return 
        if ( $jsonStr ) then
          let $pseudojson := xqjson:parse-json($jsonStr)
          return 
            ( $pseudojson[@type eq 'object'] 
            | $pseudojson/item[@type eq 'object'] )
        else <p>ERROR: No response</p>
    else <p>ERROR: { $status }</p>
};

declare function dpkg:get-rails-packages() as node()* {
  let $railsAddr := xs:anyURI('http://rails_api.tapasdev.neu.edu/api/view_packages') (: XD: Figure out where to store this. :)
  return dpkg:get-json-objects($railsAddr)
};

declare function dpkg:get-updatable() as item()* {
  let $railsPkgs := dpkg:get-rails-packages()
  let $upCandidates :=
    if ( doc-available($dpkg:registry) ) then
      for $railsPkg in $railsPkgs
      let $dirName := $railsPkg/pair[@name eq 'dir_name']/text()
      let $registryPkg := doc($dpkg:registry)//package_ref[@name eq $dirName]
      return
        (: Flag for update the packages with no entry in the registry. :)
        if ( not(exists($registryPkg)) ) then $railsPkg
        else
          let $gitTimeR := $railsPkg/pair[@name eq 'git_timestamp']/text() cast as xs:dateTime
          let $gitTimeE := $registryPkg/git/@timestamp/data(.) cast as xs:dateTime
          return 
            (: Flag for update those packages where Rails' version has a newer git 
              timestamp than eXist's version. :)
            if ( $gitTimeE lt $gitTimeR ) then $railsPkg
            (: If the package is up-to-date, do nothing. :)
            else ()
    else $railsPkgs
  return
    for $pkg in $upCandidates
    return
      <package_ref name="{$pkg/pair[@name eq 'dir_name']/text()}">
        <git timestamp="{$pkg/pair[@name eq 'git_timestamp']/text()}">
          {
            let $branch := $pkg/pair[@name eq 'git_branch']/text()
            return 
              if ( exists($branch) and $branch ne '' ) then
                attribute branch { $branch }
              else ()
          }
        </git>
      </package_ref>
};

declare %private function dpkg:make-absolute-path($relPath as xs:string) {
  if ( starts-with($relPath,'/') ) then
    concat($dpkg:home-directory, $relPath)
  else 
    concat($dpkg:home-directory,'/',$relPath)
};

declare %private function dpkg:make-directories($relPath as xs:string) {
  let $fullDir := dpkg:make-absolute-path($relPath)
  return
    if ( exists(dpkg:set-up-packages-home()) ) then
      if ( not(xdb:collection-available($fullDir)) ) then 
        let $tokenizedPath := tokenize($relPath,'/')
        return 
          for $index in 1 to count($tokenizedPath)
          let $newDir := $tokenizedPath[$index]
          let $targetDir := 
            let $tokens := subsequence($tokenizedPath,1,$index - 1)
            let $newRelPath := if ( $index le 1 ) then '' else string-join($tokens,'/')
            let $path := dpkg:make-absolute-path($newRelPath)
            return $path
          return 
            if ( not(xdb:collection-available(concat($targetDir,$newDir))) ) then
              xdb:create-collection($targetDir,$newDir)
            else ()
      else () (: error :)
    else () (: error :)
};

declare function dpkg:set-up-package-collection($dirName as xs:string) {
  let $home := dpkg:set-up-packages-home()
  let $fullPath := concat($home,'/',$dirName)
  return
    if ( xdb:collection-available($fullPath) ) then ()
    else xdb:create-collection($home,$dirName)
};

declare function dpkg:set-up-packages-home() {
  if ( xdb:collection-available($dpkg:home-directory) or file:mkdirs($dpkg:home-directory) ) then 
    $dpkg:home-directory
  else ()
};

declare function dpkg:update-packages() {
  if ( doc-available($dpkg:registry) ) then
    let $toUpdate := dpkg:get-updatable()
    let $gitCalls := 
      for $pkg in $toUpdate (: XD: download the package and create registry entry :)
      let $pkgID := $pkg/@name/data(.)
      let $pkgBranch := $pkg/git/@branch/data(.)
      return 
        (:dpkg:get-package-from-github($pkg,'develop'):) 
        if ( exists(dpkg:set-up-package-collection($pkgID)) ) then
          if ( $pkgBranch ) then
            dpkg:call-github-contents-api($dpkg:github-vpkg-repo, $pkgID, $pkgBranch)
          else 
            dpkg:call-github-contents-api($dpkg:github-vpkg-repo, $pkgID)
        else <p>Couldn't create package collection</p>
    return $gitCalls
  else (: XD: download all packages and create registry :)
    <p>No registry</p>
};