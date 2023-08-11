xquery version "3.1";

  (:declare boundary-space preserve;:)
(:  LIBRARIES  :)
  import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs"
    at "../libraries/view-pkgs.xql";
(:  NAMESPACES  :)
  (:declare default element namespace "http://www.wwp.northeastern.edu/ns/textbase";:)
  declare namespace array="http://www.w3.org/2005/xpath-functions/array";
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace tei="http://www.tei-c.org/ns/1.0";
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

(: Make sure the 'tapas' user is logged in. :)
if ( not(dpkg:is-tapas-user()) ) then
  "Log in as the 'tapas' user before running this script!"
(: Make sure the environment settings file is available. :)
else if ( not(doc-available($dpkg:environment-defaults)) ) then
  ""
(: Make sure that Rails can be reached. :)
else if ( dpkg:get-rails-packages()[self::p] ) then
  ""
(: Check for an existing registry. :)
else if ( doc-available($dpkg:registry) ) then
  "The view packages have already been initialized. Stopping."
(: If all tests passed, we can initialize the TAPAS view packages. :)
else (
  "Initializing view packages...",
  dpkg:initialize-packages()
)
