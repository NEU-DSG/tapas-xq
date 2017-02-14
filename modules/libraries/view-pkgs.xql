xquery version "3.0";

module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";

import module namespace file="http://exist-db.org/xquery/file";
import module namespace http="http://expath.org/ns/http-client";
import module namespace httpc="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

declare variable $dpkg:github-base := 'https://api.github.com/repos/NEU-DSG/tapas-view-packages';
declare variable $dpkg:home-directory := '/db/tapas-view-pkgs';

declare function dpkg:get-package-from-github($pkgID as xs:string, $branch as xs:string) as xs:string {
  let $apiURL := concat($dpkg:github-base,'/contents/',$pkgID,'?ref=',$branch)
  return $apiURL (: XD: Send requests to Github's API, then download the files from the responses. Handle directories recursively. :)
};

declare function dpkg:get-rails-packages() as node()* {
  let $railsAddr := xs:anyURI('') (: XD: Figure out where to store this. :)
  let $response :=
    let $request := httpc:get($railsAddr,false(),<headers/>)
    let $status := $request//httpc:header[@name eq 'Status']/@value/data(.)
    let $body := $request/httpc:body
    return
      if ( $status[contains(.,'200')] ) then
        if ( $body[@encoding eq 'Base64Encoded'] ) then
          util:base64-decode($body/text())
        else $body/text()
      else $status
  return
    if ( not(matches($response,'^\d\d\d ')) ) then
      let $pseudojson :=  xqjson:parse-json($response)
      return $pseudojson/item[@type eq 'object']
    else 
      <error>{ $response }</error>
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
    return dpkg:github-api-contents($pkg,'develop')
  return $gitCalls
};
