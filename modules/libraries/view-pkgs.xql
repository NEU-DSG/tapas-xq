xquery version "3.0";

module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";

import module namespace file="http://exist-db.org/xquery/file";
import module namespace http="http://expath.org/ns/http-client";
import module namespace httpc="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
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
declare variable $dpkg:valid-reader-types := 
  for $pkg in doc($dpkg:registry)/view_registry/package_ref
  return $pkg/@name/data(.);

(: Query GitHub's API for repository contents, using the default git branch. Then 
  download the files from the responses. Handle directories recursively. :)
declare function dpkg:call-github-contents-api($repoID as xs:string, $repoPath as xs:string, $localPath as xs:string) {
  dpkg:call-github-contents-api($repoID, $repoPath, $localPath, $dpkg:default-git-branch)
};

(: Query GitHub's API for repository contents, using a specified git branch. Then 
  download the files from the responses. Handle directories recursively. :)
declare function dpkg:call-github-contents-api($repoID as xs:string, $repoPath as xs:string, $localPath as xs:string, $branch as xs:string) {
  let $apiURL := concat($dpkg:github-base,'/',$repoID,'/contents/',$repoPath,'?ref=',$branch)
  let $pseudoJSON := dpkg:get-json-objects($apiURL)
  return dpkg:get-contents-from-github($pseudoJSON, $localPath)
};

(: Query GitHub's API for a repository's commits matching the timestamp given by 
  Rails. :)
declare function dpkg:get-commit-at($repoID as xs:string, $branch as xs:string, $dateTime as xs:string) {
  if ( $dateTime castable as xs:dateTime ) then
    let $apiURL := concat($dpkg:github-base,'/',$repoID,'/commits?sha=',$branch,'&amp;since=',$dateTime)
    let $pseudoJSON := dpkg:get-json-objects($apiURL)[1]
    return $pseudoJSON/pair[@name eq 'sha']/text()
  else () (: error :)
};

(: Get the configurations from all known view packages. :)
(: NOTE: It turns out this use of collection() is eXist-specific. It outputs all 
  files in descendant collections. Saxon will not do the same. :)
declare function dpkg:get-configuration($pkgID as xs:string) as item()* {
  let $parentDir := concat($dpkg:home-directory,'/',$pkgID)
  return collection($parentDir)[matches(base-uri(), 'CONFIG\.xml$')]/vpkg:view_package
};

(: Given JSON objects representing the contents of a directory within a GitHub repo, 
  determine how to handle each one by its type: directory, file, or git submodule. :)
declare function dpkg:get-contents-from-github($jsonObjs as node()*, $pathBase as xs:string) {
  for $obj in $jsonObjs
  let $type := $obj/pair[@name eq 'type']/text()
  return
    switch ($type)
      case 'dir'        return dpkg:get-dir-from-github($obj, $pathBase)
      case 'file'       return dpkg:get-file-from-github($obj, $pathBase)
      case 'submodule'  return dpkg:get-submodule-from-github($obj, $pathBase)
      default return () (: XD: symlinks :)
};

(: For a directory within a GitHub repo, create the directory locally if it doesn't 
  exist, and download its contents. :)
declare function dpkg:get-dir-from-github($jsonObj as node(), $pathBase as xs:string) {
  let $newPath := concat($pathBase,'/',$jsonObj/pair[@name eq 'name']/text())
  let $existDir := dpkg:make-directories($newPath)
  return
    if ( exists($existDir) ) then
      let $apiURL := $jsonObj/pair[@name eq 'url']/text()
      let $contents := dpkg:get-json-objects($apiURL)
      return dpkg:get-contents-from-github($contents,$newPath)
    else () (: error :)
};

(: For a file within a GitHub repo, download it. :)
declare function dpkg:get-file-from-github($jsonObj as node(), $pathBase as xs:string) {
  let $filename := $jsonObj/pair[@name eq 'name']/text()
  let $path := concat($pathBase, '/', $filename)
  let $downloadURL := $jsonObj/pair[@name eq 'download_url']/text()
  return
    if ( exists(dpkg:set-up-packages-home()) ) then
      if ( exists($downloadURL) ) then
        let $folder := $pathBase
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

(: Send out a query, and log any HTTP response that isn't "200 OK". :)
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

(:(\: Get the full path to a view pacakge's home directory. :\)
declare function dpkg:get-package-home($pkgID as xs:string) as xs:string {
  concat($dpkg:home-directory,'/',$pkgID)
};

(\: Expand a relative filepath using a view package's home directory. :\)
declare function dpkg:get-package-filepath($pkgID as xs:string, $relPath as xs:string) as xs:string {
  let $mungedPath := concat($pkgID,'/',replace($relPath, '^/', ''))
  return dpkg:make-absolute-path($mungedPath)
};:)

(: Get the <run> element from a package's configuration file. :)
declare function dpkg:get-run-stmt($pkgID as xs:string) as node()? {
  let $config := dpkg:get-configuration($pkgID)
  return $config/vpkg:run
};

(: Query the TAPAS Rails API for its stored view packages. :)
declare function dpkg:get-rails-packages() as node()* {
  let $railsAddr := xs:anyURI('http://rails_api.tapasdev.neu.edu/api/view_packages') (: XD: Figure out where to store this. :)
  return dpkg:get-json-objects($railsAddr)
};

(: For a submodule within a GitHub repo, create a directory if it doesn't exist 
  locally, then download its contents. :)
declare function dpkg:get-submodule-from-github($jsonObj as node(), $pathBase as xs:string) {
  let $moduleName := $jsonObj/pair[@name eq 'name']/text()
  let $path :=
    if ( matches($pathBase,concat('/',$moduleName,'$')) ) then
      $pathBase
    else concat($pathBase,'/',$moduleName)
  let $existDir := dpkg:make-directories($path)
  return
    if ( exists($existDir) ) then
      let $repoID := 
        let $gitURL := $jsonObj/pair[@name eq 'git_url']/text()
        return dpkg:get-submodule-identifier($gitURL)
      let $commit := $jsonObj/pair[@name eq 'sha']/text()
      return dpkg:call-github-contents-api($repoID,'',$path,$commit)
    else () (: error :)
};

(: Get the repository identifier and its GitHub owner from the "git_url" of a 
  submodule object. :)
declare function dpkg:get-submodule-identifier($gitURL as xs:string) {
  let $baseless := substring-after($gitURL,concat($dpkg:github-base,'/'))
  return substring-before($baseless,'/git/trees')
};

(: Return package reference entries for each view package newer in Rails than in the 
  XML database. Git commit timestamps are used for comparison. :)
declare function dpkg:get-updatable() as item()* {
  let $railsPkgs := dpkg:get-rails-packages()
  let $upCandidates :=
    if ( doc-available($dpkg:registry) and doc($dpkg:registry)[descendant::package_ref] ) then
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

(:declare %private function dpkg:make-absolute-path($relPath as xs:string) {
  if ( starts-with($relPath,'/') ) then
    concat($dpkg:home-directory, $relPath)
  else 
    concat($dpkg:home-directory,'/',$relPath)
};:)

(: Create all missing directories from an absolute path. :)
declare %private function dpkg:make-directories($absPath as xs:string) {
  let $tokenizedPath := tokenize($absPath,'/')
  return 
    for $index in 1 to count($tokenizedPath)
    let $newDir := $tokenizedPath[$index]
    let $targetDir := 
      let $tokens := subsequence($tokenizedPath,1,$index - 1)
      let $parentPath := if ( $index le 1 ) then '' else string-join($tokens,'/')
      return $parentPath
    return 
      if ( not(xdb:collection-available(concat($targetDir,$newDir))) ) then
        xdb:create-collection($targetDir,$newDir)
      else ()
};

(: Create a directory for a given view package, if it doesn't already exist. :)
declare function dpkg:set-up-package-collection($dirName as xs:string) {
  let $home := dpkg:set-up-packages-home()
  let $fullPath := concat($dpkg:home-directory,'/',$dirName)
  return
    if ( xdb:collection-available($fullPath) ) then $fullPath
    else xdb:create-collection($home,$dirName)
};

(: Create the view package home directory, if it doesn't already exist. :)
declare function dpkg:set-up-packages-home() {
  if ( xdb:collection-available($dpkg:home-directory) or file:mkdirs($dpkg:home-directory) ) then 
    $dpkg:home-directory
  else ()
};

(: Insert a given XML entry into the local view package registry. :)
declare function dpkg:insert-registry-entry($entry as node()) {
  let $name := $entry/@name/data(.)
  let $prevPkg := doc($dpkg:registry)/view_registry/package_ref[@name][@name/data(.) eq $name]
  return
    if ( $prevPkg ) then
      update replace $prevPkg with $entry
    else
      update insert $entry into doc($dpkg:registry)/view_registry
};

(: Given a package reference entry, update or create the local copy of that package. :)
declare function dpkg:update-package($update as node()) {
  let $pkgID := $update/@name/data(.)
  let $pkgBranch := $update/git/@branch/data(.)
  let $targetDateTime := $update/git/@timestamp/data(.)
  (: Test if the package is a submodule of the tapas-view-packages repo. :)
  let $isSubmodule :=
    let $testURL := concat($dpkg:github-base,'/',$dpkg:github-vpkg-repo,'/contents/',$pkgID,'?ref=',$dpkg:default-git-branch)
    let $pkgContent := dpkg:get-json-objects($testURL)
    return 
      if ( count($pkgContent) eq 1 and $pkgContent/pair[@name eq 'type'][text() eq 'submodule'] ) then 
        $pkgContent
      else false()
  (: Determine the correct package identifier to use for the view package. If the 
    package is a submodule, use its own package identifier, otherwise use 
    tapas-view-package. :)
  let $pkgRef := 
    if ( $isSubmodule ) then 
      let $gitURL := $isSubmodule/pair[@name eq 'git_url']/text()
      return dpkg:get-submodule-identifier($gitURL)
    else $dpkg:github-vpkg-repo
  let $branch := 
    if ( exists($pkgBranch) and $pkgBranch ne '' ) then $pkgBranch
    else $dpkg:default-git-branch
  let $newCommit := dpkg:get-commit-at($pkgRef,$branch,$targetDateTime)
  let $pkgDir := dpkg:set-up-package-collection($pkgID)
  (: Attempt to download the package from a GitHub repository. :)
  let $installUpdate :=
    if ( exists($newCommit) and $newCommit ne '' ) then
      if ( exists($pkgDir) ) then
        dpkg:call-github-contents-api($dpkg:github-vpkg-repo, $pkgID, $pkgDir, $newCommit)
      else <p>Couldn't create package collection</p>
    (: If there's no recognizable commit, download the latest contents from the 
      given branch. :)
    else dpkg:call-github-contents-api($dpkg:github-vpkg-repo, $pkgID, $pkgDir, $branch)
  return
    (: If the update returns strings of filepaths, and the view package is proven to 
      be populated, create or update the registry entry for the package. :)
    typeswitch ($installUpdate)
      case xs:string* return
        let $conf := dpkg:get-configuration($pkgID)
        return
          if ( count(xdb:get-child-resources($pkgDir)) ge 1 ) then
            let $configPath := 
              if ( $conf ) then $conf/base-uri()
              else () (: error :)
            let $entry := 
              <package_ref name="{$pkgID}">
                <conf>{$configPath}</conf>
                <git>
                  {
                    if ( exists($newCommit) and $newCommit ne '' ) then 
                      attribute commit { $newCommit }
                    else (),
                    attribute timestamp { $targetDateTime }
                  }
                </git>
              </package_ref>
            return dpkg:insert-registry-entry($entry)
          else $installUpdate (: error :)
      default return $installUpdate (: error :)
};

(: For each updatable package, find the git commit that Rails is using, then 
  download the package's files and create or update its registry entry. :)
declare function dpkg:update-packages() {
  if ( doc-available($dpkg:registry) ) then
    let $toUpdate := dpkg:get-updatable()
    let $gitCalls := 
      for $pkg in $toUpdate/descendant-or-self::package_ref
      let $pkgID := $pkg/@name/data(.)
      return dpkg:update-package($pkg)
    return $gitCalls
  else (: XD: download all packages and create registry :)
    <p>No registry</p>
};
