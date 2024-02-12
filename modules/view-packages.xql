xquery version "3.1";

  module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs";
(:  LIBRARIES  :)
  (:import module namespace http="http://expath.org/ns/http-client";:)
  import module namespace tgen="http://tapasproject.org/tapas-xq/general"
    at "general-functions.xql";
(:  NAMESPACES  :)
  declare namespace admin="http://basex.org/modules/admin";
  declare namespace array="http://www.w3.org/2005/xpath-functions/array";
  declare namespace db="http://basex.org/modules/db";
  declare namespace err="http://www.w3.org/2005/xqt-errors";
  declare namespace file="http://expath.org/ns/file";
  declare namespace http="http://expath.org/ns/http-client";
  declare namespace json="http://basex.org/modules/json";
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace proc="http://basex.org/modules/proc";
  declare namespace tap="http://tapasproject.org/tapas-xq/api";
  declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";
  declare namespace xhtml="http://www.w3.org/1999/xhtml";

(:~
  This library contains functions for dynamically updating and maintaining the view 
  packages available in eXist.
  
  @author Ash Clark
  @version 1.6
  
  2024-02-07: Started reconstructing this library for use in BaseX:
      - Replaced $dpkg:home-directory with $dpkg:database.
      - Renamed dpkg:is-valid-view-package() to dpkg:is-known-view-package().
      - Folded $dpkg:valid-reader-types into dpkg:is-known-view-package().
      - Removed global variables dealing with GitHub:
          - $dpkg:github-api-base
          - $dpkg:github-raw-base
          - $dpkg:github-vpkg-repo
      - Removed functions which relied on the GitHub API:
          - dpkg:call-github-contents-api()
          - dpkg:find-submodule-dirs()
          - dpkg:get-default-git-branch()
          - dpkg:get-file-from-github()
          - dpkg:get-repo-archive()
          - dpkg:get-submodule-identifier()
          - dpkg:list-changed-files()
          - dpkg:get-commit-at() <!!!!
      - Added functions for working with the `git` filesystem command:
          - dpkg:get-current-commit-info()
          - dpkg:get-repository-filesystem-path()
          - dpkg:get-remote-repository-info()
      - Removed dpkg:is-environment-file-available() as an unnecessary abstraction.
      - Replaced dpkg:get-rails-api-host() with dpkg:set-rails-api-host-header().
      - Added dpkg:set-registry-entry().
  2023-08-16: Added dpkg:get-response-status(). Rearranged functions into four categories:
      - getting info on the view packages as they stand;
      - getting info on the companion Rails app;
      - preparing and executing updates; and
      - sending and parsing HTTP requests (e.g. GitHub repositories).
  2023-07-05: Fixed a path in dpkg:unpack-zip-archive() that prevented submodule contents from 
    being saved to the right place. Some functions (e.g. `dpkg:get-default-git-branch()` and
    `dpkg:unpack-zip-archive()`) are now public by default.
  2023-06-09: Revised dpkg:unpack-zip-archive() to extract files from the ZIP using EXPath's
    ZIP module instead of eXist's compression module. The latter naively tries to store HTML 
    as an XML document. The former explicitly states that "an HTML document is not necessarily 
    a well-formed XML document", but even so, the output of zip:html-entry() MUST be a 
    document node.
  2023-05-17: Started filling in missing `error()` messages. Changed $dpkg:default-rails-api
    from "http://railsapi.tapas.neu.edu/api/view_packages" to 
    "https://railsapi.tapasproject.org/api/view_packages".
  2023-05-08: Removed xqjson:parse-json() in favor of fn:json-to-xml(). Changed 
    dpkg:send-request() to use the EXPath HTTP client every time, but kept eXist's HTTP 
    client response format.
  2020-03-13: Finalized storage and unpacking of zipped view packages. If Rails isn't 
    available to check for updates, dpkg:get-updatable() returns nothing. Edited and 
    reformatted function descriptions.
  2020-02-21: Converted pseudo-JSON format from XQJSON to W3C, with Joe Wicentowski's 
    implementation of json-to-xml() serving as a fallback when the W3C-namespaced 
    version isn't available. Added missing module import.
  2019-06-26: Added dpkg:unpack-zip-archive() in order to abstract out and test some of 
    the code in dpkg:get-repo-archive(). If the zip file contains a single outermost 
    directory, that directory is not used during the decompression event.
  2017-12-06: Added dpkg:is-valid-view-package() as a convenience function for testing a 
    given string against the view packages listed in $dpkg:valid-reader-types.
  2017-07-28: Added environmental defaults at /db/environment.xml; moved some declared 
    variables into private functions; created dpkg:send-request() to handle Rails API 
    URLs with port numbers in them.
 :)
 
(:
    VARIABLES
 :)
  
  declare variable $dpkg:database := 'tapas-view-packages';
  
  declare variable $dpkg:default-rails-api := 
    'https://railsapi.tapasproject.org/api/view_packages';
  
  declare variable $dpkg:environment-defaults := 'environment.xml';
  
  declare variable $dpkg:registry-name := 'registry.xml';
  declare variable $dpkg:registry := concat($dpkg:database,'/',$dpkg:registry-name);


(:
    FUNCTIONS,
    Organized into these groups:
      0. General
      1. View packages
      2. Rails
      3. Git
      4. HTTP requests
    
    To get to a group quickly, search for "FUNCTIONS " + the group number you want 
    to find.
 :)
  
(:
 :  FUNCTIONS 0: General
 :)
  
  (:~
    Create an error's QName in an app-specific namespace.
    
    @return A qualified name in the TAPAS error namespace.
   :)
  declare %private function dpkg:error-qname($name as xs:string) as xs:QName {
    QName("http://tapasproject.org/tapas-xq/view-pkgs/err", $name)
  };


(:
 :  FUNCTIONS 1: View Packages
 :
 :  For obtaining and interpreting information about a named view package.
 :)
  
  (:~
    (Re)generate the registry of view packages known by TAPAS-xq.
   :)
  declare (:%updating:) function dpkg:compile-registry() {
    let $entries :=
      collection($dpkg:database)[matches(base-uri(), 'CONFIG\.xml$')]/vpkg:view_package
    let $registry :=
      <view_registry>
        
      </view_registry>
    return $registry
      (:db:put($dpkg:database, $registry, $dpkg:registry-name):)
  };
  
  (:~
    Get a configuration file for a given view package.
    
    Since the configuration filename can begin with anything as long as it ends in 
    'CONFIG.xml', this function takes the first-occurring file matching this criteria.
    
    @return The view package configuration file, <vpkg:view_package>.
   :)
  declare function dpkg:get-configuration($package-id as xs:string) as node()? {
    let $dbPath := dpkg:get-package-directory($package-id)
    return 
      (: It turns out this use of collection() is implementation-specific. It 
        outputs all files in descendant collections. It works in eXist and BaseX, 
        but Saxon will not do the same. :)
      collection($dbPath)[matches(base-uri(), 'CONFIG\.xml$')][1]/vpkg:view_package
  };
  
  
  (:~
    Get the absolute path to the directory for a given view package ID. No attempt is 
    made to check if the identifier matches an actual view package; this function just 
    builds the path for the collection where the package would be stored.
    
    @return The path to a view package collection.
   :)
  declare function dpkg:get-package-directory($package-id as xs:string) as xs:string {
    concat($dpkg:database,'/',$package-id)
  };
  
  
  (:~
    Turn a relative filepath from a view package directory into an absolute filepath.
    
    @return An absolute filepath to a view package collection.
   :)
  declare function dpkg:get-path-from-package($package-id as xs:string, 
     $relativePath as xs:string) as xs:string {
    if ( not(dpkg:is-known-view-package($package-id)) ) then
      error(dpkg:error-qname('InvalidViewPkg'), 
        concat("There is no view package named '",$package-id,"'"))
    else
      let $pkgHome := dpkg:get-package-directory($package-id)
      let $realRelativePath :=
        if ( starts-with($relativePath,'/') ) then
          $relativePath
        else concat('/',$relativePath)
      return concat($pkgHome,$realRelativePath)
  };
  
  
  (:~
    Get the registry entry for the view package matching a given identifier.
    
    @return The <package_ref> description of the view package.
   :)
  declare function dpkg:get-registry-entry($package-id as xs:string) as node()? {
    doc($dpkg:registry)//package_ref[@name eq $package-id]
  };
  
  
  (:~
    Get the <run> element from a package's configuration file.
    
    @return The <vpkg:run> element from the given view package's configuration.
   :)
  declare function dpkg:get-run-stmt($package-id as xs:string) as node()? {
    dpkg:get-configuration($package-id)/vpkg:run
  };
  
  
  (:~
    Determine if an identifier matches that of a valid view package.
    
    @return True if the string provided matches a registered view package.
   :)
  declare function dpkg:is-known-view-package($package-id as xs:string) as 
     xs:boolean {
    let $registeredPackages := 
      doc($dpkg:registry)/view_registry/package_ref/@name/data(.)
    return $package-id = $registeredPackages
  };
  
  (:~
    Generate a registry entry for the view package matching the given name. The 
    entry can be used to populate the registry of view packages known by the 
    TAPAS-xq app.
    
    @return An XML element representing the view package, or an empty sequence if 
      the view package couldn't be found
   :)
  declare function dpkg:set-registry-entry($package-id as xs:string) as node()? {
    let $conf := dpkg:get-configuration($package-id)
    let $pkgHistory := dpkg:get-current-commit-info($package-id)
    (: Subdirectories of a git repository share the same last commit, but subMODULES 
      don't. If the full view package repository's last commit is not the same as 
      this view package's, we know this view package is a submodule. :)
    let $isSubmodule := exists($conf) and $pkgHistory instance of map(*)
      and $pkgHistory?commit ne dpkg:get-current-commit-info()?commit
    return
      if ( empty($conf) ) then () else
        <package_ref name="{$package-id}">{
            if ( $isSubmodule ) then
              attribute submodule { true() }
            else ()
          }
          <conf>{ $conf/base-uri() }</conf>
          <git>{
            (: We want to capture more information about submodules. :)
            if ( not($isSubmodule) ) then () else 
              let $originInfo := dpkg:get-remote-repository-info($package-id)
              return (
                attribute repo { $originInfo?repo },
                attribute branch { $originInfo?branch },
                attribute commit { $pkgHistory?commit }
              ),
            (: Since it's always present, we could put the timestamp attribute right 
              on <git>. However, I think it reads best after the optional submodule 
              information. :)
            attribute timestamp { $pkgHistory?timestamp }
          }</git>
        </package_ref>
  };


(:
 :  FUNCTIONS 2: Rails
 :
 :  For syncing view packages with a TAPAS Rails instance.
 :)
  
  (:~
    Get the Rails API URL. If this was not set in the environment file, the 
    $dpkg:default-rails-api is used.
    
    @return The URL for a TAPAS Rails instance
   :)
  declare function dpkg:get-rails-api-url() as xs:string {
    if ( doc-available($dpkg:environment-defaults) and 
        doc($dpkg:environment-defaults)//railsBaseURI[normalize-space(text()) ne ''] ) then
      concat(doc($dpkg:environment-defaults)//railsBaseURI/text(), '/api/view_packages')
    else $dpkg:default-rails-api
  };
  
  
  (:~
    Query the TAPAS Rails API for its stored view packages.
    
    @return The view packages known by the Rails instance, or 1+ <tap:err>s
   :)
  declare function dpkg:get-rails-packages() as node()* {
    let $railsAddr := xs:anyURI(dpkg:get-rails-api-url())
    let $response := dpkg:get-json-objects($railsAddr)
    return 
      if ( $response[self::tap:err] ) then (
          tgen:set-error(500, "Could not connect to Rails."),
          $response[self::tap:err]
        )
      else $response
  };
  
  
  (:~
    Produce a "Host" request header, if necessary for communicating with the Rails API.
    
    @return An HTTP Client "header" element, if required by the environment configuration file
   :)
  declare %private function dpkg:set-rails-api-host-header() as node()? {
    if ( doc-available($dpkg:environment-defaults) ) then
      let $host := doc($dpkg:environment-defaults)//railsBaseURI/@host/data(.)
      return
        if ( empty($host) ) then () else
          <http:header name="Host" value="{$host}"/>
    else ()
  };
  
  
  
(:
 :  FUNCTIONS 3: Git
 :
 :  For updating and maintaining the view packages repository.
 :)
  
  
  (:~
    Get information on when the TAPAS View Packages repository was last updated.
    
    @return A map containing the last commit's hash and ISO 8601 timestamp
   :)
  declare %private function dpkg:get-current-commit-info() as map(xs:string, item())? {
    dpkg:get-current-commit-info('')
  };
  
  
  (:~
    Get information on when a view package was last updated.
    
    @return A map containing the last commit's hash and ISO 8601 timestamp
   :)
  declare %private function dpkg:get-current-commit-info($package-id as xs:string) 
     as map(xs:string, item())? {
    (: We can use the `git log -1` filesystem command to get information about the 
      current commit. To ease programmatic use, we define a custom format for 
      describing that commit:
        %H  — commit hash
        %n  — newline
        %aI — author date in ISO 8601 format (strict)
      See https://git-scm.com/docs/git-log#_pretty_formats for more options. :)
    let $logFormat := 
      let $picture := '%H%n%aI'
      return concat('--format=',$picture)
    (: We'll need BaseX run the `git` command in the right directory. :)
    let $repoPath := 
      concat(dpkg:get-repository-filesystem-path(),'/',$package-id)
    let $commandOpts := map { 'dir': $repoPath }
    let $errorMsg :=
      tgen:set-error(500, "Could not retrieve git information for directory "||$repoPath)
    return
      (: If the view package doesn't have a directory in the git repository, return 
        an error. Otherwise, return a map containing the parsed commit and dateTime. :)
      if ( not(file:exists($repoPath)) ) then $errorMsg else
        let $gitInfo :=
          try {
            proc:system('git', ('log', '-1', $logFormat), $commandOpts)
          } catch * { $errorMsg }
        return
          if ( not($gitInfo instance of xs:string) ) then $gitInfo else
            let $commandOut := $gitInfo => tokenize('\n')
            return map {
                'commit': $commandOut[1],
                'timestamp': xs:dateTime($commandOut[2])
              }
  };
  
  
  (:~
    Determine where the TAPAS view packages repository lives on the filesystem.
    
    @return The path to the "view-packages" directory, relative to the BaseX home 
      directory
   :)
  declare %private function dpkg:get-repository-filesystem-path() as xs:string {
    let $tapasXqPath :=
      if ( file:exists('tapas-xq') ) then 'tapas-xq'
      (: When run from the BaseX ZIP in standalone mode, TAPAS-xq will be stored in the "webapp" directory. :)
      else if ( file:exists('webapp/tapas-xq') ) then 'webapp/tapas-xq'
      else ()
    return
      if ( empty($tapasXqPath) ) then
        error(dpkg:error-qname('AppRepoMissing'), "Could not find the 'tapas-xq' folder!")
      else concat($tapasXqPath,'/view-packages')
  };
  
  
  (:~
    Retrieve information about the "origin" repository of a given view package. This 
    is most useful for submodules.
    
    @return A map containing the origin repository's URL and HEAD branch
   :)
  declare function dpkg:get-remote-repository-info($package-id as xs:string) {
    let $repoPath := 
      concat(dpkg:get-repository-filesystem-path(),'/',$package-id)
    let $commandOpts := map { 'dir': $repoPath }
    let $errorMsg :=
      tgen:set-error(500, "Could not retrieve remote information for submodule "||$repoPath)
    return
      if ( not(file:exists($repoPath)) ) then $errorMsg else
        let $gitOrigin :=
          try {
            proc:system('git', ('remote', 'show', 'origin'), $commandOpts)
          } catch * { $errorMsg }
        return
          if ( not($gitOrigin instance of xs:string) ) then $gitOrigin else
            let $outLines := tokenize($gitOrigin, '\n') ! normalize-space()
            let $repository :=
              $outLines[starts-with(., 'Fetch URL:')]
              => substring-after(': ')
            let $branch :=
              $outLines[starts-with(., 'HEAD branch:')]
              => substring-after(': ')
            return map {
                'repo': $repository,
                'branch': $branch
              }
  };
  
  
  
(:
 :  FUNCTIONS 4: HTTP Requests
 :
 :  For sending requests through the HTTP Client, and interpreting responses.
 :)
  
  (:~
    Send out a query, and log any HTTP response that isn't "200 OK".
    
    @return A sequence of <fn:map>s
   :)
  declare %private function dpkg:get-json-objects($url as xs:string) as node()* {
    let $address := xs:anyURI($url)
    let $response := dpkg:send-request($address)
    return
      (: Pass along errors generated in dpkg:send-request(). :)
      if ( not(dpkg:is-valid-response($response)) ) then
        $response
      else
        let $body := dpkg:get-response-body($response)
        (: By default, BaseX parses JSON into the "direct" XML format. Our goal is 
          to obtain either a JSON string, or the W3C's XML serialization. :)
        let $jsonStr := 
          if ( $body?('media-type') = ('application/json', 'text/json') ) then
            let $responseBody := $body?('content')
            return
              typeswitch ($responseBody)
                case xs:string return $responseBody
                (: Convert the "direct" XML serialization of JSON into a string. :)
                case document-node(element(json)) return
                  json:serialize($responseBody/*)
                (: If the response body is XML and appears to be the W3C's 
                  serialization, pass it on unchanged. :)
                case document-node() return
                  if ( $responseBody/*[self::fn:*] ) then $responseBody/*
                  else 
                    (: If the response body is some other kind of XML, we can't know 
                      how to interpret it. Return an error. :)
                    tgen:set-error(500, "Could not parse XML serialization as JSON")
                default return 
                  tgen:set-error(500, "Could not parse response as JSON")
          else ()
        (: Now, we have either a JSON string, W3C pseudo-JSON, or an error message. 
          The goal now is to turn JSON strings into W3C pseudo-JSON. :)
        let $pseudojson :=
          if ( exists($jsonStr) and $jsonStr instance of xs:string ) then
            try {
              json-to-xml($jsonStr)/*
            } catch * {
              tgen:set-error(500, "Could not convert JSON into XML")
            }
          else if ( exists($jsonStr) and $jsonStr instance of node() ) then
            $jsonStr
          else tgen:set-error(500, "Empty or non-JSON response")
        (: Return a sequence of <fn:map>s (or errors). :)
        return
          if ( exists($pseudojson) and $pseudojson[self::fn:*] ) then
            typeswitch ($pseudojson)
              case element(fn:map) return $pseudojson
              case element(fn:array) return $pseudojson/fn:map
              default return ()
          else $pseudojson
  };
  
  
  (:~
    From an EXPath HTTP Client response, create a map for each body, with its contents and media-type.
    
    @return One map for each response body. Each map contains "media-type" and "content".
   :)
  declare %private function dpkg:get-response-body($http-response as item()*) as map(xs:string, item()?)* {
    let $mediaTypes := 
      let $contentType := 
        $http-response[1]//http:header[@name eq 'content-type']/@value/data(.)
      return
        if ( matches($contentType, '^[-\w+]+/[-\w+]+;') ) then
          substring-before($contentType, ';')
        else $contentType
    let $bodies := tail($http-response)
    return
      for $index in 1 to count($bodies)
      let $mediaType := $mediaTypes[$index]
      let $body := $bodies[$index]
      let $bodyContent :=
        (: Skip binary decoding if the file is a ZIP. :)
        if ( contains($mediaType, "application/zip") ) then $body
        else
          typeswitch ($body)
            case xs:base64Binary return (:util:base64-decode($body):) $body
            default return $body
      return
        map { 'media-type': $mediaType, 'content': $bodyContent }
  };
  
  
  (:~
    Retrieve the HTTP status code from an HTTP response.
    
    @return The HTTP code as a string, if available. Otherwise, an empty sequence.
   :)
  declare %private function dpkg:get-response-status($http-response as item()*) as xs:string? {
    if ( exists($http-response) ) then
      $http-response[1]/@status/data(.)
    else ()
  };
  
  
  (:~
    Determine if an HTTP response is usable.
    
    @return True if the server responded and no error occurred.
   :)
  declare %private function dpkg:is-valid-response($response as item()*) as xs:boolean {
    try {
      count($response) ge 2 and dpkg:get-response-status($response) eq '200'
      (:and not(exists($response[self::Q{}p[@type]])):)
    } catch * { false() }
  };
  
  
  (:~
    Send a GET request, timing out if the server takes over 15 seconds to respond.
    
    @return The HTTP response, formatted as defined in the EXPath HTTP Client spec
   :)
  declare %private function dpkg:send-request($url as xs:anyURI) as item()* {
    let $request :=
      <http:request method="GET" href="{$url}" timeout="15">{
        (: If the request is to the Rails API and environment.xml has a DNS address 
          listed, add that address to the "Host" header. :)
        if ( $url eq dpkg:get-rails-api-url() ) then
          dpkg:set-rails-api-host-header()
        else () 
      }</http:request>
    let $response :=
      (: Recover from any errors, but log them. :)
      try { http:send-request($request, $url) }
      catch * {
        let $message :=
          "TAPAS-xq could not send request to "||$url||". Full error: "
          ||$err:code||" "||$err:value||"--"||$err:description
        return (
            admin:write-log($message, 'WARN'),
            tgen:set-error(500, $message)
          )
      }
    return
      if ( empty($response) or empty(dpkg:get-response-status($response)) ) then
        $response
      else if ( dpkg:get-response-status($response) ne '200' ) then
        let $message := 
          "Request to "||$url||" failed with response "
          ||dpkg:get-response-status($response)||": "
          ||dpkg:get-response-body($response)?content
        return tgen:set-error(500, $message)
      else $response
  };
