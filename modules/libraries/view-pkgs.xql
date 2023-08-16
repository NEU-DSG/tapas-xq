xquery version "3.1";

  module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs";
(:  NAMESPACES  :)
  declare namespace err="http://www.w3.org/2005/xqt-errors";
  (: 2023-05-08: The eXist HTTP client was deprecated in eXist v4 and removed in v5.
    While we don't use the functions, we still use the HTTPC format for responses in 
    this library. :)
  (:declare namespace httpc="http://exist-db.org/xquery/httpclient";:)
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";
(:  LIBRARIES  :)
  import module namespace cprs="http://exist-db.org/xquery/compression";
  import module namespace file="http://exist-db.org/xquery/file";
  import module namespace http="http://expath.org/ns/http-client";
  import module namespace sm="http://exist-db.org/xquery/securitymanager";
  import module namespace util="http://exist-db.org/xquery/util";
  import module namespace xdb="http://exist-db.org/xquery/xmldb";
  import module namespace zip="http://expath.org/ns/zip";

(:~
  This library contains functions for dynamically updating and maintaining the view 
  packages available in eXist.
  
  @author Ash Clark
  @version 1.5
  
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

(:  VARIABLES  :)

  declare variable $dpkg:default-rails-api := 
    'https://railsapi.tapasproject.org/api/view_packages';
  declare variable $dpkg:environment-defaults := '/db/environment.xml';
  declare variable $dpkg:github-api-base := 'https://api.github.com/repos';
  declare variable $dpkg:github-raw-base := 'https://raw.githubusercontent.com';
  declare variable $dpkg:github-vpkg-repo := 'NEU-DSG/tapas-view-packages';
  declare variable $dpkg:home-directory := '/db/tapas-view-pkgs';
  declare variable $dpkg:registry-name := 'registry.xml';
  declare variable $dpkg:registry := 
    concat($dpkg:home-directory,'/',$dpkg:registry-name);
  
  declare variable $dpkg:valid-reader-types := 
    for $pkg in doc($dpkg:registry)/view_registry/package_ref
    return $pkg/@name/data(.);


(:
    FUNCTIONS:
    
    - view packages
    - Rails
    - updating
    - http requests
 :)

  (:~
    Create an error's QName in an app-specific namespace. 
    
    @return A qualified name in the TAPAS error namespace.
   :)
  declare %private function dpkg:error-qname($name as xs:string) as xs:QName {
    QName("http://tapasproject.org/tapas-xq/view-pkgs/err", $name)
  };


(:
 :  FUNCTIONS, view packages
 :)

  (:~
    Get a configuration file for a given view package. 
    
    Since the configuration filename can begin with anything as long as it ends in 
    'CONFIG.xml', this function takes the first-occurring file matching this criteria.
    
    @return The view package configuration file, <vpkg:view_package>.
   :)
  declare function dpkg:get-configuration($pkgID as xs:string) as item()* {
    let $parentDir := concat($dpkg:home-directory,'/',$pkgID)
    return 
      (: It turns out this use of collection() is eXist-specific. It outputs all
        files in descendant collections. Saxon will not do the same. :)
      collection($parentDir)[matches(base-uri(), 'CONFIG\.xml$')][1]/vpkg:view_package
  };
  
  (:~
    Get the absolute path to the directory for a given view package ID. No attempt is 
    made to check if the identifier matches an actual view package; this function just 
    builds the path for the collection where the package would be stored.
    
    @return The path to a view package collection in eXist.
   :)
  declare function dpkg:get-package-directory($pkgID as xs:string) as xs:string {
    concat($dpkg:home-directory,'/',$pkgID)
  };
  
  (:~
    Turn a relative filepath from a view package directory into an absolute filepath.
    
    @return An absolute filepath to a view package collection.
   :)
  declare function dpkg:get-path-from-package($pkgID as xs:string, $relativePath as xs:string)
     as xs:string {
    if ( not(dpkg:is-valid-view-package($pkgID)) ) then
      error(dpkg:error-qname('InvalidViewPkg'), 
        concat("There is no view package named '",$pkgID,"'"))
    else
      let $pkgHome := dpkg:get-package-directory($pkgID)
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
  declare function dpkg:get-registry-entry($pkgID as xs:string) as node()? {
    doc($dpkg:registry)//package_ref[@name eq $pkgID]
  };
  
  (:~
    Get the <run> element from a package's configuration file.
    
    @return The <vpkg:run> element from the given view package's configuration.
   :)
  declare function dpkg:get-run-stmt($pkgID as xs:string) as node()? {
    let $config := dpkg:get-configuration($pkgID)
    return $config/vpkg:run
  };
  
  (:~
    Determine if an identifier matches that of a valid view package.
    
    @return True if the string provided matches a registered view package.
   :)
  declare function dpkg:is-valid-view-package($name as xs:string) as xs:boolean {
    $name = $dpkg:valid-reader-types
  };


(:
 :  FUNCTIONS, Rails
 :)
  
  (:~
    If the Rails API URL doesn't match the default (production) Rails API, create 
    an attribute @rails-api with the custom URL. This attribute should be placed on 
    <view_registry> as necessary.
    
    @return An attribute @rails-api.
   :)
  declare %private function dpkg:define-rails-api-attribute() as item()? {
    let $railsAPI := dpkg:get-rails-api-url()
    return
      if ( $railsAPI eq $dpkg:default-rails-api ) then ()
      else attribute rails-api { $railsAPI }
  };
  
  (:~
    Query the TAPAS Rails API for its stored view packages.
   :)
  declare function dpkg:get-rails-packages() as node()* {
    let $railsAddr := xs:anyURI(dpkg:get-rails-api-url())
    let $response := dpkg:get-json-objects($railsAddr)
    return 
      if ( $response[self::p] ) then (: TODO: normalize error handling :)
        <p class="error">Could not connect to Rails.</p>
      else $response
  };
  
  (:~
    Return package reference entries for each view package newer in Rails than in the 
    XML database. Git commit timestamps are used for comparison.
   :)
  declare function dpkg:get-updatable() as item()* {
    let $railsPkgs := dpkg:get-rails-packages()
    let $registryExists := 
      doc-available($dpkg:registry) and doc($dpkg:registry)[descendant::package_ref]
    let $upCandidates :=
      if ( empty($railsPkgs) ) then ()
      else
        dpkg:get-updatable-candidates-from-rails($railsPkgs)
    return
      if ( $upCandidates/p[@class eq 'error'] ) then
        $upCandidates/p[@class eq 'error']
      else if ( not($registryExists) ) then $upCandidates
      else
        for $candidate in $upCandidates
        let $expectedDir := $candidate/fn:string[@key eq 'dir_name']/text()
        let $registryPkg := 
          if ( exists($expectedDir) ) then 
            dpkg:get-registry-entry($expectedDir) 
          else ()
        (: Flag for update those packages where the external version has a newer git 
          timestamp than eXist's version. :)
        return
          if ( not(exists($registryPkg)) 
               or $registryPkg/git/@timestamp/data(.) lt $candidate/git/@timestamp/data(.) ) then
            $candidate
          (: If the package is up-to-date, do nothing. :)
          else ()
  };
  
  (:~
    Test if the eXist environment configuration, environment.xml, is available.
    
    @return True if the environment settings document exists.
   :)
  declare %private function dpkg:is-environment-file-available() as xs:boolean {
    doc-available($dpkg:environment-defaults)
  };


(:
 :  FUNCTIONS, updating
 :)
  
  (:~
    Test if the current user can write to $dpkg:home-directory.
   :)
  declare %private function dpkg:can-write() {
    sm:has-access(xs:anyURI($dpkg:home-directory),'rwx')
  };
  
  (:~
    Get the host of the Rails API for use in a request header.
   :)
  declare %private function dpkg:get-rails-api-host() as xs:string {
    if ( dpkg:is-environment-file-available() and 
         doc($dpkg:environment-defaults)//railsBaseURI[@host] ) then
      doc($dpkg:environment-defaults)//railsBaseURI/@host/data(.) 
    else ''
  };
  
  (:~
    Get the Rails API URL.
   :)
  declare function dpkg:get-rails-api-url() as xs:string {
    if ( dpkg:is-environment-file-available() and 
        doc($dpkg:environment-defaults)//railsBaseURI[normalize-space(text()) ne ''] ) then
      concat(doc($dpkg:environment-defaults)//railsBaseURI/text(), '/api/view_packages') 
    else $dpkg:default-rails-api
  };
  
  (:~
    Given a sequence of view packages defined by the Rails API, create a registry entry 
    for each one.
   :)
  declare %private function dpkg:get-updatable-candidates-from-rails($rails-packages as element()+) {
    if ( $rails-packages/p[@class eq 'error'] ) then $rails-packages/p
    else
      for $railsPkg in $rails-packages[fn:map]
      let $dirName := $railsPkg/fn:string[@key eq 'dir_name']/text()
      let $branch := $railsPkg/fn:string[@key eq 'git_branch']/text()
      let $isSubmodule := exists($branch) and $branch ne ''
      let $registryPkg := 
        if ( exists($dirName) ) then 
          dpkg:get-registry-entry($dirName) 
        else ()
      let $useBranch := 
        if ( $isSubmodule ) then $branch 
        else dpkg:get-default-git-branch()
      let $useRepo := 
        if ( not($isSubmodule) ) then $dpkg:github-vpkg-repo
        else if ( exists($registryPkg) ) then $registryPkg/git/@repo/data(.)
        else
          let $subRepo := 
            dpkg:get-submodule-identifier($dpkg:github-vpkg-repo, $dirName, $useBranch)
          return 
            if ( contains($subRepo, ' ') ) then 
              ' ' (: error :)
            else $subRepo
      let $gitTimeR := $railsPkg/fn:string[@key eq 'git_timestamp']/text()
      let $makeEntry := function() {
          <package_ref name="{$dirName}">{
              if ( $isSubmodule ) then
                attribute submodule { true() }
              else ()
            }
            <git>
              {
                if ( $isSubmodule ) then (
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
      return $makeEntry()
  };
  
  (:~
    Determine if the current eXist user can write to the $dpkg:home-directory.
   :)
  declare function dpkg:has-write-access() as xs:boolean {
    dpkg:is-tapas-user() and dpkg:can-write()
  };
  
  (:~
    Get the contents of $dpkg:github-vpkg-repo at the default git branch by 
    retrieving its ZIP archive from GitHub. Set up the view package registry.
   :)
  declare function dpkg:initialize-packages() {
    (: Only proceed if the current user is a TAPAS user. This ensures that the 
      contents of $dpkg:home-directory will be owned by that user. :)
    if ( dpkg:has-write-access() ) then
      (: Create <git> to hold data on $dpkg:github-vpkg-repo. :)
      let $vpkgGitInfo :=
        let $defaultBranch := dpkg:get-default-git-branch()
        let $urlParts := ( $dpkg:github-api-base, $dpkg:github-vpkg-repo, 
                            'branches', $defaultBranch )
        let $branchURL := string-join($urlParts,'/')
        let $responseObj := dpkg:get-json-objects($branchURL)
        let $commitObj := $responseObj/fn:map[@key eq 'commit']
        let $timestamp :=
          $commitObj/fn:map[@key eq 'commit']/fn:map[@key eq 'author']/fn:string[@key eq 'date']/text()
        return
          <git repo="{$dpkg:github-vpkg-repo}" branch="{$defaultBranch}"
            commit="{$commitObj/fn:string[@key eq 'sha']/text()}"
            timestamp="{$timestamp}"/>
      (: Get the current commit on the default branch. :)
      let $vpkgCommit := $vpkgGitInfo/@commit/data(.)
      (: Get a ZIP archive of $dpkg:github-vpkg-repo, and unpack it into 
        $dpkg:home-directory. This process also obtains and unpacks any git submodules. :)
      let $mainRepo :=
        dpkg:get-repo-archive($dpkg:github-vpkg-repo, $dpkg:home-directory, $vpkgCommit)
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
                    <git>{ $vpkgGitInfo/@commit, $vpkgGitInfo/@timestamp }</git>
                }
              </package_ref>
          }
        </view_registry>
      return 
        if ( exists($vpkgCommit) ) then
          xdb:store($dpkg:home-directory, $dpkg:registry-name, $registry)
        else error(dpkg:error-qname('GitHubApi'), "Could not find a commit in GitHub API response.")
    else
      error(dpkg:error-qname('UserAuth'), "This action must be completed by the 'tapas' user.")
  };
  
  (:~
    Test if the current, effective eXist user is a TAPAS user. This function will not
    work as expected in eXist v2.2.
    
    @return True if the current user is "tapas"; otherwise, false.
   :)
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
    } catch * { false() }
  };
  
  (:~
    Create all missing directories from an absolute path.
    
    @return A string if the collection was created. Otherwise, an empty sequence.
   :)
  declare %private function dpkg:make-directories($absPath as xs:string) as xs:string? {
    let $tokenizedPath := tokenize($absPath,'/')
    return 
      for $index in 1 to count($tokenizedPath)
      let $newDir := $tokenizedPath[$index]
      let $targetDir := 
        let $tokens := subsequence($tokenizedPath, 1, $index - 1)
        let $parentPath := if ( $index le 1 ) then '' else string-join($tokens,'/')
        return $parentPath
      return 
        if ( not(xdb:collection-available(concat($targetDir,$newDir))) ) then
          xdb:create-collection($targetDir,$newDir)
        else ()
  };
  
  (:~
    Unzip an archive. If there is a single outermost directory, it is ignored in 
    favor of its descendants.
   :)
  declare function dpkg:unpack-zip-archive($archivePath as xs:string, $dbPath as xs:string) {
    let $wrapperDirName := replace($archivePath, '^.*/(.+)\.zip$', '$1')
    let $zipEntries := zip:entries(xs:anyURI($archivePath))
    let $outermostDirs := $zipEntries//*[@name[matches(., '^[-\w]+/$')]]
    let $ignorableDir :=
      if ( count($outermostDirs) eq 1 ) then
        $outermostDirs/@name/data(.)
      else ()
    return
      for $entry in $zipEntries/zip:*[not($ignorableDir) or not(@name eq $ignorableDir)]
      let $entryName := $entry/@name/data(.)
      let $relativePath := 
        substring-after($entryName, $ignorableDir) => replace('/$', '')
      let $pathParts := tokenize($relativePath, '/')
      let $parentDir :=
        if ( count($pathParts) eq 1 ) then ()
        else string-join(remove($pathParts, count($pathParts)), '/')
      let $parentPath :=
        concat( if ( ends-with($dbPath,'/') ) then $dbPath else concat($dbPath,'/'), $parentDir)
      let $parentAvailable := xdb:collection-available($parentPath)
      return
        (: If the parent directory is not available, do nothing. :)
        if ( not($parentAvailable) ) then
          concat("Skipping ",$relativePath)
        (: If this is an entry for a directory, create it inside its parent. :)
        else if ( $entry[self::zip:dir] ) then
          xdb:create-collection($parentPath, $pathParts[last()])
        (: If this is an entry for a file, use context clues to figure out how to 
          extract it from the ZIP file and how to store it in eXist. :)
        else if ( $entry[self::zip:entry] ) then
          let $filename := $pathParts[last()]
          let $fileExtension := 
            let $filename := lower-case($filename)
            (: If the file was hidden, or has no file extension, assume it's a text 
              file. :)
            let $assumeTextFile :=
              starts-with($filename, '.') or not(contains($filename, '.'))
            return
              if ( $assumeTextFile ) then 'txt'
              else replace($filename, '^.+\.([\w]+)$', '$1')
          return
            switch ($fileExtension)
              (: Store various flavors of XML as XML. :)
              case 'xml' case 'rng' case 'svg' case 'xhtml' 
              case 'xpl' case 'xsl' case 'xslt' return 
                let $file := zip:xml-entry(xs:anyURI($archivePath), $entryName)
                return xdb:store($parentPath, $filename, $file)
              (: Extract HTML using the EXPath ZIP module, which ensures it will 
                yield an XML serialization that can be stored. :)
              case 'html' return
                let $file := zip:html-entry(xs:anyURI($archivePath), $entryName)
                return xdb:store($parentPath, $filename, $file, 'text/html')
              (: Extract images (and others?) as binary files and store them as such. :)
              case 'gif' case 'jpeg' case 'jpg' case 'png' case 'pxm' return
                let $file := zip:binary-entry(xs:anyURI($archivePath), $entryName)
                return xdb:store-as-binary($parentPath, $filename, $file)
              (: Everything else is extracted as a text file and stored as binary. :)
              default return
                let $file := zip:text-entry(xs:anyURI($archivePath), $entryName)
                return xdb:store-as-binary($parentPath, $filename, $file)
        else "SOMETHING WENT WRONG" (: TODO: error :)
  };
  
  (:~
    Update a list of files from a 'Compare Commits' API response from GitHub.
   :)
  declare %private function dpkg:update-files($targetDir as xs:string, $fileList as node()*) as xs:string* {
    for $fileRef in $fileList
    let $status := $fileRef/fn:string[@key eq 'status']/text()
    return
      if ( $status eq 'added' or $status eq 'modified' ) then
        if ( $fileRef/fn:string[@key eq 'raw_url'] ) then
          dpkg:get-file-from-github($fileRef, $targetDir)
        else () (: TODO: download submodule :)
      else () (: TODO: delete files from eXist :)
  };
  
  (:~
    For each updatable package, find the git commit that Rails is using, then 
    download the package's files and create or update its registry entry.
   :)
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
            let $repoPkgs :=
              $toUpdate/descendant-or-self::package_ref[not(@submodule) or @submodule/data(.) eq 'false']
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
  
  (:~
    Update $dpkg:home-directory using the $dpkg:github-vpkg-repo.
   :)
  declare function dpkg:update-package-repo($timestamp as xs:string) {
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
  
  (:~
    Given a package reference entry for a submodule of $dpkg:github-vpkg-repo, update 
    or create the local copy of that package.
   :)
  declare %private function dpkg:update-submodule($update as node()) {
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
                  <conf>{
                    if ( $conf ) then $conf/base-uri()
                    else () (: error :)
                  }</conf>
                  <git>{ $update/git/@* }</git>
                </package_ref>
              return $entry
            else $installUpdate (: error :)
        default return $installUpdate (: error :)
  };
  
  
(:
 : FUNCTIONS, http requests
 :)
  
  (:~
    Query GitHub's API for repository contents, using a specified git branch.
   :)
  declare function dpkg:call-github-contents-api($repoID as xs:string, $repoPath as xs:string, 
     $branch as xs:string) {
    let $apiURL := 
      concat($dpkg:github-api-base,'/',$repoID,'/contents/',$repoPath,'?ref=',$branch)
    return dpkg:get-json-objects($apiURL)
  };
  
  (:~
    Return the paths for any git submodules (as indicated by empty directories, which 
    git is not able to track). This should only be run after unpacking a GitHub 
    repository from a ZIP file, before that file is deleted. 
   :)
  declare function dpkg:find-submodule-dirs($zipPath as xs:string) as xs:string* {
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
  
  (:~
    Query GitHub's API for a repository's commits matching the timestamp given by Rails.
   :)
  declare function dpkg:get-commit-at($repoID as xs:string, $branch as xs:string, 
     $dateTime as xs:string) { (: TODO: why not cast $dateTime as xs:dateTime here? :)
    if ( $dateTime castable as xs:dateTime ) then
      try {
        let $apiURL := 
          concat($dpkg:github-api-base,'/',$repoID,'/commits?sha=',$branch,'&amp;since=',$dateTime)
        let $pseudoJSON := dpkg:get-json-objects($apiURL)[1]
        return $pseudoJSON/*[@key eq 'sha']/text()
      } catch * {
        () (: error :)
      }
    else () (: error :)
  };
  
  (:~
    Get the name of the git branch to use by default.
   :)
  declare function dpkg:get-default-git-branch() as xs:string {
    if ( dpkg:is-environment-file-available() and 
        exists(doc($dpkg:environment-defaults)//defaultGitBranch/@name) ) then 
      doc($dpkg:environment-defaults)//defaultGitBranch/@name/data(.) 
    else 'master'
  };
  
  (:~
    Download a file using data from GitHub's 'Compare Commits' API.
   :)
  declare %private function dpkg:get-file-from-github($jsonObj as node(), $pathBase as xs:string) {
    let $relPath := $jsonObj/fn:string[@key eq 'filename']/text()
    let $filename := tokenize($relPath,'/')[last()]
    let $folder := concat($pathBase, '/', substring-before($relPath,concat('/',$filename)))
    let $downloadURL := $jsonObj/fn:string[@key eq 'raw_url']/text()
    return
      if ( not(exists(dpkg:make-directories($folder))) ) then
        () (: error :)
      else if ( not(exists($downloadURL)) or not($downloadURL castable as xs:anyURI) ) then
        () (: error :)
      else
        let $download := dpkg:send-request(xs:anyURI($downloadURL))
        return
          (: Pass along errors generated in dpkg:send-request(). :)
          if ( not(dpkg:is-valid-response($download)) ) then
            $download
          else
            let $body := dpkg:get-response-body($download)
            return 
              if ( (:exists($folder) and:) exists($body) and count($body) eq 1 ) then
                let $mimetype := 
                  concat('text/',substring-after($body?('media-type'),'/'))
                return xdb:store($folder, $filename, $body?('content'), $mimetype) 
              else () (: error :)
  };
  
  (:~
    Send out a query, and log any HTTP response that isn't "200 OK".
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
        let $jsonStr := 
          if ( $body?('media-type') = ('application/json', 'text/json') ) then
            $body?('content')
          else ()
        return 
          if ( exists($jsonStr) ) then
            let $pseudojson := json-to-xml($jsonStr)/*
            return 
              typeswitch ($pseudojson)
                case element(fn:map) return $pseudojson
                case element(fn:array) return $pseudojson/fn:map
                default return ()
          else
            <p class="error">ERROR: Empty or non-JSON response</p> (: error :)
  };
  
  (:~
    Get and unpack an archive of the contents of a GitHub repository.
   :)
  declare function dpkg:get-repo-archive($repoID as xs:string, $dbPath as xs:string, 
     $branch as xs:string) {
    let $zipURL := 
      let $urlParts := ($dpkg:github-api-base, $repoID, 'zipball', $branch)
      return xs:anyURI(string-join($urlParts,'/'))
    let $response := dpkg:send-request($zipURL)
    let $status := dpkg:get-response-status($response)
    let $isResponseZipped := function () as xs:boolean {
        $response[1]//http:body/@media-type/data(.) = 'application/zip'
      }
    return
      (: Pass along errors generated in dpkg:send-request(). :)
      if ( not(dpkg:is-valid-response($response)) ) then
        $response
      else if ( count($response) lt 2 or not($isResponseZipped()) ) then
        () (: error? :)
      else
        let $zipFilename := 
          let $contentDisposition := 
            $response[1]//http:header[@name eq lower-case('Content-Disposition')]
          return substring-after($contentDisposition/@value/data(.), 'filename=')
        let $binary := $response[2]
        let $archivePath :=
          if ( exists($binary) ) then
            xdb:store($dpkg:home-directory, $zipFilename, $binary, 'application/zip')
          else error(dpkg:error-qname('NoArchive'), "Compressed binary file not found.")
        let $unzipped := dpkg:unpack-zip-archive($archivePath, $dbPath)
        (: Identify any submodules; download and unpack their archives. :)
        let $submoduleDirs := dpkg:find-submodule-dirs($archivePath)
        let $updatablePkgs := dpkg:get-updatable()
        let $railsIsAvailable := not(exists($updatablePkgs/p[@class eq 'error']))
        let $getSubmodules := 
          for $localPath in $submoduleDirs
          let $repoPath := substring-after($localPath, concat($dbPath,'/'))
          let $subRepo := dpkg:get-submodule-identifier($repoID, $repoPath, $branch)
          let $updateEntry := dpkg:get-updatable()[@submodule eq 'true'][contains(@name, $subRepo)]
          let $commit := 
            (: If the submodule matches a view package, try to use the specific commit used by Rails. :)
            if ( $repoID eq $dpkg:github-vpkg-repo 
                  and $railsIsAvailable 
                  and exists($updateEntry/git/@commit/data(.)) ) then
              $updateEntry/git/@commit/data(.)
            (: If Rails is not available, or the submodule is not a view package, use the commit 
              referenced by GitHub. :)
            else
              dpkg:call-github-contents-api($repoID, $repoPath, $branch)/fn:string[@key eq 'sha']/text()
          return 
            if ( contains($subRepo, ' ') ) then ()
            else 
              try {
                dpkg:get-repo-archive($subRepo, $localPath, $commit),
                (: If the submodule is a view package tracked by Rails, return complete git(Hub) info. :)
                if ( $repoID eq $dpkg:github-vpkg-repo and exists($updateEntry) ) then
                  <package_ref>
                    { $updateEntry/@* }
                    <git>
                      { $updateEntry/git/@* }
                    </git>
                  </package_ref>
                else if ( not($railsIsAvailable) ) then (: TODO :)
                  <package_ref>
                    
                    <git>
                      
                    </git>
                  </package_ref>
                else ()
              } catch * { () }
        (: Delete the ZIP file after we're done with it. :)
        (:let $deleteZip :=  xdb:remove($dpkg:home-directory, $zipFilename):)
        return $getSubmodules
  };
  
  (:~
    Retrieve the HTTP status code from an HTTP response.
    
    @return The HTTP code as a string, if available. Otherwise, an empty sequence.
   :)
  declare function dpkg:get-response-status($http-response as item()*) as xs:string? {
    if ( exists($http-response) ) then
      $http-response[1]/@status/data(.)
    else ()
  };
  
  (:~
    From an EXPath HTTP Client response, create a map for each body, with its contents and media-type.
    
    @return One map for each response body. Each map contains "media-type" and "content".
   :)
  declare function dpkg:get-response-body($http-response as item()*) as map(xs:string, item())* {
    let $mediaTypes := 
      let $contentType := $http-response[1]//http:header[@name eq 'content-type']/@value
      return
        if ( matches($contentType, '^[\w+-]+/[\w+-]+;') ) then
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
            case xs:base64Binary return util:base64-decode($body)
            default return $body
      return
        map { 'media-type': $mediaType, 'content': $bodyContent }
  };
  
  (:~
    Identify the GitHub repository identifier of a different repository's submodule.
   :)
  declare %private function dpkg:get-submodule-identifier($repoID as xs:string, $repoPath as xs:string,
     $branch as xs:string) as xs:string {
    let $submoduleObj := dpkg:call-github-contents-api($repoID, $repoPath, $branch)
    let $gitURL := $submoduleObj/*[@key eq 'git_url']/text()
    return
      if ( exists($gitURL) ) then 
        let $baseless := substring-after($gitURL, concat($dpkg:github-api-base,'/'))
        return substring-before($baseless, '/git/trees')
      else concat("No GitHub URL in ",$repoID," for ",$repoPath) (: error :)
  };
  
  declare %private function dpkg:is-valid-response($response as item()*) as xs:boolean {
    exists($response[1][self::http:*]) and not(exists($response[self::Q{}p[@type]]))
  };
  
  (:~
    Get a list of all files changed between commits in a given GitHub repository.
   :)
  declare function dpkg:list-changed-files($repoID as xs:string, $oldCommit as xs:string, 
     $newCommit as xs:string) {
    let $urlParts := ( $dpkg:github-api-base, $repoID, 'compare', concat($oldCommit,'...',$newCommit) )
    let $url := string-join($urlParts,'/')
    return dpkg:get-json-objects($url)/fn:array[@key eq 'files']/fn:map
  };
  
  (:~
    Send a GET request, timing out if the server takes over 15 seconds to respond. 
   :)
  declare function dpkg:send-request($url as xs:anyURI) as item()* {
    let $reqConfig :=
      if ( $url eq dpkg:get-rails-api-url() ) then
        (: If the request is to the Rails API and environment.xml has a DNS address 
          listed, add that address to the "Host" header. :)
        let $railsHost := dpkg:get-rails-api-host()
        return
          if ( $railsHost ne '' ) then
            <http:header name="Host" value="{$railsHost}"/>
          else ()
      else ()
    let $request :=
      <http:request method="GET" href="{$url}" timeout="15">
        { $reqConfig }
      </http:request>
    let $response :=
      (: Recover from any errors, but log them. :)
      try { http:send-request($request, $url) }
      catch * {
        let $message :=
          "TAPAS-xq could not send request to "||$url||". Full error: "
          ||$err:code||" "||$err:value||"--"||$err:description
        return (
            util:log('warn', $message),
            <p class="error">{ $message }</p>
          )
      }
    return
      if ( empty($response) or empty(dpkg:get-response-status($response)) ) then
        $response
      else if ( dpkg:get-response-status($response) ne '200' ) then
        <p class="error">Request to {$url} failed with response {
          dpkg:get-response-status($response) }: { dpkg:get-response-body($response)?content }</p>
      else $response
  };
