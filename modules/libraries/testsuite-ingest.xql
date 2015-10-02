xquery version "3.0";

module namespace txqt="http://tapasproject.org/tapas-xq/testsuite";
import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace http="http://expath.org/ns/http-client";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mods="http://www.loc.gov/mods/v3";

(:~
 : @author Ashley M. Clark
 : @version 1.0
:)

declare variable $txqt:host := "http://localhost:8080/exist/apps/tapas-xq";

declare %private function txqt:set-http-request($method as xs:string, $href as xs:anyURI, $partSeq as item()*) {
  <http:request method="{$method}" href="{$href}" username="tapas-tester" password="freesample" auth-method="digest" send-authorization="true" http-version="1.0"> 
    {
      for $i in $partSeq
      return $i
    }
  </http:request>
};

declare %private function txqt:set-http-multipart($multipart-subtype as xs:string, $partSeq as item()+) {
  <http:multipart media-type="multipart/{$multipart-subtype}" boundary="xyzBOUNDSAWAYzyx">
    {
      for $i in $partSeq
      return $i
    }
  </http:multipart>
};

declare %private function txqt:set-http-header($name as xs:string, $value as xs:string) {
  <http:header name="{$name}" value='{$value}' />
};

declare %private function txqt:set-http-body($media-type as xs:string, $method as xs:string, $content) {
  <http:body media-type="{$media-type}" method="{$method}">
    { $content }
  </http:body>
};

declare
  %test:setUp
function txqt:_test-setup() {
  sm:create-account('tapas-tester','freesample','tapas')
};

declare
  %test:tearDown
function txqt:_test-teardown() {
  sm:remove-account('tapas-tester'),
  sm:remove-group('tapas-tester')
};

declare 
  %test:arg("name","World") %test:assertEquals("Hello World!")
function txqt:hello($name as xs:string) as xs:string {
  concat("Hello ",$name,"!")
};

declare 
  %test:assertExists
function txqt:testdoc() {
  $txqt:testDoc
};

declare
  %test:name("Derive MODS")
  %test:args('POST','true')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("namespace-uri($result[2]/*) eq 'http://www.loc.gov/mods/v3'")
  %test:args('POST','false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
  %test:args('PUT','false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
function txqt:derive-mods($method, $file) {
  let $request := txqt:set-http-request($method, xs:anyURI(concat($txqt:host,"/derive-mods")),
                  (
                    if ($file eq 'true') then
                        txqt:set-http-multipart("xml",
                        (
                          txqt:set-http-header("Content-Disposition",'form-data; name="file"'),
                          txqt:set-http-body("application/xml","xml",$txqt:testDoc)
                        ))
                    else ()
                  ))
  return http:send-request($request)
};

declare variable $txqt:testDoc := 
  <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:lang="en">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title>A Test for Metadata</title>
          <author>
            <name type="person">Joseph Cullen Ayer, Jr., Ph.D.</name>
            <persName>
              <persName>
                <roleName type="nobility">Princess</roleName>
                <forename sort="1">Diana</forename>
                <surname><surname sort="2">Prince</surname>, <surname type="matronym">daughter of Hippolyta</surname></surname>
              </persName>
              <persName>
                <addName type="professional">Wonder Woman</addName>
                <affiliation>Justice League of America</affiliation>
              </persName>
            </persName>
            <name>
              <roleName type="honorific" full="abb">Mme</roleName>
              <nameLink>de la</nameLink>
              <surname>Rochefoucault</surname>
            </name>
          </author>
          <editor><persName>Son of <persName>Bob</persName></persName></editor>
          <editor><choice><orig>A. Duck</orig><reg>Duck, Ann</reg></choice></editor>
        </titleStmt>
        <editionStmt>
          <edition n="1">Edition 1</edition>
        </editionStmt>
        <publicationStmt>
          <publisher>TAPAS</publisher>
          <date>September 1, 2015</date>
          <availability>
            <p>This file is free for anyone to use or distribute. Not sure why 
              you'd want to do so, but you can!</p>
          </availability>
        </publicationStmt>
        <sourceDesc>
          <bibl>
            <title type="custom">A Custom Title</title>
            <title type="marc245a">The Main Title</title>
            <title type="duplicate">A Custom Title</title>
            <title>A title with no type</title>
            <biblScope unit="page" from="13" to="89">pp. 13-89</biblScope>
            <biblScope>Selected passages from <title>BiblScope Title</title>.</biblScope>
          </bibl>
          <listBibl>
            <bibl>
              <bibl type="monogr">
                <title>Bibl/Bibl[@type='monogr'] Title</title>
              </bibl>
            </bibl>
            <biblFull>
              <titleStmt>
                <title>BiblFull Title</title>
                <title type="sub">Subtitle</title>
              </titleStmt>
              <publicationStmt>
                <publisher><orgName><persName>Kent</persName> and <persName>Wayne</persName></orgName> Inc.</publisher>
              </publicationStmt>
              <seriesStmt>
                <title>Battling for Peace</title>
                <editor>
                  <name>Barbara Gordon</name>
                </editor>
              </seriesStmt>
            </biblFull>
            <biblStruct>
              <monogr>
                <title>BiblStruct/monogr Title</title>
                <imprint>
                  <publisher>Imprint/publisher</publisher>
                </imprint>
              </monogr>
            </biblStruct>
            <msDesc>
              <msIdentifier>
                <repository>S.T.A.R. Labs</repository>
                <msName>A Previously Distinctly Separate Manuscript</msName>
              </msIdentifier>
              <msContents>
                <msItem>
                  <locus from="20v">20v</locus>
                  <editor>A. Thena</editor>
                  <title>On clay children</title>
                </msItem>
                <msItemStruct>
                  <locusGrp>
                    <locus>4-7ff.</locus>
                    <locus>10ff.</locus>
                  </locusGrp>
                  <bibl>
                    <ref target="tei_full_metadata.xml">Ref'd Title</ref>, by Whitman</bibl>
                  <textLang xml:lang="en" mainLang="la" otherLangs="de fr">Mostly in Latin with some German and French.</textLang>
                </msItemStruct>
              </msContents>
              <msPart>
                <msIdentifier>
                  <msName>msPart Identifier</msName>
                </msIdentifier>
                <p>msPart text</p>
              </msPart>
            </msDesc>
          </listBibl>
          <bibl> Created electronically. </bibl>
        </sourceDesc>
      </fileDesc>
      <encodingDesc><p> </p></encodingDesc>
      <profileDesc>
        <abstract>
          <p>This is an abstract. It is generally a summary of the text.</p>
          <p>Not here, though!</p>
        </abstract>
        <textClass>
          <keywords>
            <term>lions</term>
            <term>tigers</term>
            <term>bears</term>
          </keywords>
        </textClass>
        <langUsage>
          <language ident="en"/>
          <language ident="el"/>
          <language ident="la"/>
        </langUsage>
      </profileDesc>
      <revisionDesc>
        <change when="2015-09-01">
          <p>Ashley M. Clark removed almost everything from this TEI file that 
            corresponded to Dr. Ayer's "A Source Book for Ancient Church 
            History", published by Project Gutenberg. The file had already been 
            drastically edited down, but this change is intended as 
            acknowledgment that, in the service of testing TEI-to-metadata 
            workflows, this file has become its own entity.
          </p>
        </change>
        <change>
          <date when="2008-04-02">April 2, 2008</date>
          <p> Produced by Greg Weeks, La Monte H.P. Yarrol, David King, and
              the Online Distributed Proofreading Team at
              &lt;http://www.pgdp.net/&gt;. Page-images available at
              &lt;http://www.pgdp.net/projects/projectID4484cbcb67673/&gt; 
          </p>
          <p>Project Gutenberg TEI edition 1</p>
        </change>
      </revisionDesc>
    </teiHeader>
    <text xml:lang="en">
      <front></front>
      <body>
        <p>This is the body of the text.</p>
      </body>
      <back></back>
    </text>
  </TEI>;
