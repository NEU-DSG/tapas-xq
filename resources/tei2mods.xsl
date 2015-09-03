<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xpath-default-namespace="http://www.tei-c.org/ns/1.0"
  xmlns:wwpfn="http://www.wwp.northeastern.edu/ns/functions"
  xmlns:tapasfn="http://www.tapasproject.org/ns/functions"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-0.xsd"
  exclude-result-prefixes="#all">
  <xsl:output indent="yes" method="xml" />

  <!-- TAPAS2MODSminimal: -->
  <!-- Read in a TEI-encoded file intended for TAPAS, and write -->
  <!-- out a MODS record for said file. -->
  <!-- Written by Sarah Sweeney. -->
  <!-- Updated 2015-09 by Syd Bauman and Ashley Clark -->
  
  <!-- Known issues: -->
  <!-- * Empty elements are allowed on output (mostly). -->
  <!-- * <choice> inside of one of the name/contributor elements is either flattened (name) or discarded (contributor). -->
  <!-- * Persons with multiple contributor roles are duplicated for each role. -->
  <!-- * `title/@type='sub'` and `title/@type='marc245b'` are considered "alternative" titles. -->
  <!-- * `availability/@status` is not used. -->
  <!-- * <mods:languageOfCataloging> does not include the main language used in the source. -->
  <!-- * @xml:lang on TEI elements do not carry over to MODS when appropriate. -->
  <!-- * <address> does not match up with `mods:name/mods:affiliation`. -->
  <!-- * <msDesc> is handled somewhat generically. -->
  <!-- * "textOnly" mode does not know how to process <list> elements properly (at the moment, there are none in TAPAS). -->
  <!-- * <date>s are handled permissively. <mods:dateIssued> should be in W3C format, not plain text. -->
  
  <!-- PARAMETERS -->
  
  <xsl:param name="copyTEI" as="xs:boolean" select="false()"/>
  <xsl:param name="recordContentSource" as="xs:string" select="'TEI Archive, Publishing, and Access Service (TAPAS)'"/>
  
  <!-- FUNCTIONS -->
  
  <!-- Match the leading articles of work titles, and return their character counts. -->
  <xsl:function name="wwpfn:number-nonfiling">
    <xsl:param name="title" required="yes"/>
    <xsl:variable name="leadingArticlesRegex" select="'^((a|an|the|der|das|le|la|el) |).+$'"/>
    <xsl:value-of select="string-length(replace($title,$leadingArticlesRegex,'$1','i'))"/>
  </xsl:function>
  
  <!-- Apply textOnly mode to the requested node. -->
  <xsl:function name="tapasfn:text-only">
    <xsl:param name="node" as="node()" required="yes"/>
    <xsl:variable name="textSeq">
      <xsl:apply-templates select="$node" mode="textOnly"/>
    </xsl:variable>
    <xsl:value-of select="normalize-space(string-join($textSeq,' '))"/>
  </xsl:function>
  
  <!-- TEMPLATES -->
  
  <!-- If an element matches no other template, continue applying templates on 
    its children in the current mode. -->
  <xsl:template match="*" mode="#all">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <!-- TEXT RESOLVERS -->
  <!-- For now, ignore text nodes by default. -->
  <xsl:template match="text()" mode="#default edition name origin related contributors biblScope"/>
  <!-- Ignore content, as opposed to metadata. -->
  <xsl:template match="text | surface | sourceDoc"/>
  
  <!-- In textOnly mode, return same text node with any sequence of whitespace (including -->
  <!-- leading or trailing) reduced to a single blank. -->
  <xsl:template match="text()" mode="textOnly">
    <xsl:variable name="protected" select="concat('␠', .,'␠')"/>
    <xsl:variable name="normalized" select="normalize-space( $protected )"/>
    <xsl:variable name="result" select="substring( substring-after( $normalized ,'␠'), 1, string-length( $normalized )-2 )"/>
    <xsl:value-of select="$result"/>
  </xsl:template>
  
  <!-- In textOnly mode, the value of ptr/@target is turned into plain text. -->
  <xsl:template match="ptr[@target]|ref[@target and normalize-space(.) eq '']" mode="textOnly">
    <xsl:value-of select="@target"/>
  </xsl:template>
  
  <!-- In textOnly mode, the first <reg>, <corr>, or <expan> child of <choice> 
    is used. -->
  <xsl:template match="choice" mode="textOnly">
    <xsl:apply-templates select="(reg | corr | expan)[1]" mode="textOnly"/>
    <!-- note that <sic>, <orig>, <abbr>, and <seg> never get processed -->
  </xsl:template>
    
  <!-- For elements which may contain either (1) specific, precise TEI elements 
    (ex. <publisher>), or (2) relatively-bare text (<p>, <ab>, text() ). The 
    template applies one wrapper element around any textual content. -->
  <xsl:template name="mixedContent">
    <xsl:param name="wrapper" required="yes"/>
    <!-- If there is any plain-text child of the current node, use textOnly 
      mode to flatten any elements and wrap the text in the specified element. -->
    <xsl:choose>
      <xsl:when test="p | ab | text()[normalize-space(.) ne '']">
        <xsl:element name="{$wrapper}">
          <xsl:choose>
            <xsl:when test="not(*)">
              <xsl:value-of select="normalize-space(.)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="tapasfn:text-only(.)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- TEI DOCUMENTS -->
  <!-- If <teiCorpus> is the root element, use a <mods:collection> to surround 
    the metadata for each child <TEI>. -->
  <xsl:template match="teiCorpus">
    <mods:collection>
      <xsl:apply-templates/>
    </mods:collection>
  </xsl:template>
  
  <xsl:template match="TEI">
    <!-- If there is an edition associated with this digital document, then 
      grab that information now, to be used in the template matching 
      <publicationStmt> or <imprint> (origin mode). -->
    <xsl:variable name="digitalEdition">
      <xsl:apply-templates select="//fileDesc/editionStmt" mode="edition"/>
    </xsl:variable>
    <mods:mods>
      <xsl:apply-templates select="teiHeader">
        <xsl:with-param name="digitalEdition" tunnel="yes" select="$digitalEdition"/>
      </xsl:apply-templates>
      <!-- abstract -->
      <xsl:apply-templates select="//text//div[@type='abstract']"/>
      <!-- typeOfResource -->
      <mods:typeOfResource>
        <xsl:if test="parent::teiCorpus">
          <xsl:attribute name="collection" select="'yes'"/>
        </xsl:if>
        <xsl:text>text</xsl:text>
      </mods:typeOfResource>
      <!-- genre -->
      <mods:genre authority="aat">texts (document genres)</mods:genre>
      <!-- metadata record info -->
      <mods:recordInfo>
        <mods:recordContentSource><xsl:value-of select="$recordContentSource"/></mods:recordContentSource>
        <mods:recordOrigin>MODS record generated from TEI source file teiHeader data on <xsl:value-of select="current-date()"/> at <xsl:value-of select="current-time()"/>.</mods:recordOrigin>
        <mods:languageOfCataloging>
          <mods:languageTerm type="text" authority="iso639-2b">English</mods:languageTerm>
        </mods:languageOfCataloging>
      </mods:recordInfo>
      <!-- extension, if desired -->
      <xsl:if test="$copyTEI">
        <xsl:call-template name="extensionTEI"/>
      </xsl:if>
    </mods:mods>
  </xsl:template>
  
  <!-- Handle the rest of the metadata in a fall-through way. -->
  <xsl:template match="teiHeader">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="fileDesc">
    <xsl:call-template name="setAllTitles"/>
    <!-- Apply contributor mode; identify contributors to this work. -->
    <xsl:apply-templates
      select="*[not(name() eq 'sourceDesc')]//author 
            | *[not(name() eq 'sourceDesc')]//editor 
            | *[not(name() eq 'sourceDesc')]//funder 
            | *[not(name() eq 'sourceDesc')]//principal 
            | *[not(name() eq 'sourceDesc')]//sponsor 
            | *[not(name() eq 'sourceDesc')]//respStmt"
      mode="contributors"/>
    <!-- Apply origin mode; handle publication information. -->
    <xsl:apply-templates select="publicationStmt" mode="origin"/>
    <!-- Apply related mode; list out related resources. -->
    <xsl:apply-templates select="sourceDesc" mode="related"/>
  </xsl:template>
  
  <xsl:template match="fileDesc/extent">
    <mods:physicalDescription>
      <mods:extent>
        <xsl:value-of select="tapasfn:text-only(.)"/>
      </mods:extent>
    </mods:physicalDescription>
  </xsl:template>
  
  <!-- ABSTRACTS -->
  <xsl:template match="abstract | div[@type='abstract']">
    <mods:abstract>
      <xsl:value-of select="tapasfn:text-only(.)"/>
    </mods:abstract>
  </xsl:template>
  
  <!-- CONTRIBUTORS -->
  <xsl:template
    match="author | editor | funder | principal | sponsor"
    mode="contributors related">
      <xsl:choose>
        <xsl:when test="text()[normalize-space(.) ne '']">
          <mods:name>
            <mods:namePart>
              <xsl:choose>
                <xsl:when test="not(*)">
                  <xsl:value-of select="normalize-space(.)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="tapasfn:text-only(.)"/>
                </xsl:otherwise>
              </xsl:choose>
            </mods:namePart>
            <xsl:call-template name="nameRole"/>
          </mods:name>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="name">
            <xsl:with-param name="modsRole" tunnel="yes">
              <xsl:call-template name="nameRole"/>
            </xsl:with-param>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>
  
  <xsl:template match="respStmt" mode="contributors">
    <xsl:variable name="role">
      <xsl:for-each select="./resp">
        <xsl:call-template name="setRole">
          <xsl:with-param name="term">
            <xsl:value-of select="tapasfn:text-only(.)"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
    </xsl:variable>
    <xsl:apply-templates select="* except resp" mode="name">
      <xsl:with-param name="modsRole" select="$role" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <!-- NAMES -->
  <xsl:template match="name" mode="name">
    <xsl:call-template name="namingStruct">
      <xsl:with-param name="nameType">
        <!-- MODS' @type should only be used when <name> is explicitly personal
          or corporate. Otherwise, no judgement is made and no attribute included. -->
        <xsl:choose>
          <!-- If there is a <forename> or <surname> child, we can assume this 
            name refers to a person. -->
          <xsl:when test="matches(@type,'person') or ./surname or ./forename">
            <xsl:text>personal</xsl:text>
          </xsl:when>
          <xsl:when test="matches(@type,'^org')">
            <xsl:text>corporate</xsl:text>
          </xsl:when>
        </xsl:choose>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <!-- If this persName holds mixed content, its children will be reduced 
    to plain text. -->
  <xsl:template match="persName" mode="name">
    <xsl:choose>
      <!-- If this persName holds mixed content, its children will be reduced 
        to plain text. -->
      <xsl:when test="text()[normalize-space(.) ne '']">
        <xsl:call-template name="namingStruct">
          <xsl:with-param name="nameType" select="'personal'"/>
        </xsl:call-template>
      </xsl:when>
      <!-- If there is 1+ child persName, choose the first. In the case of 
        nested <persName>s, this logic should select the first leaf <persName>. -->
      <xsl:when test="persName">
        <xsl:apply-templates select="persName[1]" mode="name"/>
      </xsl:when>
      <!-- If the last rule was skipped, then we've arrived at the first leaf 
        <persName>. If its ancestor was <orgName>, switch to text-only mode. -->
      <xsl:when test="ancestor::orgName">
        <xsl:value-of select="tapasfn:text-only(.)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="namingStruct">
          <xsl:with-param name="nameType" select="'personal'"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="orgName" mode="name">
    <xsl:call-template name="namingStruct">
      <xsl:with-param name="nameType" select="'corporate'"/>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template name="namingStruct">
    <xsl:param name="nameType" as="xs:string"/>
    <xsl:param name="modsRole" as="node()" tunnel="yes"/>
    <mods:name>
      <xsl:if test="$nameType">
        <xsl:attribute name="type" select="$nameType"/>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="text()[normalize-space(.) ne '']">
          <mods:namePart>
            <xsl:choose>
              <xsl:when test="not(*)">
                <xsl:value-of select="normalize-space(.)"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="tapasfn:text-only(.)"/>
              </xsl:otherwise>
            </xsl:choose>
          </mods:namePart>
        </xsl:when>
        <xsl:when test="$nameType eq 'personal'">
          <xsl:call-template name="persNameHandler"/>
        </xsl:when>
        <xsl:otherwise>
          <mods:namePart>
            <xsl:apply-templates mode="name"/>
          </mods:namePart>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:copy-of select="$modsRole"/>
    </mods:name>
  </xsl:template>
  
  <!-- xd: addName -->
  <xsl:template name="persNameHandler">
    <xsl:variable name="surnames" select="surname"/>
    <xsl:variable name="forenames" select="forename, genName"/>
    <xsl:variable name="sortedNameParts" 
      select="$surnames/descendant-or-self::*[@sort], $forenames/descendant-or-self::*[@sort]"/>
    <!-- <nameLink>s are used to distinguish articles/prepositions in 
      names as NOT part of the surname. As such, RDA cataloging rules say that
      the content <nameLink>s must be placed at the end of the forename(s). -->
    <xsl:variable name="nameLinks">
      <xsl:for-each select="nameLink">
        <xsl:value-of select="tapasfn:text-only(.)"/>
        <xsl:if test="position() != last()">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <!-- Arrange surnames into one <mods:namePart> -->
    <xsl:if test="$surnames">
      <mods:namePart type="family">
        <xsl:for-each select="$surnames">
          <xsl:apply-templates select="." mode="name"/>
          <xsl:if test="position() != last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </mods:namePart>
    </xsl:if>
    <!-- Arrange forenames into one <mods:namePart> -->
    <xsl:if test="count($forenames) > 0 or $nameLinks">
      <mods:namePart type="given">
        <xsl:for-each select="$forenames">
          <xsl:apply-templates select="." mode="name"/>
          <xsl:if test="position() ne last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
        <xsl:value-of select="$nameLinks"/>
      </mods:namePart>
    </xsl:if>
    <xsl:apply-templates select="genName | roleName | address | affiliation" mode="name"/>
    <!-- Use @sort to create a displayForm of the name, if applicable. -->
    <xsl:if test="$sortedNameParts">
      <mods:displayForm>
        <xsl:for-each select="$sortedNameParts">
          <!-- If the sort attribute is available, then text nodes will be 
            ignored in favor of the sorting mechanism. -->
          <xsl:sort select="@sort" data-type="number"/>
          <xsl:apply-templates select="." mode="name"/>
          <xsl:if test="position() != last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </mods:displayForm>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="genName | roleName" mode="name">
    <mods:namePart type="termsOfAddress">
      <xsl:apply-templates mode="name"/>
    </mods:namePart>
  </xsl:template>
  
  <xsl:template match="address | affiliation" mode="name">
    <mods:affiliation>
      <xsl:value-of select="tapasfn:text-only(.)"/>
    </mods:affiliation>
  </xsl:template>
  
  <!-- The TEI allows whitespace in names. Text nodes should be considered 
    significant, though we will normalize whitespace. -->
  <xsl:template match="name//text() | persName//text() | orgName//text()" mode="name">
    <xsl:value-of select="replace(.,'\s+',' ')"/>
  </xsl:template>
  
  <xsl:template name="invertName">
    <xsl:choose>
      <xsl:when test="not(contains(., ','))">
        <xsl:choose>
          <xsl:when test="contains(., '.')">
            <xsl:value-of select="substring-after(., '. ')"/>
            <xsl:text>, </xsl:text>
            <xsl:value-of select="substring-before(., '.')"/>
            <xsl:text>.</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="substring-after(., ' ')"/>
            <xsl:text>, </xsl:text>
            <xsl:value-of select="substring-before(., ' ')"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Map TEI elements to MARC relators. -->
  <xsl:template name="nameRole">
    <xsl:param name="localName" select="local-name(.)"/>
    <xsl:variable name="relator">
      <xsl:choose>
        <!-- TEI elements belonging to model.respLike -->
        <xsl:when test="$localName eq 'author'">
          <xsl:text>Author</xsl:text>
        </xsl:when>
        <xsl:when test="$localName eq 'editor'">
          <xsl:text>Editor</xsl:text>
        </xsl:when>
        <xsl:when test="$localName eq 'funder'">
          <xsl:text>Funder</xsl:text>
        </xsl:when>
        <xsl:when test="$localName eq 'principal'">
          <xsl:text>Research team head</xsl:text>
        </xsl:when>
        <xsl:when test="$localName eq 'sponsor'">
          <xsl:text>Sponsor</xsl:text>
        </xsl:when>
        <!-- TEI elements belonging to model.publicationStmtPart.agency -->
        <xsl:when test="$localName eq 'distributor'">
          <xsl:text>Distributor</xsl:text>
        </xsl:when>
        <xsl:when test="$localName eq 'publisher' or $localName eq 'authority'">
          <xsl:text>Publisher</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message>
            <xsl:text>internal error: unable to ascertain contributor role for element </xsl:text>
            <xsl:value-of select="$localName"/>
          </xsl:message>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:call-template name="setRole">
      <xsl:with-param name="term" select="$relator"/>
      <xsl:with-param name="authority" select="'marcrelator'"/>
    </xsl:call-template>
  </xsl:template>
  
  <!-- Given the name of a role, generate <mods:role>. -->
  <xsl:template name="setRole">
    <xsl:param name="roleType"/>
    <xsl:param name="term" required="yes"/>
    <xsl:param name="termType" select="'text'"/>
    <xsl:param name="authority"/>
    <mods:role>
      <xsl:if test="$roleType">
        <xsl:attribute name="type" select="$roleType"/>
      </xsl:if>
      <mods:roleTerm type="{$termType}">
        <xsl:if test="$authority">
          <xsl:attribute name="authority" select="$authority"/>
        </xsl:if>
        <xsl:value-of select="$term"/>
      </mods:roleTerm>
    </mods:role>
  </xsl:template>

  <!-- PUBLICATION STATEMENT -->
  <xsl:template match="publicationStmt | imprint" mode="origin">
    <xsl:param name="digitalEdition" as="node()" tunnel="yes"/>
    <xsl:choose>
      <xsl:when test="text()[normalize-space(.) ne '']">
        <mods:note type="publicationStmt">
          <xsl:choose>
            <xsl:when test="not(*)">
              <xsl:value-of select="normalize-space(.)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="tapasfn:text-only(.)"/>
            </xsl:otherwise>
          </xsl:choose>
        </mods:note>
      </xsl:when>
      <xsl:when test="p | ab">
        <mods:note type="publicationStmt">
          <xsl:value-of select="tapasfn:text-only(.)"/>
        </mods:note>
      </xsl:when>
      <xsl:otherwise>
        <mods:originInfo>
          <xsl:if test="not(empty($digitalEdition))">
            <xsl:copy-of select="$digitalEdition"/>
          </xsl:if>
          <xsl:apply-templates select="*[not(self::availability)]" mode="origin"/>
        </mods:originInfo>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="availability" mode="origin"/>
  </xsl:template>
  
  <xsl:template match="pubPlace" mode="origin">
    <mods:place>
      <mods:placeTerm>
        <xsl:value-of select="tapasfn:text-only(.)"/>
      </mods:placeTerm>
    </mods:place>
  </xsl:template>
  
  <xsl:template match="publisher | distributor | authority" mode="origin related">
    <mods:publisher>
      <xsl:value-of select="tapasfn:text-only(.)"/>
    </mods:publisher>
  </xsl:template>
  
  <xsl:template match="date" mode="origin">
    <xsl:choose>
      <xsl:when test="@when">
        <mods:dateIssued keyDate="yes">
          <xsl:value-of select="@when"/>
        </mods:dateIssued>
      </xsl:when>
      <xsl:when test="@notBefore or @notAfter">
        <xsl:if test="@notBefore">
          <mods:dateIssued point="start" qualifier="approximate" keyDate="yes">
            <xsl:value-of select="date/@notBefore"/>
          </mods:dateIssued>
        </xsl:if>
        <xsl:if test="@notAfter">
          <mods:dateIssued point="end" qualifier="approximate">
            <xsl:value-of select="date/@notAfter"/>
          </mods:dateIssued>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <mods:dateIssued keyDate="yes">
          <xsl:value-of select="tapasfn:text-only(.)"/>
        </mods:dateIssued>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- LICENSING -->
  <xsl:template match="availability" mode="origin">
    <xsl:choose>
      <xsl:when test="licence">
        <xsl:apply-templates select="licence" mode="origin"/>
      </xsl:when>
      <xsl:otherwise>
        <mods:accessCondition>
          <xsl:value-of select="tapasfn:text-only(.)"/>
        </mods:accessCondition>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="licence" mode="origin">
    <mods:accessCondition displayLabel="Licensing information:">
      <xsl:if test="@target">URL: <xsl:value-of select="@target"/>.&#x0A;</xsl:if>
      <!-- maybe handle dating attrs same kinda way? -->
      <xsl:value-of select="tapasfn:text-only(.)"/>
    </mods:accessCondition>
  </xsl:template>

  <!-- EDITION -->
  <xsl:template match="fileDesc/editionStmt" mode="edition">
    <mods:edition>
      <xsl:choose>
        <xsl:when test="text()[normalize-space(.) ne '']">
          <xsl:choose>
            <xsl:when test="not(*)">
              <xsl:value-of select="normalize-space(.)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="tapasfn:text-only(.)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="p | ab">
          <xsl:value-of select="tapasfn:text-only(.)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="edition"/>
        </xsl:otherwise>
      </xsl:choose>
    </mods:edition>
  </xsl:template>
  
  <xsl:template match="fileDesc/editionStmt/edition[normalize-space(concat(@n,.)) ne '']" mode="edition">
    <xsl:choose>
      <xsl:when test="@n">
        <xsl:value-of select="@n"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="tapasfn:text-only(.)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- LANGUAGE -->
  <xsl:template match="language">
    <mods:language>
      <mods:languageTerm type="code" authority="rfc5646">
        <xsl:value-of select="@ident"/>
      </mods:languageTerm>
      <xsl:if test="
           starts-with( @ident,'x-')
        or matches( @ident,'^q[a-t][a-z]-?')
        or matches( @ident,'-(Qaa[a-z]|Qab[a-x])(-|$)')
        or matches( @ident,'-(AA|Q[M-Z]|X[A-Z]|ZZ)(-|$)')
        or contains( @ident,'-x-')
        ">
        <mods:languageTerm type="text">
          <xsl:apply-templates/>
        </mods:languageTerm>
      </xsl:if>
    </mods:language>
  </xsl:template>

  <!-- NOTES -->
  <xsl:template match="notesStmt/note">
    <mods:note>
      <xsl:value-of select="tapasfn:text-only(.)"/>
    </mods:note>
  </xsl:template>
  
  <xsl:template match="fileDesc/publicationStmt[p]">
    <mods:note>
      <xsl:for-each select="p">
        <xsl:value-of select="tapasfn:text-only(.)"/>
        <xsl:if test="position() != last()">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:for-each>
    </mods:note>
  </xsl:template>
  
  <!-- SUBJECTS -->
  <xsl:template match="keywords/term">
    <mods:subject>
      <mods:topic>
        <xsl:value-of select="tapasfn:text-only(.)"/>
      </mods:topic>
    </mods:subject>
  </xsl:template>
  
  <!-- Handle <list>s inside <keywords> (deprecated, but may still be around in older TEI) -->
  <xsl:template match="keywords/list/item | encodingDesc/classDecl/taxonomy/category/catDesc">
    <mods:subject>
      <mods:topic>
        <xsl:value-of select="tapasfn:text-only(.)"/>
      </mods:topic>
    </mods:subject>
  </xsl:template>
  
  <!-- RELATED ITEM -->
  <xsl:template match="fileDesc/sourceDesc" mode="related">
    <xsl:apply-templates mode="related"/>
  </xsl:template>
  
  <xsl:template match="date" mode="related">
    <mods:originInfo>
      <xsl:apply-templates select="." mode="origin"/>
    </mods:originInfo>
  </xsl:template>
  
  <xsl:template match="bibl" mode="related">
    <mods:relatedItem>
      <xsl:call-template name="setAllTitles"/>
      <xsl:call-template name="mixedContent">
        <xsl:with-param name="wrapper" select="'mods:note'"/>
      </xsl:call-template>
    </mods:relatedItem>
  </xsl:template>
  
  <xsl:template match="msDesc" mode="related">
    <mods:relatedItem>
      <xsl:call-template name="setAllTitles"/>
      <mods:typeOfResource manuscript="yes">text</mods:typeOfResource>
      <xsl:call-template name="mixedContent">
        <xsl:with-param name="wrapper" select="'mods:note'"/>
      </xsl:call-template>
    </mods:relatedItem>
  </xsl:template>
  
  <xsl:template match="biblStruct" mode="related">
    <mods:relatedItem>
      <xsl:call-template name="setAllTitles"/>
      <xsl:apply-templates mode="related"/>
    </mods:relatedItem>
  </xsl:template>
  
  <xsl:template match="biblFull" mode="related">
    <mods:relatedItem>
      <xsl:call-template name="setAllTitles"/>
      <xsl:apply-templates select=".//titleStmt" mode="contributors"/>
      <xsl:apply-templates mode="related"/>
    </mods:relatedItem>
  </xsl:template>
  
  <xsl:template match="publicationStmt | imprint" mode="related">
    <xsl:apply-templates select="." mode="origin"/>
  </xsl:template>
  
  <!-- xd: is there a @type on <bibl> for series? -->
  <xsl:template match="seriesStmt" mode="related">
    <mods:relatedItem type="series">
      <xsl:call-template name="setAllTitles"/>
      <xsl:call-template name="mixedContent">
        <xsl:with-param name="wrapper" select="'mods:note'"/>
      </xsl:call-template>
    </mods:relatedItem>
  </xsl:template>
  
  <!--<xsl:template match="fileDesc/titleStmt[title[@level eq 's']]" mode="related" 
    priority="50">
    <mods:relatedItem type="series">
      <xsl:call-template name="constructTitle">
        <xsl:with-param name="inputTitle">
          <xsl:value-of select="tapasfn:text-only(.)"/>
        </xsl:with-param>
      </xsl:call-template>
    </mods:relatedItem>
  </xsl:template>-->
  
  <!-- xd: Is there a @type on <bibl> for analytics? -->
  <xsl:template match="sourceDesc//analytic | sourceDesc//*[not(self::monogr)][title[@level eq 'a']] | msPart" mode="related">
    <mods:relatedItem>
      <xsl:if test="ancestor::bibl or ancestor::biblFull or ancestor::biblStruct or ancestor::msDesc">
        <xsl:attribute name="type" select="'constituent'"/>
      </xsl:if>
      <xsl:call-template name="setAllTitles"/>
      <xsl:apply-templates mode="related"/>
    </mods:relatedItem>
  </xsl:template>
  
  <xsl:template match="msIdentifier/*[not(name() eq 'msName')]" mode="related">
    <mods:note type="{local-name()}">
      <xsl:value-of select="tapasfn:text-only(.)"/>
    </mods:note>
  </xsl:template>
  
  <xsl:template match="msItem | msItemStruct" mode="related">
    <xsl:call-template name="setAllTitles"/>
    <xsl:apply-templates mode="related"/>
  </xsl:template>
  
  <!-- PARTS -->
  <xsl:template match="biblScope | locus" mode="related">
    <mods:part>
      <!-- Handle optional attributes -->
      <xsl:choose>
        <xsl:when test="@from or @to">
          <mods:extent>
            <xsl:if test="@unit">
              <xsl:attribute name="unit" select="@unit"/>
            </xsl:if>
            <xsl:if test="@from">
              <mods:start><xsl:value-of select="@from"/></mods:start>
            </xsl:if>
            <xsl:if test="@to">
              <mods:end><xsl:value-of select="@to"/></mods:end>
            </xsl:if>
          </mods:extent>
        </xsl:when>
        <xsl:when test="@unit">
          <mods:detail type="{@unit}" level="{tapasfn:text-only(.)}"/>
        </xsl:when>
      </xsl:choose>
      <!-- Handle <biblScope>'s children -->
      <xsl:variable name="biblScopeText" select="tapasfn:text-only(.)"/>
      <xsl:if test="$biblScopeText">
        <mods:text>
          <xsl:value-of select="tapasfn:text-only(.)"/>
        </mods:text>
      </xsl:if>
      <!-- The only child element we match is title. There may be others 
        later, however. -->
      <xsl:apply-templates mode="biblScope"/>
    </mods:part>
  </xsl:template>
  
  <xsl:template match="biblScope/title" mode="biblScope">
    <mods:detail>
      <mods:title>
        <xsl:value-of select="tapasfn:text-only(.)"/>
      </mods:title>
    </mods:detail>
  </xsl:template>

  <!-- ******************* -->
  <!-- *** subroutines *** -->
  <!-- ******************* -->
  
  <!-- TITLES -->
  <!-- This template generates all <mods:titleInfo> elements for the current 
    node and its children, including determining which is the main element and 
    which have @type='alternative'. This template should be called from the 
    specific element which holds the titles for the current item 
    (eg. <titleStmt>, <bibl>). -->
  <xsl:template name="setAllTitles">
    <xsl:variable name="allTitles" as="item()*"
      select="./title
            | ./titleStmt/title
            | self::biblStruct/*[ monogr or bibl[matches(@type, '^monogr')] ]/title
            | ./msIdentifier/msName "/>
    <xsl:variable name="distinctTitles"
      select="distinct-values( for $t in $allTitles return tapasfn:text-only($t) )"/>
    <xsl:if test="not(empty($allTitles))">
      <!-- When choosing the main title, prioritize those which have been 
      explicitly encoded for canonical use. -->
      <xsl:variable name="mainTitle">
        <xsl:choose>
          <xsl:when test="$allTitles/@type = 'marc245a'">
            <xsl:value-of select="tapasfn:text-only($allTitles[@type = 'marc245a'][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles/@type = 'uniform'">
            <xsl:value-of select="tapasfn:text-only($allTitles[@type = 'uniform'][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles/@type = 'main'">
            <xsl:value-of select="tapasfn:text-only($allTitles[@type = 'main'][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles/@level = 'm'">
            <xsl:value-of select="tapasfn:text-only($allTitles[@level = 'm'][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles/@level = 's'">
            <xsl:value-of select="tapasfn:text-only($allTitles[@level = 's'][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles/@level">
            <xsl:value-of select="tapasfn:text-only($allTitles[@level][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles[not(@type)]">
            <xsl:value-of select="tapasfn:text-only($allTitles[not(@type)][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles/@type = 'desc'">
            <xsl:value-of select="tapasfn:text-only($allTitles[@type = 'desc'][1])"/>
          </xsl:when>
          <xsl:when test="$allTitles/@type != 'sub'">
            <xsl:value-of select="tapasfn:text-only($allTitles[@type][1])"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="tapasfn:text-only($allTitles[1])"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- Construct the entry for the main title. -->
      <mods:titleInfo>
        <xsl:call-template name="constructTitle">
          <xsl:with-param name="inputTitle" select="$mainTitle"/>
          <xsl:with-param name="is-main" select="true()"/>
        </xsl:call-template>
      </mods:titleInfo>
      <!-- Construct the alternate titles. -->
      <xsl:for-each select="$distinctTitles[not(. eq $mainTitle)]">
        <!-- Do not include duplicate main titles. -->
        <mods:titleInfo>
          <xsl:call-template name="constructTitle">
            <xsl:with-param name="inputTitle" select="."/>
          </xsl:call-template>
        </mods:titleInfo>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>
  
  <!-- Given a title, contruct its <titleInfo>, including (limited) non-filing handling. -->
  <xsl:template name="constructTitle">
    <xsl:param name="inputTitle" as="xs:string" required="yes"/>
    <xsl:param name="is-main" as="xs:boolean" select="false()"/>
    <xsl:variable name="title" select="normalize-space($inputTitle)"/>
    <xsl:variable name="numNonfiling" select="wwpfn:number-nonfiling($title)"/>
    <xsl:if test="not($is-main)">
      <xsl:attribute name="type" select="'alternative'"/>
    </xsl:if>
    <xsl:if test="$numNonfiling > 0">
      <mods:nonSort>
        <xsl:value-of select="substring($title,1,$numNonfiling - 1)"/>
      </mods:nonSort>
    </xsl:if>
    <mods:title>
      <xsl:value-of select="substring($title,$numNonfiling+1)"/>
    </mods:title>
  </xsl:template>
  
  <!-- Make a copy of the entire TEI document. -->
  <xsl:template name="extensionTEI">
    <mods:extension>
      <xsl:copy-of select="."/>
    </mods:extension>
  </xsl:template>

</xsl:stylesheet>
