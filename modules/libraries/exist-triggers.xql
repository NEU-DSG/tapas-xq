xquery version "3.0";

module namespace wtrig='http://www.wwp.northeastern.edu/ns/exist-trigger/functions';

declare namespace sm='http://exist-db.org/xquery/securitymanager';
declare namespace trigger='http://exist-db.org/xquery/trigger';

(:~
  Functions which will be triggered after users act on documents or collections in 
  some way. To use this library, store it in eXist somewhere besides the folder for 
  which you want to create triggers. Then, create a collection configuration file 
  for the target folder, at `/db/system/config/db/PATH/TO/FOLDER/collection.xconf`.
  All external variables listed below must be provided values in the configuration
  file.
  
  MIT License
  
  Copyright (c) 2020 Northeastern University Women Writers Project
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
 :)

  (: The name of the group which should own the resources in the given folder. :)
  declare variable $wtrig:group-name as xs:string external;
  (: The Unix permissions to be used for the given folder. :)
  declare variable $wtrig:coll-mode as xs:string external;
  (: The Unix permissions to be used for documents within the given folder. :)
  declare variable $wtrig:doc-mode as xs:string external;
  
  (:~ After a collection is created within eXist, give that collection the default 
    permissions for resources in that collection. If a group name is provided, the 
    document will be assigned to that group (rather than the user's primary group, 
    which is the default). :)
  declare function trigger:after-create-collection($uri as xs:anyURI) {
    wtrig:edit-permissions($uri, $wtrig:coll-mode)
  };
  
  (:~ After a document is created within an eXist collection, give that document the 
    default permissions for resources in that collection. If a group name is provided,
    the document will be assigned to that group (rather than the user's primary group,
    which is the default). :)
  declare function trigger:after-create-document($uri as xs:anyURI) {
    wtrig:edit-permissions($uri, $wtrig:doc-mode)
  };
  
  declare %private function wtrig:edit-permissions($uri as xs:anyURI, $mode as xs:string) {
    (: Make sure that the given mode is in the expected format. :)
    if ( matches($mode,'([r-][w-][x-]){3,3}') ) then
    (
      sm:chmod($uri, $mode),
      if ( exists($wtrig:group-name) and $wtrig:group-name ne '' ) then
        sm:chgrp($uri, $wtrig:group-name)
      else ()
    )
    else () (: error :)
  };
