xquery version "3.1";

(:  LIBRARIES  :)
  import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs"
    at "../libraries/view-pkgs.xql";
(:  NAMESPACES  :)
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
(:  OPTIONS  :)
  (:declare option output:indent "no";:)

(:~
  Initialize the view packages available to TAPAS-xq by downloading code from GitHub.
  This script is intended to be run after installation, and as such, includes some
  checks to ensure that TAPAS-xq is set up properly.
  
  @author Ash Clark
  @since 2023
 :)


(:  MAIN QUERY  :)

(: Make sure the 'tapas' user is logged in and has write access. :)
if ( not(dpkg:can-write()) ) then
  "Cannot write to the view packages directory. Are you logged in?"
(: Make sure the environment settings file is available. :)
else if ( not(doc-available($dpkg:environment-defaults)) ) then
  "Could not find /db/environment.xml"
(: Make sure that Rails can be reached. :)
else 
  let $railsResponse := dpkg:get-rails-packages()
  return
    if ( $railsResponse[self::p] ) then
      $railsResponse/data(.)
    (: Check for an existing registry. :)
    else if ( doc-available($dpkg:registry) ) then
      "The view packages have already been initialized. Stopping."
    (: If all tests passed, we can initialize the TAPAS view packages. :)
    else (
      "Initializing view packages...",
      dpkg:initialize-packages()
    )
