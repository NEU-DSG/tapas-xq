xquery version "3.0";

module namespace xslHdlr="http:/localhost:8983/exist/apps/xslhdlr";

declare namespace json="http://www.json.org";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $xslHdlr:tapas-wide := "/db/data";

(: Hello World function for testing. :)
declare
    %rest:path("hello") 
    %rest:GET 
    %rest:query-param("name", "{$name}", "world")
    %rest:produces("application/json") 
    %output:method("json") 
    function xslHdlr:as-json($name) {
  xslHdlr:hello($name)
};
declare
    %rest:path("hello") 
    %rest:GET 
    %rest:query-param("name", "{$name}", "world")
    %rest:produces("application/xml") 
    function xslHdlr:hello($name) {
  <response>
    <title>Hello {$name}!</title>
  </response>
};

(: The parts of a multipart message are represented as a sequence. :)
declare
    %rest:path("generate-tfc") 
    %rest:POST
    function xslHdlr:tfc() {
        let $input := doc("/db/test_y.xml")
        let $result := transform:transform($input, doc("../resources/tfc-generator.xsl"), ())
        (: Initiate the metadata process. :)
        
        (:  :)
        
        return $result
(:        let $streamableResult := util:string-to-binary($result):)
(:        return response:stream-binary($streamableResult, "application/octet-stream", "test.xml"):)
};
declare
    %rest:path("generate-tfc") 
    %rest:GET 
    function xslHdlr:generate-tfc() {
        let $input := doc("/db/test_y.xml")
        return transform:transform($input, doc("../resources/tfc-generator.xsl"), ())
};
