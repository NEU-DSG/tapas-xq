xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;

declare function local:get-extension($filename as xs:string) as xs:string {
  let $name := replace($filename, '.*[/\\]([^/\\]+)$', '$1')
  return 
      if (contains($name, '.'))
      then replace($name, '.*\.([^\.]*)$', '$1')
      else ''
};
    
if (local:get-extension($exist:resource) eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{concat($exist:controller, $exist:path, '.xq')}"/>
    </dispatch>

else
    <ignore xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </ignore>
