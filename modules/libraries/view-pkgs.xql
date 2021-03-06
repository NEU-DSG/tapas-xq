xquery version "3.0";

  module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";

  import module namespace cprs="http://exist-db.org/xquery/compression";
  import module namespace file="http://exist-db.org/xquery/file";
  import module namespace http="http://expath.org/ns/http-client";
  import module namespace httpc="http://exist-db.org/xquery/httpclient";
  import module namespace sm="http://exist-db.org/xquery/securitymanager";
  import module namespace util="http://exist-db.org/xquery/util";
  import module namespace xdb="http://exist-db.org/xquery/xmldb";
  import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

(:~
 : This library contains functions for dynamically updating and maintaining the view 
 : packages available in eXist.
 : 
 : @author Ashley M. Clark
 : @version 1.1
 :
 : 2019-06-26: Added dpkg:unpack-zip-archive() in order to abstract out and test some of 
 :    the code in dpkg:get-repo-archive(). If the zip file contains a single outermost 
 :    directory, that directory is not used during the decompression event.
 : 2017-12-06: Added dpkg:is-valid-view-package() as a convenience function for testing a 
 :    given string against the view packages listed in $dpkg:valid-reader-types.
 : 2017-07-28: Added environmental defaults at /db/environment.xml; moved some declared 
 :    variables into private functions; created dpkg:send-request() to handle Rails API 
 :    URLs with port numbers in them.
:)

(:  VARIABLES  :)

  declare variable $dpkg:default-rails-api := 'http://railsapi.tapas.neu.edu/api/view_packages';
  declare variable $dpkg:environment-defaults := '/db/environment.xml';
  declare variable $dpkg:github-api-base := 'https://api.github.com/repos';
  declare variable $dpkg:github-raw-base := 'https://raw.githubusercontent.com';
  declare variable $dpkg:github-vpkg-repo := 'NEU-DSG/tapas-view-packages';
  declare variable $dpkg:home-directory := '/db/tapas-view-pkgs';
  declare variable $dpkg:registry-name := 'registry.xml';
  declare variable $dpkg:registry := concat($dpkg:home-directory,'/',$dpkg:registry-name);
  
  declare variable $dpkg:valid-reader-types := 
    for $pkg in doc($dpkg:registry)/view_registry/package_ref
    return $pkg/@name/data(.);


(:  FUNCTIONS  :)

  (: Get a configuration file for a given view package. :)
  (: NOTE: It turns out this use of collection() is eXist-specific. It outputs all 
    files in descendant collections. Saxon will not do the same. :)
  declare function dpkg:get-configuration($pkgID as xs:string) as item()* {
    let $parentDir := concat($dpkg:home-directory,'/',$pkgID)
    (: Since the configuration filename can begin with anything as long as it ends in 
      'CONFIG.xml', take the first-occurring file matching the config file criteria. :)
    return collection($parentDir)[matches(base-uri(), 'CONFIG\.xml$')][1]/vpkg:view_package
  };
  
  (: Turn a relative filepath from a view package directory into an absolute filepath. :)
  declare function dpkg:get-path-from-package($pkgID as xs:string, $relativePath as xs:string) {
    if ( dpkg:is-valid-view-package($pkgID) ) then
      let $pkgHome := dpkg:get-package-directory($pkgID)
      let $realRelativePath :=
        if ( starts-with($relativePath,'/') ) then
          $relativePath
        else concat('/',$relativePath)
      return concat($pkgHome,$realRelativePath)
    else () (: error :)
  };
  
  (: Query the TAPAS Rails API for its stored view packages. :)
  declare function dpkg:get-rails-packages() as node()* {
    let $railsAddr := xs:anyURI(dpkg:get-rails-api-url())
    return dpkg:get-json-objects($railsAddr)
  };
  
  (: Get the registry entry for the view package matching a given identifier. :)
  declare function dpkg:get-registry-entry($pkgID as xs:string) as node()? {
    doc($dpkg:registry)//package_ref[@name eq $pkgID]
  };
  
  (: Get the <run> element from a package's configuration file. :)
  declare function dpkg:get-run-stmt($pkgID as xs:string) as node()? {
    let $config := dpkg:get-configuration($pkgID)
    return $config/vpkg:run
  };
  
  (: Return package reference entries for each view package newer in Rails than in the 
    XML database. Git commit timestamps are used for comparison. :)
  declare function dpkg:get-updatable() as item()* {
    let $railsPkgs := dpkg:get-rails-packages()
    let $registryExists := doc-available($dpkg:registry) and doc($dpkg:registry)[descendant::package_ref]
    let $upCandidates :=
      for $railsPkg in $railsPkgs
      let $dirName := $railsPkg/pair[@name eq 'dir_name']/text()
      let $branch := $railsPkg/pair[@name eq 'git_branch']/text()
      let $isSubmodule := exists($branch) and $branch ne ''
      let $registryPkg := 
        if ( exists($dirName) ) then 
          dpkg:get-registry-entry($dirName) 
        else ()
      let $useBranch := 
        if ( $isSubmodule ) then $branch 
        else dpkg:get-default-git-branch()
      let $useRepo := 
        if ( not($isSubmodule) ) then
          $dpkg:github-vpkg-repo
        else if ( exists($registryPkg) ) then
          $registryPkg/git/@repo/data(.)
        else
          let $subRepo := dpkg:get-submodule-identifier($dpkg:github-vpkg-repo, $dirName, $useBranch)
          return 
            if ( contains($subRepo, ' ') ) then 
              ' ' (: error :)
            else $subRepo
      let $gitTimeR := $railsPkg/pair[@name eq 'git_timestamp']/text()
      let $makeEntry := function() {
          <package_ref name="{$dirName}">
            {
              if ( $isSubmodule ) then
                attribute submodule { true() }
              else ()
            }
            <git>
              {
                if ( $isSubmodule ) then
                  (
                    attribute repo { $useRepo },
                    attribute branch { $branch },
                    attribute commit { dpkg:get-commit-at($useRepo, $useBranch, $gitTimeR) }
                  )
                else ()
              }
              { attribute timestamp { $gitTimeR } }
            </git>
          </package_ref>
        }
      return
        (: Flag for update the packages with no entry in the registry. :)
        if ( not($registryExists) or not(exists($registryPkg)) ) then
          $makeEntry()
        else 
          (: Flag for update those packages where Rails' version has a newer git 
            timestamp than eXist's version. :)
          let $gitTimeE := $registryPkg/git/@timestamp/data(.) cast as xs:dateTime
          return 
            if ( $gitTimeE lt $gitTimeR cast as xs:dateTime ) then
              $makeEntry()
            (: If the package is up-to-date, do nothing. :)
            else ()
    return $upCandidates
  };
  
  (: Determine if the current eXist user can write to the $dpkg:home-directory. :)
    (: 2017-04-06: Half of the test is commented out for now! eXist v2.2 has a bug 
      which causes sm:id() to error out when one XQuery calls a function in a library; 
      see https://github.com/eXist-db/exist/issues/388. It should be fixed in eXist 
      v3.0 and higher; uncomment the dpkg:is-tapas-user() call when TAPAS upgrades 
      eXist. :)
  declare function dpkg:has-write-access() as xs:boolean {
    dpkg:is-tapas-user() and  dpkg:can-write()
  };
  
  (: Get the contents of $dpkg:github-vpkg-repo at the default git branch by 
    retrieving its ZIP archive from GitHub. Set up the view package registry. :)
  declare function dpkg:initialize-packages() {
    (: Only proceed if the current user is the TAPAS user. This ensures that the 
      contents of $dpkg:home-directory will be owned by that user. :)
    if ( dpkg:has-write-access() ) then
      (: Create <git> to hold data on $dpkg:github-vpkg-repo. :)
      let $vpkgGitInfo :=
        let $defaultBranch := dpkg:get-default-git-branch()
        let $urlParts := ( $dpkg:github-api-base, $dpkg:github-vpkg-repo, 
                            'branches', $defaultBranch )
        let $branchURL := string-join($urlParts,'/')
        let $responseObj := dpkg:get-json-objects($branchURL)/pair[@name eq 'commit']
        return
          <git repo="{$dpkg:github-vpkg-repo}" branch="{$defaultBranch}"
            commit="{$responseObj/pair[@name eq 'sha']/text()}"
            timestamp="{$responseObj/pair[@name eq 'commit']/pair[@name eq 'author']/pair[@name eq 'date']/text()}"/>
      (: Get the current commit on the default branch. :)
      let $vpkgCommit := $vpkgGitInfo/@commit/data(.)
      (: Get a ZIP archive of $dpkg:github-vpkg-repo, and unpack it into 
        $dpkg:home-directory. This process also obtains and unpacks any git submodules. :)
      let $mainRepo := dpkg:get-repo-archive($dpkg:github-vpkg-repo, $dpkg:home-directory, $vpkgCommit)
      (: Create the view package registry. :)
      let $registry := 
        <view_registry>
          { dpkg:define-rails-api-attribute() }
          { $vpkgGitInfo }
          {
            for $pkg in ( $mainRepo, dpkg:get-updatable() )
            let $name := $pkg/@name/data(.)
            order by $name
            return 
              <package_ref>
                { $pkg/@* }
                <conf>{ dpkg:get-configuration($name)/base-uri() }</conf>
                {
                  if ( $pkg[@submodule][@submodule eq 'true'] ) then
                    $pkg/git
                  else 
                    <git>
                      { $vpkgGitInfo/@commit, $vpkgGitInfo/@timestamp }
                    </git>
                }
              </package_ref>
          }
        </view_registry>
      return xdb:store($dpkg:home-directory, $dpkg:registry-name, $registry)
    else
      () (: error :)
  };
  
  (: Determine if an identifier matches that of a valid view package. :)
  declare function dpkg:is-valid-view-package($name as xs:string) as xs:boolean {
    $name = $dpkg:valid-reader-types
  };
  
  (: For each updatable package, find the git commit that Rails is using, then 
    download the package's files and create or update its registry entry. :)
  declare function dpkg:update-packages() {
    if ( doc-available($dpkg:registry) and doc($dpkg:registry)[descendant::package_ref] ) then
      (: Only proceed if the current user is the TAPAS user. This ensures that the 
        contents of $dpkg:home-directory will be owned by that user. :)
      if ( dpkg:has-write-access() ) then
        let $toUpdate := dpkg:get-updatable()
        return
          if ( count($toUpdate) gt 0 ) then
          let $submodules := 
            for $pkg in $toUpdate/descendant-or-self::package_ref[@submodule/data(.) eq 'true']
            let $pkgID := $pkg/@name/data(.)
            return dpkg:update-submodule($pkg)
          let $repoPkgs := $toUpdate/descendant-or-self::package_ref[not(@submodule) or @submodule/data(.) eq 'false']
          let $vpkgRepo :=
            (: All view packages entirely housed within $dpkg:github-vpkg-repo should have 
              the same Rails timestamp (and thus, the same commit SHA). If they don't, 
              return an error. :)
            let $timestamp := distinct-values($repoPkgs/git/@timestamp)
            return
              if ( count($timestamp) eq 0 ) then
                doc($dpkg:registry)/view_registry/git
              else if ( count($timestamp) eq 1 ) then
                dpkg:update-package-repo($timestamp)
              else () (: error :)
          (: Copy the registry entries for unmodified packages, and expand entries for 
            packages updated as part of the $dpkg:github-vpkg-repo. :)
          let $otherPkgs := 
            (
              doc($dpkg:registry)//package_ref[not(@name = $toUpdate/@name/data(.))],
              for $pkg in $repoPkgs
              let $conf := dpkg:get-configuration($pkg/@name/data(.))
              return
                <package_ref>
                  { $pkg/@* }
                  <conf>
                    {
                      if ( $conf ) then $conf/base-uri()
                      else () (: error :)
                    }
                  </conf>
                  <git>
                    { $pkg/git/@* }
                    { $vpkgRepo/@commit }
                  </git>
                </package_ref>
            )
          (: Recreate the registry of view packages. :)
          let $newRegistry := 
            <view_registry>
              { dpkg:define-rails-api-attribute() }
              { $vpkgRepo }
              { 
                for $pkg in ( $submodules, $otherPkgs )
                order by $pkg/@name/data(.)
                return $pkg
              }
            </view_registry>
          (: Update the registry document by storing it again. :)
          return 
            xdb:store($dpkg:home-directory, $dpkg:registry-name, $newRegistry)
        (: If there's nothing to update, don't do anything. :)
        else ()
      else () (: error :)
    else 
      (: If there's no registry or actionable package entries, download all packages 
        and create the registry for each package. :)
      dpkg:initialize-packages()
  };
  
  
(:  SUPPORT FUNCTIONS  :)
  
  (: Query GitHub's API for repository contents, using a specified git branch. :)
  declare
    %private
  function dpkg:call-github-contents-api($repoID as xs:string, $repoPath as xs:string, $branch as xs:string) {
    let $apiURL := concat($dpkg:github-api-base,'/',$repoID,'/contents/',$repoPath,'?ref=',$branch)
    return dpkg:get-json-objects($apiURL)
  };
  
  (: Test if the current user can write to $dpkg:home-directory. :)
  declare 
    %private 
  function dpkg:can-write() {
    sm:has-access(xs:anyURI($dpkg:home-directory),'rwx')
  };
  
  (: Return the paths for any git submodules (as indicated by empty directories, which 
    git is not able to track). This should only be run after unpacking a GitHub 
    repository from a ZIP file, before that file is deleted. :)
  declare
    %private
  function dpkg:find-submodule-dirs($zipPath as xs:string) as xs:string* {
    let $uri := xs:anyURI($zipPath)
    return
      if ( util:binary-doc-available($uri) ) then
        let $zipEntries := zip:entries($uri)
        let $zipDirs := $zipEntries/zip:dir/@name/data(.)
        (: To be a submodule directory, a directory must not contain any files, and 
          it must not contain any directories. :)
        return
          for $dir in $zipDirs
          let $filename := tokenize($zipPath,'/')[last()]
          let $zipBase := concat(substring-before($filename,'.zip'),'/')
          let $numPathMatches := count($zipEntries/*[contains(@name/data(.),$dir)])
          return
            (: If the directory is empty, there will be only one archive entry 
              matching the directory path. :)
            if ( $numPathMatches eq 1 ) then
              (: Return the absolute path to the directory in the database. :)
              concat(substring-before($zipPath,$filename), substring-after($dir,$zipBase))
            else ()
      else () (: error :)
  };
  
  (: Query GitHub's API for a repository's commits matching the timestamp given by 
    Rails. :)
  declare 
    %private 
  function dpkg:get-commit-at($repoID as xs:string, $branch as xs:string, $dateTime as xs:string) {
    if ( $dateTime castable as xs:dateTime ) then
      let $apiURL := concat($dpkg:github-api-base,'/',$repoID,'/commits?sha=',$branch,'&amp;since=',$dateTime)
      let $pseudoJSON := dpkg:get-json-objects($apiURL)[1]
      return $pseudoJSON/pair[@name eq 'sha']/text()
    else () (: error :)
  };
  
  (: Get the name of the git branch to use by default. :)
  declare
    %private
  function dpkg:get-default-git-branch() as xs:string {
    if ( dpkg:is-environment-file-available() ) then 
      doc($dpkg:environment-defaults)//defaultGitBranch/@name/data(.) 
    else 'master'
  };
  
  (: Download a file using data from GitHub's 'Compare Commits' API. :)
  declare
    %private
  function dpkg:get-file-from-github($jsonObj as node(), $pathBase as xs:string) {
    let $relPath := $jsonObj/pair[@name eq 'filename']/text()
    let $filename := tokenize($relPath,'/')[last()]
    let $folder := concat($pathBase, '/', substring-before($relPath,concat('/',$filename)))
    let $downloadURL := $jsonObj/pair[@name eq 'raw_url']/text()
    return
      if ( exists(dpkg:make-directories($folder)) ) then
        if ( exists($downloadURL) ) then
          let $download := dpkg:send-request(xs:anyURI($downloadURL))
          let $statusCode := $download/@statusCode/data(.)
          return 
            if ( exists($folder) and $statusCode eq '200' ) then
              let $body := $download/httpc:body
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
  declare 
    %private
  function dpkg:get-json-objects($url as xs:string) as node()* {
    let $address := xs:anyURI($url)
    let $request := dpkg:send-request($address)
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
          else <p>ERROR: No response</p> (: error :)
      else <p>ERROR: { $status }</p> (: error :)
  };
  
  (: Get the absolute path to the directory for a given view package ID. No attempt is 
    made to check if the identifier matches an actual view package; this function just 
    builds the path for the collection where the package would be stored. :)
  declare
    %private 
  function dpkg:get-package-directory($pkgID as xs:string) {
    concat($dpkg:home-directory,'/',$pkgID)
  };
  
  (: Get the host of the Rails API for use in a request header. :)
  declare
    %private
  function dpkg:get-rails-api-host() as xs:string {
    if ( dpkg:is-environment-file-available() and doc($dpkg:environment-defaults)//railsBaseURI[@host] ) then
      doc($dpkg:environment-defaults)//railsBaseURI/@host/data(.) 
    else ''
  };
  
  (: Get the Rails API URL. :)
  declare
    %private
  function dpkg:get-rails-api-url() as xs:string {
    if ( dpkg:is-environment-file-available() and doc($dpkg:environment-defaults)//railsBaseURI[normalize-space(text()) ne ''] ) then
      concat(doc($dpkg:environment-defaults)//railsBaseURI/text(), '/api/view_packages') 
    else $dpkg:default-rails-api
  };
  
  (: Get and unpack an archive of the contents of a GitHub repository. :)
  declare 
    %private
  function dpkg:get-repo-archive($repoID as xs:string, $dbPath as xs:string, $branch as xs:string) {
    let $zipURL := 
      let $urlParts := ($dpkg:github-api-base, $repoID, 'zipball', $branch)
      return xs:anyURI(string-join($urlParts,'/'))
    let $response := dpkg:send-request($zipURL)
    let $zipFilename := $response//httpc:header[@name eq 'Content-Disposition']/@value/substring-after(data(.),'filename=')
    let $archivePath := 
      let $binary := xs:base64Binary($response//httpc:body/text())
      return xdb:store($dpkg:home-directory, $zipFilename, $binary, 'application/zip')
    let $unzipped := dpkg:unpack-zip-archive($archivePath, $dbPath)
    (: Identify any submodules; download and unpack their archives. :)
    let $submoduleDirs := dpkg:find-submodule-dirs($archivePath)
    let $getSubmodules := 
      for $localPath in $submoduleDirs
      let $repoPath := substring-after($localPath, concat($dbPath,'/'))
      let $subRepo := dpkg:get-submodule-identifier($repoID, $repoPath, $branch)
      let $updateEntry := dpkg:get-updatable()[@submodule eq 'true'][contains(@name, $subRepo)]
      let $commit := 
        (: If the submodule matches a view package, use the specific commit used by Rails. :)
        if ( $repoID eq $dpkg:github-vpkg-repo and exists($updateEntry/git/@commit/data(.)) ) then
          $updateEntry/git/@commit/data(.)
        (: If the submodule is not a view package, use the commit referenced by GitHub. :)
        else dpkg:call-github-contents-api($repoID,$repoPath,$branch)/pair[@name eq 'sha']/text()
      return 
        if ( contains($subRepo,' ') ) then ()
        else 
          try {
            dpkg:get-repo-archive($subRepo,$localPath,$commit),
            (: If the submodule is a view package, return complete git(Hub) info. :)
            if ( $repoID eq $dpkg:github-vpkg-repo and exists($updateEntry) ) then
              <package_ref>
                { $updateEntry/@* }
                <git>
                  { $updateEntry/git/@* }
                </git>
              </package_ref>
            else ()
          } catch * { () }
    (: Delete the ZIP file after we're done with it. :)
    let $deleteZip :=  xdb:remove($dpkg:home-directory, $zipFilename)
    return $getSubmodules
  };
  
  (: Identify the GitHub repository identifier of a different repository's submodule. :)
  declare
    %private
  function dpkg:get-submodule-identifier($repoID as xs:string, $repoPath as xs:string, $branch as xs:string) as xs:string {
    let $submoduleObj := dpkg:call-github-contents-api($repoID, $repoPath, $branch)
    let $gitURL := $submoduleObj/pair[@name eq 'git_url']/text()
    return
      if ( exists($gitURL) ) then 
        let $baseless := substring-after($gitURL,concat($dpkg:github-api-base,'/'))
        return substring-before($baseless,'/git/trees')
      else concat("No GitHub URL in ",$repoID," for ",$repoPath) (: error :)
  };
  
  (: Test if the eXist environment configuration, environment.xml, is available. :)
  declare
    %private
  function dpkg:is-environment-file-available() as xs:boolean {
    doc-available($dpkg:environment-defaults)
  };
  
  (: Test if the current, effective eXist user is a TAPAS user. This function will 
    silently fail in eXist v2.2. :)
  declare function dpkg:is-tapas-user() as xs:boolean {
    try {
      let $account := sm:id()
      let $matchGrp := function($text as xs:string) as xs:boolean { $text eq 'tapas' }
      return
        (: Use the 'effective' user if the 'real' user is acting as someone else. :)
        if ( $account[descendant::sm:effective] ) then
          exists($account//sm:effective//sm:group[$matchGrp(text())])
        else
          exists($account//sm:real//sm:group[$matchGrp(text())])
    } catch * { true() }
  };
  
  (: Get a list of all files changed between commits in a given GitHub repository. :)
  declare
    %private
  function dpkg:list-changed-files($repoID as xs:string, $oldCommit as xs:string, $newCommit as xs:string) {
    let $urlParts := ( $dpkg:github-api-base, $repoID, 'compare', concat($oldCommit,'...',$newCommit) )
    let $url := string-join($urlParts,'/')
    return dpkg:get-json-objects($url)/pair[@name eq 'files']/item[@type eq 'object']
  };
  
  (: Create all missing directories from an absolute path. :)
  declare
    %private 
  function dpkg:make-directories($absPath as xs:string) {
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
  
  (: If the Rails API URL doesn't match the default (production) Rails API, create 
    an attribute @rails-api with the custom URL. This attribute should be placed on 
    <view_registry> as necessary. :)
  declare
    %private
  function dpkg:define-rails-api-attribute() as item()? {
    let $railsAPI := dpkg:get-rails-api-url()
    return
      if ( $railsAPI eq $dpkg:default-rails-api ) then ()
      else attribute rails-api { $railsAPI }
  };
  
  (: Send a GET request. If the URL matches the Rails API URL and the environmental 
    configuration has a host defined, the EXPath HTTP client is used instead of 
    eXist's. This gets around what seems to be a bug in the way eXist's HTTP client 
    resolves URLs that include port numbers. :)
  declare
    %private
  function dpkg:send-request($url as xs:anyURI) as item()? {
    let $railsAPI := dpkg:get-rails-api-url()
    let $railsHost := dpkg:get-rails-api-host()
    return
      if ( $url eq $railsAPI and $railsHost ne '' ) then
        let $request :=
          <http:request method="GET" href="{$url}">
            <http:header name="Host" value="{$railsHost}"/>
          </http:request>
        let $response := http:send-request($request, $url)
        return 
          (: Create a fake eXist-HTTPclient response for the EXPath HTTP client response
            (thus saving the need to handle two formats elsewhere). :)
          <httpc:response statusCode="{$response[1]/@status/data(.)}">
            <httpc:headers/>
            <httpc:body>
              { $response[1]/http:body/@* }
              {
                typeswitch ($response[2])
                  case xs:base64Binary return util:base64-decode($response[2])
                  default return $response[2]
              }
            </httpc:body>
          </httpc:response>
      else 
        httpc:get($url, false(), <httpc:headers/>)
  };
  
  (: Unzip an archive. If there is a single outermost directory, it is ignored in 
    favor of its descendants. :)
  declare
    %private
  function dpkg:unpack-zip-archive($archivePath as xs:string, $dbPath as xs:string) {
    let $wrapperDirName := replace($archivePath, '^.*/(.+)\.zip$', '$1')
    let $outermostDir :=
      let $allOutermost := zip:entries(xs:anyURI($archivePath))
                            //zip:*[@name[count(tokenize(replace(.,'/$',''),'/')) eq 1]]
      return
        (: We only need to know the resource name if it is the only outermost 
          directory in the zip file. :)
        if ( count($allOutermost) eq 1 and local-name($allOutermost) eq 'dir' ) then
          $allOutermost/@name/xs:string(.)
        else ()
    (: Filter out the single outermost directory (if there is one). :)
    let $filterFn := 
      function($path as xs:string, $type as xs:string, $param as item()*) as xs:boolean {
        if ( exists($outermostDir) ) then
          not($type eq 'folder' and $path eq $outermostDir)
        else 
          $path ne concat($wrapperDirName, '/')
      }
    (: Build a URI for a given directory or resource. If needed, remove the outermost 
      directory name, since we don't want to preserve it. :)
    let $storageFn := 
      function($path as xs:string, $type as xs:string, $param as item()*) as xs:anyURI { 
        let $usePath := 
          if ( exists($outermostDir) ) then 
            substring-after($path, $outermostDir)
          else if ( matches($path, concat('^',$wrapperDirName)) ) then 
            substring-after($path, concat($wrapperDirName, '/'))
          else $path
        return
          concat($dbPath, '/', $usePath) cast as xs:anyURI 
      }
    (: Obtain the zip file and unpack it, using the functions above and eXist's 
      compression module. :)
    let $storedBinary := util:binary-doc($archivePath)
    return cprs:unzip($storedBinary, $filterFn, (), $storageFn, ())
  };
  
  (: Update a list of files from a 'Compare Commits' API response from GitHub. :)
  declare 
    %private
  function dpkg:update-files($targetDir as xs:string, $fileList as node()*) as xs:string* {
    for $fileRef in $fileList
    let $status := $fileRef/pair[@name eq 'status']/text()
    return
      if ( $status eq 'added' or $status eq 'modified' ) then
        if ( $fileRef/pair[@name eq 'raw_url']/@type/data(.) ne 'null' ) then
          dpkg:get-file-from-github($fileRef, $targetDir)
        else () (: XD: download submodule :)
      else () (: XD: delete files from eXist :)
  };
  
  (: Update $dpkg:home-directory using the $dpkg:github-vpkg-repo. :)
  declare 
    %private
  function dpkg:update-package-repo($timestamp as xs:string) {
    let $defaultBranch := dpkg:get-default-git-branch()
    let $newCommit := dpkg:get-commit-at($dpkg:github-vpkg-repo, $defaultBranch, $timestamp)
    (: Get a list of files changed since the last time the registry was updated. :)
    let $oldCommit := doc($dpkg:registry)/view_registry/git/@commit/data(.)
    let $fileList := dpkg:list-changed-files($dpkg:github-vpkg-repo, $oldCommit, $newCommit)
    (: For each file in the list (that isn't a submodule view package), either 
      download the file or delete it from eXist. :)
    let $files := dpkg:update-files($dpkg:home-directory, $fileList)
    (: Recreate the registry, using the same commit and timestamp for <git> under 
      <view_registry> and each non-submodule <package_ref>. :)
    return
      <git repo="{$dpkg:github-vpkg-repo}" branch="{$defaultBranch}" 
        commit="{$newCommit}" timestamp="{$timestamp}"/>
  };
  
  (: Given a package reference entry for a submodule of $dpkg:github-vpkg-repo, update 
    or create the local copy of that package. :)
  declare
    %private
  function dpkg:update-submodule($update as node()) {
    let $pkgID := $update/@name/data(.)
    let $pkgBranch := $update/git/@branch/data(.)
    let $targetDateTime := $update/git/@timestamp/data(.)
    (: Determine the correct package identifier to use for the view package. If the 
      package is a submodule, use its own package identifier, otherwise use 
      tapas-view-package. :)
    let $useRepo := 
      if ( $update/git[@repo] ) then
        $update/git/@repo/data(.)
      else () (: error :)
    let $useBranch := 
      if ( exists($pkgBranch) and $pkgBranch ne '' ) then $pkgBranch
      else dpkg:get-default-git-branch()
    let $newCommit := $update/git/@commit/data(.)
    let $pkgDir := dpkg:get-package-directory($pkgID)
    let $pkgEntry := dpkg:get-registry-entry($pkgID)
    let $installUpdate :=
      if ( $pkgEntry ) then
        let $oldCommit := $pkgEntry/git/@commit/data(.)
        let $changedFiles := dpkg:list-changed-files($useRepo, $oldCommit, $newCommit)
        return dpkg:update-files($pkgDir, $changedFiles)
      (: If the view package is a submodule and being added to eXist for the first 
        time, install its files from a ZIP archive. :)
      else 
        dpkg:get-repo-archive($useRepo, dpkg:get-package-directory($pkgID), $useBranch)
    (: If the update returns strings of filepaths, and the view package is proven to 
      be populated, create or update the registry entry for the package. :)
    return
      typeswitch ($installUpdate)
        case xs:string* return
          let $conf := dpkg:get-configuration($pkgID)
          return
            if ( count(xdb:get-child-resources($pkgDir)) ge 1 ) then
              let $entry := 
                <package_ref>
                  { $update/@* }
                  <conf>
                    {
                      if ( $conf ) then $conf/base-uri()
                      else () (: error :)
                    }
                  </conf>
                  <git>{ $update/git/@* }</git>
                </package_ref>
              return $entry
            else $installUpdate (: error :)
        default return $installUpdate (: error :)
  };
